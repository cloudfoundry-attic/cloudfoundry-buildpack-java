require "spec_helper"

describe LanguagePack::Spring, type: :with_temp_dir do

  let(:tmpdir) { @tmpdir }

  describe "detect" do
    subject { LanguagePack::Spring.use? }

    it "should be used if Spring class is present" do
      Dir.chdir(tmpdir) do
        FileUtils.mkdir_p("WEB-INF/classes/org/springframework")
        should eq true
      end
    end

    it "should be used if Spring class is present in installed Tomcat dir" do
      Dir.chdir(tmpdir) do
        FileUtils.mkdir_p("webapps/ROOT/WEB-INF/classes/org/springframework")
        should eq true
      end
    end

    it "should be used if Spring jar with shortname is present" do
      Dir.chdir(tmpdir) do
        FileUtils.mkdir_p("WEB-INF/lib")
        FileUtils.touch "WEB-INF/lib/spring-core-2.5.6.jar"
        should eq true
      end
    end

    it "should be used if Spring jar with shortname is present in installed Tomcat dir" do
      Dir.chdir(tmpdir) do
        FileUtils.mkdir_p("webapps/ROOT/WEB-INF/lib")
        FileUtils.touch "webapps/ROOT/WEB-INF/lib/spring-core-2.5.6.jar"
        should eq true
      end
    end

    it "should be used if Spring jar with fullname is present" do
      Dir.chdir(tmpdir) do
        FileUtils.mkdir_p("WEB-INF/lib")
        FileUtils.touch "WEB-INF/lib/org.springframework.core-3.0.4.RELEASE.jar"
        should eq true
      end
    end

    it "should be used if Spring jar with fullname is present in installed Tomcat dir" do
      Dir.chdir(tmpdir) do
        FileUtils.mkdir_p("webapps/ROOT/WEB-INF/lib")
        FileUtils.touch "webapps/ROOT/WEB-INF/lib/org.springframework.core-3.0.4.RELEASE.jar"
        should eq true
      end
    end

    it "should not be used if no Spring classes or jars" do
      Dir.chdir(tmpdir) do
        should eq false
      end
    end

  end

  describe "compile" do

    let(:mock_web_xml_config) {mock("webxml")}
    let(:spring_pack) {LanguagePack::Spring.new(tmpdir, nil, mock_web_xml_config)}

    before do
      # TODO pass in Mock
      spring_pack.stub(:install_java)
      spring_pack.stub(:install_tomcat)
      spring_pack.stub(:install_database_drivers)
      Dir.chdir(tmpdir) do
        FileUtils.mkdir_p("WEB-INF/lib")
        FileUtils.mkdir_p("WEB-INF/classes")
      end

      spring_pack.stub(:fetch_package) do |package_name|
        FileUtils.touch(package_name)
      end
    end

    context "when auto-reconfig is explicitly enabled" do

      before do
        File.open(File.join("#{tmpdir}/WEB-INF/classes/system.properties"), 'w') do
          |f| f.write "spring.autoconfig=true"
        end

        mock_web_xml_config.should_receive("configure_autostaging_context_param")
        mock_web_xml_config.should_receive("configure_springenv_context_param")
        mock_web_xml_config.should_receive("configure_autostaging_servlet")
        mock_web_xml_config.should_receive("xml").and_return("somexmlforyoutosave")
      end

      it "should save modified web.xml" do
        spring_pack.compile
        expect(File.read(File.join(spring_pack.webapp_path, "WEB-INF", "web.xml"))).to eq "somexmlforyoutosave"
      end

      it "should have the auto reconfiguration jar in the webapp lib path" do
        spring_pack.compile
        File.exist?(File.join(spring_pack.webapp_path, "WEB-INF", "lib", LanguagePack::AutostagingHelpers::AUTOSTAGING_JAR)).should == true
      end
    end

    context "when auto-reconfig is implicitly enabled (enabled by default)" do
      before do
        mock_web_xml_config.should_receive("configure_autostaging_context_param")
        mock_web_xml_config.should_receive("configure_springenv_context_param")
        mock_web_xml_config.should_receive("configure_autostaging_servlet")
        mock_web_xml_config.should_receive("xml").and_return("somexmlforyoutosave")
      end

      it "should save modified web.xml" do
        spring_pack.compile
        expect(File.read(File.join(spring_pack.webapp_path, "WEB-INF", "web.xml"))).to eq "somexmlforyoutosave"
      end

      it "should have the auto reconfiguration jar in the webapp lib path" do
        spring_pack.compile
        File.exist?(File.join(spring_pack.webapp_path, "WEB-INF", "lib", LanguagePack::AutostagingHelpers::AUTOSTAGING_JAR)).should == true
      end
    end

    context "when auto-reconfig is disabled" do
      before do
        File.open(File.join("#{tmpdir}/WEB-INF/classes/system.properties"), 'w') do
          |f| f.write "spring.autoconfig=false"
        end
      end

      it "should not modify web.xml" do
        mock_web_xml_config.should_not_receive("configure_autostaging_context_param")
        mock_web_xml_config.should_not_receive("configure_springenv_context_param")
        mock_web_xml_config.should_not_receive("configure_autostaging_servlet")
        mock_web_xml_config.should_not_receive("xml")

        spring_pack.compile
        expect(File.exists?(File.join(spring_pack.webapp_path, "WEB-INF", "web.xml"))).to be_false

      end

      it "should have the auto reconfiguration jar in the webapp lib path" do
        spring_pack.compile
        expect(File.exists?(File.join(spring_pack.webapp_path, "WEB-INF", "lib", LanguagePack::AutostagingHelpers::AUTOSTAGING_JAR))).to be_false
      end

    end
  end

  describe "#default_app_context" do

    let(:spring_pack) {LanguagePack::Spring.new(tmpdir)}

    it "should return DEFAULT_APP_CONTEXT if file found" do
      Dir.chdir(tmpdir) do
        FileUtils.mkdir_p(File.join(spring_pack.webapp_path, "WEB-INF"))
        FileUtils.touch(File.join(spring_pack.webapp_path,"WEB-INF", "applicationContext.xml"))
        expect(spring_pack.default_app_context).to eq LanguagePack::Spring::DEFAULT_APP_CONTEXT
      end
    end

    it "should return nil if no default app context file found" do
      Dir.chdir(tmpdir) do
        FileUtils.mkdir_p(File.join(spring_pack.webapp_path, "WEB-INF"))
        expect(spring_pack.default_app_context).to be_nil
      end
    end
  end

  describe "#default_servlet_contexts" do

    let(:spring_pack) {LanguagePack::Spring.new(tmpdir)}

    it "should return a map of servlet names to file locations" do
      Dir.chdir(tmpdir) do
        FileUtils.mkdir_p(File.join(spring_pack.webapp_path, "WEB-INF"))
        FileUtils.touch(File.join(spring_pack.webapp_path,"WEB-INF", "myname-servlet.xml"))
        FileUtils.touch(File.join(spring_pack.webapp_path,"WEB-INF", "myothername-servlet.xml"))
        FileUtils.touch(File.join(spring_pack.webapp_path,"WEB-INF", "some.xml"))
        expect(spring_pack.default_servlet_contexts).to eq( {
          "myname" => "/WEB-INF/myname-servlet.xml",
          "myothername" => "/WEB-INF/myothername-servlet.xml"
        })
      end
    end

    it "should return an empty map when there are no servlet files" do
      Dir.chdir(tmpdir) do
        FileUtils.mkdir_p(File.join(spring_pack.webapp_path, "WEB-INF"))
        FileUtils.touch(File.join(spring_pack.webapp_path,"WEB-INF", "some.xml"))
        expect(spring_pack.default_servlet_contexts).to eq({})
      end
    end
  end
end
