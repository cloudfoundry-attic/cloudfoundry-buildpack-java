require "rspec"
require "tmpdir"
require "language_pack/java_web"

describe "JavaWeb Language Pack" do

  attr_reader :tmpdir

  before do
    @tmpdir = Dir.mktmpdir
  end

  after do
    FileUtils.rm_r(@tmpdir) if @tmpdir
  end

  describe "detect" do

    it "should be used if web.xml present" do
      Dir.chdir(tmpdir) do
        Dir.mkdir("WEB-INF")
        File.open("#{tmpdir}/WEB-INF/web.xml", 'w') {|f| f.write("what") }
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
        File.open("WEB-INF/web.xml", 'w') {|f| f.write("what") }
      end
    end

    it "should download and unpack Tomcat to root directory" do
      LanguagePack::JavaWeb.new(tmpdir).compile
      File.exists?(File.join(tmpdir, "bin", "catalina.sh")).should == true
    end

    it "should remove specified Tomcat files" do
      puts tmpdir
      LanguagePack::JavaWeb.new(tmpdir).compile
      File.exists?(File.join(tmpdir, "LICENSE")).should == false
      Dir.chdir(File.join(tmpdir, "webapps")) do
        Dir.glob("*").should == ["ROOT"]
      end
      Dir.chdir(File.join(tmpdir, "temp")) do
        Dir.glob("*").empty?.should == true
      end
    end

    it "should copy app to webapp ROOT" do
      LanguagePack::JavaWeb.new(tmpdir).compile
      web_xml = File.join(tmpdir,"webapps","ROOT", "WEB-INF", "web.xml")
      File.exists?(web_xml).should == true
      File.read(web_xml).should == "what"
    end

    it "should copy mysql driver to Tomcat lib dir" do

    end

    it "should copy postgres driver to Tomcat lib dir" do

    end

    it "should unpack and configure Insight agent if Insight Rabbit service bound" do

    end

    it "should not unpack and configure Insight agent if Insight Rabbit service not bound" do

    end

    it "should create a .profile.d with proxy sys props, connector port and heap size in JAVA_OPTS" do
      # TODO replace ruby set_environment for proxy, parameterized connector port,  -Xmx, -Xms, java.io.tmpdir?
      # TODO do warden containers already have tmpdir env variable?  how about mem settings passed too?
    end

    it "should add template server.xml to Tomcat" do
      LanguagePack::JavaWeb.new(tmpdir).compile
      server_xml = File.join(tmpdir,"conf","server.xml")
      File.exists?(server_xml).should == true
      File.read(server_xml).should include("http.port")
    end

    it "should provide a way for DEA to ensure app is up" do
      # droplet.yaml written by LifecycleListener?  How to write to root dir if buildpacks create app dir...
    end
  end

  describe "release" do
    it "should return the Tomcat start script as default web process" do
      LanguagePack::JavaWeb.new(tmpdir).release.should == {
          "addons" => [],
          "config_vars" => [],
          "default_process_types" => { "web" => "./bin/catalina.sh run" }
      }.to_yaml
    end
  end
end