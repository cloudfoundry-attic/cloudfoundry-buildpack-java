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
        java_web_pack.stub(:fetch_package) do |package|
          FileUtils.copy( File.expand_path("../../support/fake-tomcat.tar.gz", __FILE__), package)
        end
        java_web_pack.stub(:install_database_drivers)
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

    it "should be used if web.xml is present in installed Tomcat dir" do
      Dir.chdir(appdir) do
        FileUtils.mkdir_p("webapps/ROOT/WEB-INF")
        FileUtils.touch "webapps/ROOT/WEB-INF/web.xml"
        LanguagePack::JavaWeb.use?.should == true
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

    it "should download and unpack Tomcat to root directory" do
      java_web_pack.compile
      File.exists?(File.join(appdir, "bin", "catalina.sh")).should == true
    end

    it "should remove specified Tomcat files" do
      java_web_pack.compile
      File.exists?(File.join(appdir, "LICENSE")).should == false
      Dir.chdir(File.join(appdir, "webapps")) do
        Dir.glob("*").should == ["ROOT"]
      end
      Dir.chdir(File.join(appdir, "temp")) do
        Dir.glob("*").empty?.should == true
      end
    end

    it "should copy app to webapp ROOT" do
      java_web_pack.compile

      web_xml = File.join(appdir,"webapps","ROOT", "WEB-INF", "web.xml")
      File.exists?(web_xml).should == true
    end

    it "should copy MySQL and Postgres drivers to Tomcat lib dir" do
      java_web_pack.unstub(:install_database_drivers)
      java_web_pack.compile
      File.exists?(File.join(appdir,"lib","mysql-connector-java-5.1.12.jar")).should == true
      File.exists?(File.join(appdir,"lib","postgresql-9.0-801.jdbc4.jar")).should == true
    end


    it "should unpack and configure Insight agent if Insight Rabbit service bound" do

    end

    it "should not unpack and configure Insight agent if Insight Rabbit service not bound" do

    end

    it "should create a .profile.d with proxy sys props, connector port, and heap size in JAVA_OPTS" do
      java_web_pack.stub(:install_tomcat)
      java_web_pack.compile
      profiled = File.join(appdir,".profile.d","java.sh")
      File.exists?(profiled).should == true
      script = File.read(profiled)
      script.should include("-Xmx$MEMORY_LIMIT")
      script.should include("-Xms$MEMORY_LIMIT")
      script.should include("-Dhttp.port=$PORT")
      script.should_not include("-Djava.io.tmpdir=$TMPDIR")
    end

    it "should add template server.xml to Tomcat for configuration of web port" do
      java_web_pack.compile
      server_xml = File.join(appdir,"conf","server.xml")
      File.exists?(server_xml).should == true
      File.read(server_xml).should include("http.port")
    end
  end

  describe "release" do
    it "should return the Tomcat start script as default web process" do
      java_web_pack.release.should == {
          "addons" => [],
          "config_vars" => {},
          "default_process_types" => { "web" => "./bin/catalina.sh run" }
      }.to_yaml
    end
  end
end
