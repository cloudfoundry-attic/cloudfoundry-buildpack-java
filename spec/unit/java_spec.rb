require "rspec"
require "tmpdir"
require "language_pack/java"

describe "Java Language Pack" do

  # TODO factor to helper?
  attr_reader :tmpdir

  before do
    @tmpdir = Dir.mktmpdir
  end

  after do
    FileUtils.rm_r(@tmpdir) if @tmpdir
  end

  describe "detect" do
    # TODO detect standalone java
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
      java_pack.compile
      script_body = File.read(File.join(tmpdir, ".profile.d", "java.sh"))
      script_body.should include <<-EXPECTED
export JAVA_HOME="$HOME/.jdk"
export PATH="$HOME/.jdk/bin:$PATH"
      EXPECTED
    end

    it "should create a .profile.d with heap size and tmpdir in JAVA_OPTS" do
      java_pack = LanguagePack::Java.new(tmpdir)
      java_pack.compile
      script_body = File.read(File.join(tmpdir, ".profile.d", "java.sh"))
      script_body.should include("export JAVA_OPTS=${JAVA_OPTS:--Xmx$MEMORY_LIMIT -Xms$MEMORY_LIMIT -Djava.io.tmpdir=$TMPDIR}")
    end

    it "should somehow support debug mode" do
      # TODO get debug env out of DEA and into this plugin.  Make DEA just pass debug mode in env variable (run or suspend)
    end
  end

  describe "release" do

    it "should not return default process types" do
      LanguagePack::Java.new(tmpdir).release.should == {
          "addons" => [],
          "config_vars" => [],
          "default_process_types" => {}
      }.to_yaml
    end

  end
end