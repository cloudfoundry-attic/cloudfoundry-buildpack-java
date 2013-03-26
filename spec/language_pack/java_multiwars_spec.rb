require "spec_helper"

describe LanguagePack::JavaMultiWars, type: :with_temp_dir do

  attr_reader :tmpdir, :java_multiwars

  let(:appdir) { File.join(tmpdir, "app") }

  before do
    @java_multiwars = LanguagePack::JavaMultiWars.new(appdir)
    # TODO pass in Mock
    @java_multiwars.stub(:install_java)
    
    Dir.chdir(tmpdir) do
      Dir.mkdir("app") 
      Dir.chdir(appdir) do
        java_multiwars.stub(:fetch_package) do |package|
          FileUtils.copy( File.expand_path("../../support/fake-tomcat.tar.gz", __FILE__), package)
        end
        java_multiwars.stub(:install_database_drivers)
      end
    end
  end

  describe "detect" do
    it "should be used if multi wars present" do
      Dir.chdir(appdir) do
        FileUtils.touch "a.war"
        FileUtils.touch "b.war"
        FileUtils.touch "c.war"
        FileUtils.mkdir "META-INF"
        puts Dir.pwd
        LanguagePack::JavaMultiWars.use?.should == true
      end
    end

    it "should not be used if no wars here" do
      Dir.chdir(appdir) do
        FileUtils.rm_r Dir.glob("*.war"), :force => true
        LanguagePack::JavaMultiWars.use?.should == false
      end
    end
  end

  describe "move web war to tomcat" do
    before do
       FileUtils.touch "#{appdir}/a.war"
       FileUtils.touch "#{appdir}/b.war"
       FileUtils.touch "#{appdir}/c.war"
    end

    it "should be able to  move the war files to the webapps folder of tomcat" do
      java_multiwars.stub(:install_tomcat)
      java_multiwars.compile
      war_file = File.join(appdir,"webapps","a.war")
      File.exists?(war_file).should == true
      war_file = File.join(appdir,"webapps","b.war")
      File.exists?(war_file).should == true
      war_file = File.join(appdir,"webapps","c.war")
      File.exists?(war_file).should == true
    end
  end 

  describe "release" do
     it "should return the Tomcat start script as default web process" do
       java_multiwars.release.should == {
         "addons" => [],
         "config_vars" => {},
          "default_process_types" => { "web" => "./bin/catalina.sh run" }
       }.to_yaml
     end
  end
end
