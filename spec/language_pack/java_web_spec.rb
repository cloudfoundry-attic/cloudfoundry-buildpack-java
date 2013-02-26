require "spec_helper"

describe LanguagePack::JavaWeb, type: :with_temp_dir do

  attr_reader :tmpdir, :java_web_pack

  let(:appdir) { File.join(tmpdir, "app") }

  before do
    @java_web_pack = LanguagePack::JavaWeb.new(appdir)
    # TODO pass in Mock
    @java_web_pack.stub(:install_java)

    Dir.chdir(tmpdir) do
      Dir.mkdir("app")
      Dir.chdir(appdir) do
        Dir.mkdir("WEB-INF")
        java_web_pack.container.stub(:fetch_package) do |package|
          container_name = java_web_pack.container.name
          FileUtils.copy( File.expand_path("../../support/fake-#{container_name}.tar.gz", __FILE__), package)
        end
        java_web_pack.container.stub(:install_database_drivers)
      end
    end
  end

  describe "detect" do

    it "should be used if web.xml present" do
      Dir.chdir(appdir) do
        FileUtils.touch "WEB-INF/web.xml"
        LanguagePack::JavaWeb.use?.should == true
      end
    end

    it "should be used if jboss-web.xml present" do
      Dir.chdir(appdir) do
        FileUtils.touch "WEB-INF/jboss-web.xml"
        LanguagePack::JavaWeb.use?.should == true
        LanguagePack::Container::JbossAS.use?.should == true
      end
    end

    it "should not be used if no web.xml" do
      Dir.chdir(appdir) do
        LanguagePack::JavaWeb.use?.should == false
      end
    end
  end

  describe "compile" do

    before do
      FileUtils.touch "#{appdir}/WEB-INF/web.xml"
    end

    it "should download and unpack container to root directory" do
      java_web_pack.compile
      File.exists?(File.join(appdir, "bin", java_web_pack.container.installed_bin_file)).should == true
    end

    it "should delete discarded files" do
      java_web_pack.compile
      java_web_pack.container.discarded_files.each do |file|
        if File.exists?(File.join(appdir, file))
          File.directory?(File.join(appdir, file)).should == true
        end
      end
    end

    it "should remove specified Tomcat container files" do
      pending "only for tomcat container" unless java_web_pack.container.name == "tomcat"
      java_web_pack.compile
      Dir.chdir(File.join(appdir, "webapps")) do
        Dir.glob("*").should == ["ROOT"]
      end
      Dir.chdir(File.join(appdir, "temp")) do
        Dir.glob("*").empty?.should == true
      end
    end

    it "should remove specified Jboss-as container files" do
      pending "only for jboss-as container" unless java_web_pack.container.name == "jboss-as"
      java_web_pack.compile
      Dir.chdir(File.join(appdir, "standalone", "deployments")) do
        Dir.glob("*").should == ["ROOT.war"]
      end
    end

    it "should copy app to container web root" do
      java_web_pack.compile do |jwp|
        web_xml = File.join(jwp.webapp_path, "WEB-INF", "web.xml")
        File.exists?(web_xml).should == true
      end
    end

    it "should copy MySQL and Postgres drivers to container lib dir" do
      java_web_pack.container.unstub(:install_database_drivers)
      java_web_pack.compile
      File.exists?(File.join(appdir, java_web_pack.container.get_database_driver_info("mysql")[:installed_path])).should == true
      File.exists?(File.join(appdir, java_web_pack.container.get_database_driver_info("postgresql")[:installed_path])).should == true
    end

    it "should repack webapp in jboss-as contianer" do
      pending "only for jboss-as container" unless java_web_pack.container.name == "jboss-as"
      Dir.chdir(appdir) do
        FileUtils.touch "WEB-INF/mysql-ds.xml"
      end
      java_web_pack.compile
      File.exists?(java_web_pack.webapp_path).should == true
      File.directory?(java_web_pack.webapp_path).should == false
      File.exists?(File.join(java_web_pack.webapp_path, "WEB-INF/mysql-ds.xml")).should == false
      File.exists?(File.join(File.dirname(java_web_pack.webapp_path), "mysql-ds.xml")).should == true
    end

    it "should unpack and configure Insight agent if Insight Rabbit service bound" do

    end

    it "should not unpack and configure Insight agent if Insight Rabbit service not bound" do

    end

    it "should create a .profile.d with proxy sys props, connector port, and heap size in JAVA_OPTS" do
      java_web_pack.stub(:install_container)
      java_web_pack.compile
      profiled = File.join(appdir,".profile.d","java.sh")
      File.exists?(profiled).should == true
      script = File.read(profiled)
      script.should include("-Xmx$MEMORY_LIMIT")
      script.should include("-Xms$MEMORY_LIMIT")
      script.should include("-Dhttp.port=$VCAP_APP_PORT")
      script.should_not include("-Djava.io.tmpdir=$TMPDIR") if java_web_pack.container.name == "tomcat"
    end

    it "should add template server.xml to Tomcat for configuration of web port" do
      pending "only for tomcat container" unless java_web_pack.container.name == "tomcat"
      java_web_pack.compile
      server_xml = File.join(appdir,"conf","server.xml")
      File.exists?(server_xml).should == true
      File.read(server_xml).should include("http.port")
    end

    it "should add template standalone.xml to jboss-as for configuration of web port" do
      pending "only for jboss-as container" unless java_web_pack.container.name == "jboss-as"
      java_web_pack.compile
      standalone_xml = File.join(appdir,"standalone","configuration","standalone.xml")
      sleep 30
      File.exists?(standalone_xml).should == true
      File.read(standalone_xml).should include("http.port")
    end
  end

  describe "release" do
    it "should return the Tomcat start script as default web process" do
      pending "only for tomcat container" unless java_web_pack.container.name == "tomcat"
      java_web_pack.release.should == {
          "addons" => [],
          "config_vars" => {},
          "default_process_types" => { "web" => "./bin/catalina.sh run" }
      }.to_yaml
    end

    it "should return the jboss-as start script as default web process" do
      pending "only for jboss-as container" unless java_web_pack.container.name == "jboss-as"
      java_web_pack.release.should == {
          "addons" => [],
          "config_vars" => {},
          "default_process_types" => { "web" => "./bin/standalone.sh" }
      }.to_yaml
    end

  end
end
