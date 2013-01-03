require "spec_helper"

describe LanguagePack::Java do

  # TODO factor to helper?
  attr_reader :tmpdir

  before do
    @tmpdir = Dir.mktmpdir
  end

  after do
    FileUtils.rm_r(@tmpdir) if @tmpdir
  end

  describe "detect" do
    it "should detect a Java app by recursive presence of a jar file" do
      Dir.chdir(tmpdir) do
        FileUtils.mkdir_p(File.join(tmpdir,"lib"))
        FileUtils.touch(File.join(tmpdir,"lib","foo.jar"))
        LanguagePack::Java.use?.should == true
      end
    end

    it "should detect a Java app by presence of a jar file in root dir" do
      Dir.chdir(tmpdir) do
        FileUtils.touch(File.join(tmpdir,"foo.jar"))
        LanguagePack::Java.use?.should == true
      end
    end

    it "should detect a Java app by recursive presence of a class file" do
      Dir.chdir(tmpdir) do
        FileUtils.mkdir_p(File.join(tmpdir,"lib"))
        FileUtils.touch(File.join(tmpdir,"lib","foo.class"))
        LanguagePack::Java.use?.should == true
      end
    end

    it "should detect a Java app by presence of a class file in root dir" do
      Dir.chdir(tmpdir) do
        FileUtils.touch(File.join(tmpdir,"foo.class"))
        LanguagePack::Java.use?.should == true
      end
    end

    it "should not detect a Java app if no jar or class files" do
      Dir.chdir(tmpdir) do
        LanguagePack::Java.use?.should == false
      end
    end
  end

  describe "compile" do

    it "should download and unpack Java with default version" do
      java_pack = LanguagePack::Java.new(tmpdir)
      java_pack.compile
      File.exists?(File.join(tmpdir, ".jdk", "bin", "java")).should == true
    end

    it "should download user-specified Java version" do
      # TODO how to specify? system.properties?
    end

    it "should create a .profile.d with Java in PATH and JAVA_HOME set" do
      java_pack = LanguagePack::Java.new(tmpdir)
      # TODO pass in Mock
      java_pack.stub(:install_java)
      java_pack.compile
      script_body = File.read(File.join(tmpdir, ".profile.d", "java.sh"))
      script_body.should include <<-EXPECTED
export JAVA_HOME="$HOME/.jdk"
export PATH="$HOME/.jdk/bin:$PATH"
      EXPECTED
    end

    it "should create a .profile.d with heap size and tmpdir in JAVA_OPTS" do
      java_pack = LanguagePack::Java.new(tmpdir)
      # TODO pass in Mock
      java_pack.stub(:install_java)
      java_pack.compile
      script_body = File.read(File.join(tmpdir, ".profile.d", "java.sh"))
      script_body.should include("-Xmx$MEMORY_LIMIT")
      script_body.should include("-Xms$MEMORY_LIMIT")
      script_body.should include("-Djava.io.tmpdir=$TMPDIR")
    end

    it "should somehow support debug mode" do
      # TODO get debug env out of DEA and into this plugin.  Make DEA just pass debug mode in env variable (run or suspend)
    end
  end

  describe "release" do

    it "should not return default process types" do
      LanguagePack::Java.new(tmpdir).release.should == {
          "addons" => [],
          "config_vars" => {},
          "default_process_types" => {}
      }.to_yaml
    end

  end
end