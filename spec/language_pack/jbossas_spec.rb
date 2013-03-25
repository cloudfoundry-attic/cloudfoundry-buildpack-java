require "spec_helper"

describe LanguagePack::JavaWeb, type: :with_temp_dir do

  attr_reader :tmpdir, :java_web_pack

  let(:appdir) { File.join(tmpdir, "app") }

  before do
    FileUtils.mkdir_p(File.join(appdir, 'WEB-INF'))
    FileUtils.touch(File.join(appdir, 'WEB-INF', 'jboss-web.xml'))

    @java_web_pack = LanguagePack::JavaWeb.new(appdir)
    # TODO pass in Mock
    @java_web_pack.stub(:install_java)

    Dir.chdir(appdir) do
      puts java_web_pack.container.to_s
      java_web_pack.container.stub(:fetch_package) do |package|
        container_name = java_web_pack.container.name
        FileUtils.copy( File.expand_path("../../support/fake-#{container_name}.tar.gz", __FILE__), package)
      end
      java_web_pack.container.stub(:install_database_drivers)
    end
  end

  describe "detect" do
    it "should be used if jboss-web.xml present" do
      Dir.chdir(appdir) do
        FileUtils.touch "WEB-INF/jboss-web.xml"
        LanguagePack::JavaWeb.use?.should == true
        File.exists?(LanguagePack::JavaWeb.detected_hint_file(:pack)).should == true
        LanguagePack::Container::JbossAS.use?.should == true
        File.exists?(LanguagePack::JavaWeb.detected_hint_file(:pack)).should == true
        LanguagePack::JavaWeb.detect_with_hint_file(LanguagePack::JavaWeb.to_s, :pack).should == true
        File.exists?(LanguagePack::JavaWeb.detected_hint_file(:container)).should == true
        LanguagePack::JavaWeb.detect_with_hint_file(LanguagePack::Container::JbossAS.to_s, :container).should == true
      end
    end
  end

  describe "compile" do

    before do
      FileUtils.touch "#{appdir}/WEB-INF/web.xml"
    end

    it "should remove specified Jboss-as container files" do
      java_web_pack.compile
      Dir.chdir(File.join(appdir, "standalone", "deployments")) do
        Dir.glob("*").should == ["ROOT.war"]
      end
    end

    it "should repack webapp in Jboss-as contianer" do
      Dir.chdir(appdir) do
        FileUtils.touch "WEB-INF/mysql-ds.xml"
      end
      java_web_pack.compile
      File.exists?(java_web_pack.webapp_path).should == true
      File.directory?(java_web_pack.webapp_path).should == false
      File.exists?(File.join(java_web_pack.webapp_path, "WEB-INF/mysql-ds.xml")).should == false
      File.exists?(File.join(File.dirname(java_web_pack.webapp_path), "mysql-ds.xml")).should == true
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
    end

    it "should add template standalone.xml to jboss-as for configuration of web port" do
      Dir.chdir(appdir) do
        FileUtils.touch "WEB-INF/jboss-web.xml"
      end
      java_web_pack.compile
      standalone_xml = File.join(appdir,"standalone","configuration","standalone.xml")
      sleep 30
      File.exists?(standalone_xml).should == true
      File.read(standalone_xml).should include("http.port")
    end
  end

  describe "release" do

    it "should return the jboss-as start script as default web process" do
      java_web_pack.release.should == {
          "addons" => [],
          "config_vars" => {},
          "default_process_types" => { "web" => "./bin/standalone.sh" }
      }.to_yaml
    end

  end
end
