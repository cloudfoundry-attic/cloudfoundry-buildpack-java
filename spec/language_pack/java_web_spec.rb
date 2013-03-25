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

  describe "detect" do

    it "should be used if web.xml present" do
      Dir.chdir(appdir) do
        FileUtils.touch "WEB-INF/web.xml"
        LanguagePack::JavaWeb.use?.should == true
      end
    end

    it "should not be used if no web.xml" do
      Dir.chdir(appdir) do
        LanguagePack::JavaWeb.use?.should == false
      end
    end

    it "should have hint file after detecting" do
      java_web_pack.compile do |jwp|
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

    it "should unpack and configure Insight agent if Insight Rabbit service bound" do

    end

    it "should not unpack and configure Insight agent if Insight Rabbit service not bound" do

    end
  end

  describe "release" do
  end
end
