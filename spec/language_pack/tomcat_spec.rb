require "spec_helper"

describe LanguagePack::JavaWeb, type: :with_temp_dir do

  attr_reader :tmpdir, :java_web_pack

  let(:appdir) { File.join(tmpdir, "app") }

  before do
    @java_web_pack = LanguagePack::JavaWeb.new(appdir)
    # TODO pass in Mock
    @java_web_pack.stub(:install_java)

    FileUtils.mkdir_p(appdir)

    Dir.chdir(appdir) do
      FileUtils.mkdir_p("WEB-INF")
      java_web_pack.container.stub(:fetch_package) do |package|
        container_name = java_web_pack.container.name
        FileUtils.copy( File.expand_path("../../support/fake-#{container_name}.tar.gz", __FILE__), package)
      end
      java_web_pack.container.stub(:install_database_drivers)
    end
  end

  describe "compile" do

    before do
      FileUtils.touch "#{appdir}/WEB-INF/web.xml"
    end

    it "should remove specified Tomcat container files" do
      java_web_pack.compile
      Dir.chdir(File.join(appdir, "webapps")) do
        Dir.glob("*").should == ["ROOT"]
      end
      Dir.chdir(File.join(appdir, "temp")) do
        Dir.glob("*").empty?.should == true
      end
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
