require "spec_helper"

describe LanguagePack::JavaWeb do

  attr_reader :tmpdir, :java_web_pack

  before do
    @tmpdir = Dir.mktmpdir
    @java_web_pack = LanguagePack::JavaWeb.new(tmpdir)
    # TODO pass in Mock
    @java_web_pack.stub(:install_java)
  end

  after do
    FileUtils.rm_r(@tmpdir) if @tmpdir
  end

  describe "detect" do

    it "should be used if web.xml present" do
      Dir.chdir(tmpdir) do
        Dir.mkdir("WEB-INF")
        FileUtils.touch "WEB-INF/web.xml"
        LanguagePack::JavaWeb.use?.should == true
      end
    end

    it "should be used if web.xml is present in installed Tomcat dir" do
      Dir.chdir(tmpdir) do
        FileUtils.mkdir_p("webapps/ROOT/WEB-INF")
        FileUtils.touch "webapps/ROOT/WEB-INF/web.xml"
        LanguagePack::JavaWeb.use?.should == true
      end
    end

    it "should not be used if no web.xml" do
      Dir.chdir(tmpdir) do
        LanguagePack::JavaWeb.use?.should == false
      end
    end
  end

  describe "compile" do

    before do
      Dir.chdir(tmpdir) do
        Dir.mkdir("WEB-INF")
        FileUtils.touch "WEB-INF/web.xml"
        Dir.mkdir("logs")
        FileUtils.touch "logs/staging.log"
        java_web_pack.stub(:download_tomcat) do
          FileUtils.copy( File.expand_path("../../support/fake-tomcat.tar.gz", __FILE__), ".tomcat/tomcat.tar.gz")
        end
        java_web_pack.stub(:install_database_drivers)
      end
    end

    it "should download and unpack Tomcat to root directory" do
      java_web_pack.compile
      File.exists?(File.join(tmpdir, "bin", "catalina.sh")).should == true
    end

    it "should remove specified Tomcat files" do
      java_web_pack.compile
      File.exists?(File.join(tmpdir, "LICENSE")).should == false
      Dir.chdir(File.join(tmpdir, "webapps")) do
        Dir.glob("*").should == ["ROOT"]
      end
      Dir.chdir(File.join(tmpdir, "temp")) do
        Dir.glob("*").empty?.should == true
      end
    end

    it "should copy app to webapp ROOT but leave staging logs dir" do
      java_web_pack.compile
      web_xml = File.join(tmpdir,"webapps","ROOT", "WEB-INF", "web.xml")
      File.exists?(web_xml).should == true
      File.exists?(File.join(tmpdir,"logs","staging.log")).should == true
    end

    it "should copy MySQL and Postgres drivers to Tomcat lib dir" do
      java_web_pack.unstub(:install_database_drivers)
      java_web_pack.compile
      File.exists?(File.join(tmpdir,"lib","mysql-connector-java-5.1.12.jar")).should == true
      File.exists?(File.join(tmpdir,"lib","postgresql-9.0-801.jdbc4.jar")).should == true
    end


    it "should unpack and configure Insight agent if Insight Rabbit service bound" do

    end

    it "should not unpack and configure Insight agent if Insight Rabbit service not bound" do

    end

    it "should create a .profile.d with proxy sys props, connector port, and heap size in JAVA_OPTS" do
      java_web_pack.stub(:install_tomcat)
      java_web_pack.compile
      profiled = File.join(tmpdir,".profile.d","java.sh")
      File.exists?(profiled).should == true
      script = File.read(profiled)
      script.should include("-Xmx$MEMORY_LIMIT")
      script.should include("-Xms$MEMORY_LIMIT")
      script.should include ("-Dhttp.port=$VCAP_APP_PORT")
      script.should_not include("-Djava.io.tmpdir=$TMPDIR")
    end

    it "should add template server.xml to Tomcat for configuration of web port" do
      java_web_pack.compile
      server_xml = File.join(tmpdir,"conf","server.xml")
      File.exists?(server_xml).should == true
      File.read(server_xml).should include("http.port")
    end

    it "should provide a way for DEA to ensure app is up by copying droplet.yaml and LifecycleListener config" do
      java_web_pack.compile
      File.exists?(File.join(tmpdir,"droplet.yaml")).should == true
      File.exists?(File.join(tmpdir,"lib","TomcatStartupListener-1.0.jar")).should == true
      context_xml = File.join(tmpdir,"conf","context.xml")
      File.read(context_xml).should include("AppCloudLifecycleListener")
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