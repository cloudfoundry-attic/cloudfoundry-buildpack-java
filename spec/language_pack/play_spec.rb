require "spec_helper"

describe LanguagePack::Play, type: :with_temp_dir do

  let(:tmpdir) { @tmpdir }

  describe "detect" do
    subject { LanguagePack::Play.use? }

    it "should be used if Play jar is present in unzipped app" do
      Dir.chdir(tmpdir) do
        FileUtils.mkdir_p("myapp/lib")
        FileUtils.touch("myapp/lib/play.play_2.9.1-2.0.1.jar")
        should eq true
      end
    end

    it "should be used if Play jar is present in staged app" do
      Dir.chdir(tmpdir) do
        FileUtils.mkdir_p("lib")
        FileUtils.touch("lib/play.play_2.9.1-2.0.1.jar")
        should eq true
      end
    end

    it "should not be used if jar file does not start with 'play.'" do
      Dir.chdir(tmpdir) do
        FileUtils.mkdir_p("lib")
        FileUtils.touch("lib/playfoo.jar")
        should eq false
      end
    end

    it "should not be used if Play jar is not present" do
      Dir.chdir(tmpdir) do
        FileUtils.mkdir_p("lib")
        FileUtils.touch("lib/foo.jar")
        should eq false
      end
    end
  end

  describe "compile" do
    let(:play_pack) { java_pack = LanguagePack::Play.new(tmpdir) }

    subject { play_pack.compile }

    before do
      play_pack.stub(:install_java)
      play_pack.stub(:install_database_drivers)
      FileUtils.mkdir_p("#{tmpdir}/myapp/lib")
      File.open("#{tmpdir}/myapp/start", 'w') do |f|
        f.write("exec java $* -cp \"`dirname $0`/lib/*\" play.core.server.NettyServer `dirname $0`")
      end
    end

    it "selects the right directory to copy" do
      FileUtils.mkdir_p("#{tmpdir}/some_other_dir")
      FileUtils.touch("#{tmpdir}/__EMPTY__")
      expect { subject }.not_to raise_error
    end

    it "copies the app from a named directory to root of droplet" do
      Dir.chdir(tmpdir) do
        FileUtils.touch("myapp/lib/play.play_2.9.1-2.0.1.jar")
        subject
        File.exists?("lib/play.play_2.9.1-2.0.1.jar").should == true
        File.exists?("myapp/lib/play.play_2.9.1-2.0.1.jar").should == false
      end
    end

    it "raises an Error if start script is missing" do
      Dir.chdir(tmpdir) do
        FileUtils.rm "myapp/start"
        FileUtils.touch("myapp/lib/play.play_2.9.1-2.0.1.jar")
        expect { subject }.to raise_error(/Play app not detected/)
      end
    end

    it "raises an error if lib dir is missing" do
      Dir.chdir(tmpdir) do
        FileUtils.rm_rf "myapp/lib"
        expect { subject }.to raise_error(/Play app not detected/)
      end
    end

    it "copies MySQL and Postgres drivers to lib dir" do
      Dir.chdir(tmpdir) do
        play_pack.unstub(:install_database_drivers)
        subject
        File.exists?("lib/mysql-connector-java-5.1.12.jar").should == true
        File.exists?("lib/postgresql-9.0-801.jdbc4.jar").should == true
      end
    end

    it "does not copy MySQL driver to lib dir if already present" do
      Dir.chdir(tmpdir) do
        play_pack.unstub(:install_database_drivers)
        FileUtils.touch("myapp/lib/mysql-connector-java-5.0.5.jar")
        subject
        File.exists?("lib/mysql-connector-java-5.1.12.jar").should == false
        File.exists?("lib/postgresql-9.0-801.jdbc4.jar").should == true
      end
    end

    it "does not copy Postgres driver to lib dir if already present" do
      Dir.chdir(tmpdir) do
        play_pack.unstub(:install_database_drivers)
        FileUtils.touch("myapp/lib/postgresql-9.0-763.jdbc4.jar")
        subject
        File.exists?("lib/mysql-connector-java-5.1.12.jar").should == true
        File.exists?("lib/postgresql-9.0-801.jdbc4.jar").should == false
      end
    end

    it "copies autostaging jar to lib dir" do
      Dir.chdir(tmpdir) do
        subject
        File.exists?("lib/auto-reconfiguration-0.6.5.jar").should == true
      end
    end

    it "enables autostaging bootstrap class in user's start script" do
      Dir.chdir(tmpdir) do
        subject
        File.read("start").should == "exec java $* -cp \"`dirname $0`/lib/*\" org.cloudfoundry.reconfiguration.play.Bootstrap `dirname $0`"
      end
    end

    it "should create a .profile.d with http port, tmpdir and heap size in JAVA_OPTS" do
      subject
      profiled = File.join(tmpdir,".profile.d","java.sh")
      File.exists?(profiled).should == true
      script = File.read(profiled)
      script.should include("-Xmx$MEMORY_LIMIT")
      script.should include("-Xms$MEMORY_LIMIT")
      script.should include("-Dhttp.port=$VCAP_APP_PORT")
      script.should include("-Djava.io.tmpdir=$TMPDIR")
    end
  end

  describe "release" do
    it "should return the user's start script as default web process" do
      LanguagePack::Play.new(tmpdir).release.should == {
          "addons" => [],
          "config_vars" => {},
          "default_process_types" => { "web" => "./start $JAVA_OPTS" }
      }.to_yaml
    end
  end
end
