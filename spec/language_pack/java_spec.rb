require "spec_helper"

describe LanguagePack::Java, type: :with_temp_dir do

  let(:tmpdir) { @tmpdir }

  describe "#use" do
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

  describe "#compile" do
    let(:java_pack) { java_pack = LanguagePack::Java.new(tmpdir) }
    let(:jdk_download) { make_scratch_dir(".jdk") + "/jdk.tar.gz" }

    before do
      java_pack.stub(:fetch_jdk_package) do |filename|
        FileUtils.copy(File.expand_path("../../support/fake-java.tar.gz", __FILE__), filename)
        filename
      end
    end

    it "should download and unpack Java with default version" do
      Dir.chdir(tmpdir) do
        java_pack.compile
        File.exists?(File.join(tmpdir, ".jdk", "bin", "java")).should == true
      end
    end

    it "should create a .profile.d with Java in PATH and JAVA_HOME set" do
      java_pack.compile
      script_body = File.read(File.join(tmpdir, ".profile.d", "java.sh"))
      script_body.should include <<-EXPECTED
export JAVA_HOME="$HOME/.jdk"
export PATH="$HOME/.jdk/bin:$PATH"
      EXPECTED
    end

    it "should create a .profile.d with heap size, tmpdir, and oom handler in JAVA_OPTS" do
      java_pack.compile
      script_body = File.read(File.join(tmpdir, ".profile.d", "java.sh"))
      script_body.should include("-Xmx$MEMORY_LIMIT")
      script_body.should include("-Xms$MEMORY_LIMIT")
      script_body.should include('-Djava.io.tmpdir=\"$TMPDIR\"')
# commented out for now due to removal of the oome functionality
#      script_body.should include('\"echo oome killing pid: %p && kill -9 %p\"')
    end

    it "should create a .profile.d with LANG set" do
      java_pack.compile
      script_body = File.read(File.join(tmpdir, ".profile.d", "java.sh"))
      script_body.should include 'export LANG="${LANG:-en_US.UTF-8}"'
    end

    describe "debug mode" do

      let(:java_script) { File.join(tmpdir, ".profile.d", "java.sh") }

      before do
        java_pack.compile
        FileUtils.chmod(0744, java_script)
      end

      context "set to suspend" do
        let(:debug_mode) { "suspend" }
        let(:java_opts) do
          `export MEMORY_LIMIT=10M
          export VCAP_DEBUG_PORT=80
          export VCAP_DEBUG_MODE=#{debug_mode}
          . #{java_script}
          echo $JAVA_OPTS`
        end

        it "should add debug opts when debug mode is set to suspend" do
          java_opts.should include '-Xdebug -Xrunjdwp:transport=dt_socket,address=80,server=y,suspend=y'
        end
      end


      context "set to run" do
        let(:debug_mode) { "run" }
        let(:java_opts) do
          `export MEMORY_LIMIT=10M
          export VCAP_DEBUG_PORT=80
          export VCAP_DEBUG_MODE=#{debug_mode}
          . #{java_script}
          echo $JAVA_OPTS`
        end

        it "should add debug opts when debug mode is set to run" do
          java_opts.should include '-Xdebug -Xrunjdwp:transport=dt_socket,address=80,server=y,suspend=n'
        end
      end

      context "not set" do
        let(:java_opts) do
          `export MEMORY_LIMIT=10M
          . #{java_script}
          echo $JAVA_OPTS`
        end

        it "should not add debug opts when debug mode is not set" do
          expect($?.exitstatus).to eq 0
          java_opts.should_not include ("-Xdebug")
        end
      end
    end
  end

  describe "#compile with invalid JDK" do
    let(:java_pack) { LanguagePack::Java.new(tmpdir) }
    let(:jdk_download) { make_scratch_dir(".jdk") + "/jdk.tar.gz" }

    before do
      java_pack.stub(:fetch_jdk_package) do |filename|
        FileUtils.copy(File.expand_path("../../support/junk.tar.gz", __FILE__), filename)
        filename
      end
    end

    it "should exit when the downloaded JDK is invalid" do
      expect {java_pack.compile}.to raise_error { |error|
        error.should be_a(SystemExit)
        error.status.should eq(1)
      }
    end
  end

  describe "#java_version" do
    let(:java_pack) { java_pack = LanguagePack::Java.new(tmpdir) }

    it "should detect user-specified Java version if system.properties file is in root dir" do
      Dir.chdir(tmpdir) do
        File.open(File.join("system.properties"), 'w') {|f| f.write "java.runtime.version=1.7" }
        java_pack.java_version.should == "1.7"
      end
    end

    it "should detect user-specified Java version if system.properties file is in a sub directory" do
      Dir.chdir(tmpdir) do
        FileUtils.mkdir_p("WEB-INF/config")
        File.open(File.join("WEB-INF", "config", "system.properties"), 'w') {|f| f.write "java.runtime.version=1.7" }
        java_pack.java_version.should == "1.7"
      end
    end

    it "should return default java version if system.properties is missing" do
      java_pack.java_version.should == LanguagePack::Java::DEFAULT_JDK_VERSION
    end

    it "should return default java version if system.properties does not contain a version property" do
      Dir.chdir(tmpdir) do
        File.open(File.join("system.properties"), 'w') {|f| f.write "foo=bar" }
        java_pack.java_version.should == LanguagePack::Java::DEFAULT_JDK_VERSION
      end
    end

    it "should return default java version if file is not a properties file" do
      Dir.chdir(tmpdir) do
        File.open(File.join("system.properties"), 'w') {|f| f.write "HELLO WORLD" }
        java_pack.java_version.should == LanguagePack::Java::DEFAULT_JDK_VERSION
      end
    end
  end

  describe "#jdk_download_url" do
    let(:java_pack) { java_pack = LanguagePack::Java.new(tmpdir) }
    let(:bad_version) { "1.4" }

    it "should raise an Error if an unsupported Java version is specified" do
      Dir.chdir(tmpdir) do
        FileUtils.mkdir_p("WEB-INF/config")
        File.open(File.join("WEB-INF", "config", "system.properties"), 'w') {|f| f.write "java.runtime.version=#{bad_version}" }
        expect { java_pack.download_jdk(anything) }.to raise_error(RuntimeError, "Unsupported Java version: #{bad_version}")
      end
    end

  end

  describe "#release" do

    it "should not return default process types" do
      LanguagePack::Java.new(tmpdir).release.should == {
          "addons" => [],
          "config_vars" => {},
          "default_process_types" => {}
      }.to_yaml
    end

  end
end
