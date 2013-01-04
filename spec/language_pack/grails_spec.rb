require "spec_helper"

describe LanguagePack::Grails, type: :with_temp_dir do

  let(:tmpdir) { @tmpdir }

  describe 'detect' do

    subject { LanguagePack::Grails.use? }

    shared_examples "detection tests" do
      it "detects a Grails app in grails-web directory" do
        Dir.chdir(tmpdir) do
          FileUtils.mkdir_p("#{root_dir}WEB-INF/lib/grails-web")
          FileUtils.touch("#{root_dir}WEB-INF/lib/grails-web/foo.jar")
          should eq true
        end
      end

      it "does not detect a Grails app if a jar is not present in the grails-web dir" do
        Dir.chdir(tmpdir) do
          FileUtils.mkdir_p("#{root_dir}WEB-INF/lib/grails-web")
          should eq false
        end
      end
    end

    context 'when the app is in the root dir' do
      let(:root_dir) { '' }
      include_examples "detection tests"
    end

    context 'when the app is in the tomcat dir' do
      let(:root_dir) { 'webapps/ROOT/' }
      include_examples "detection tests"
    end
  end

  describe 'compile' do

    let(:mock_web_xml_config) { mock("webxml") }
    let(:grails_pack) { LanguagePack::Grails.new(tmpdir, nil, mock_web_xml_config) }

    before do
      # TODO pass in Mock
      grails_pack.stub(:install_java)
      grails_pack.stub(:install_tomcat)
      grails_pack.stub(:install_database_drivers)
      Dir.chdir(tmpdir) do
        FileUtils.mkdir_p("WEB-INF/lib")
      end

    end

    context "when a grails.xml file is present" do

      before do
        Dir.chdir(tmpdir) do
          FileUtils.mkdir_p("WEB-INF")
        end
      end

      context "and it does not contain the vmc plugin" do
        before do
          Dir.chdir(tmpdir) do
            File.open(File.join("WEB-INF", "grails.xml"), 'w') {|f| f.write("<root/>") }
          end
          mock_web_xml_config.should_receive("configure_autostaging_context_param")
          mock_web_xml_config.should_receive("configure_autostaging_servlet")
          mock_web_xml_config.should_receive("xml").and_return("somexmlforyoutosave")
        end

        it "should configure autostaging" do
          grails_pack.compile
        end

        it "should save modified web.xml" do
          grails_pack.compile
          expect(File.read(File.join(grails_pack.webapp_path, "WEB-INF", "web.xml"))).to eq "somexmlforyoutosave"
        end

        it "should have the auto reconfiguration jar in the webapp lib path" do
          grails_pack.compile
          File.exist?(File.join(grails_pack.webapp_path, "WEB-INF", "lib", LanguagePack::Spring::AUTOSTAGING_JAR)).should == true
        end
      end

      context "and it contains the vmc plugin" do
        before do
          Dir.chdir(tmpdir) do
            File.open(File.join("WEB-INF", "grails.xml"), 'w') {|f| f.write("<plugins><plugin>CloudFoundryGrailsPlugin</plugin></plugins>") }
          end
        end

        it "should not configure autostaging" do
          grails_pack.compile
          File.exist?(File.join(grails_pack.webapp_path, "WEB-INF", "lib", LanguagePack::Spring::AUTOSTAGING_JAR)).should == false
        end
      end

      context "and it contains the vmc plugin with a namespace in the root document" do
        before do
          Dir.chdir(tmpdir) do
            File.open(File.join("WEB-INF", "grails.xml"), 'w') {|f| f.write("<plugins xmlns=\"http://java.sun.com/xml/ns/javaee\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xsi:schemaLocation=\"http://java.sun.com/xml/ns/javaee http://java.sun.com/xml/ns/javaee/web-app_2_5.xsd\"><plugin>CloudFoundryGrailsPlugin</plugin></plugins>") }
          end
        end

        it "should not configure autostaging" do
          grails_pack.compile
          File.exist?(File.join(grails_pack.webapp_path, "WEB-INF", "lib", LanguagePack::Spring::AUTOSTAGING_JAR)).should == false
        end
      end
    end

    context "when a grails.xml file is not present" do

      before do
        mock_web_xml_config.should_receive("configure_autostaging_context_param")
        mock_web_xml_config.should_receive("configure_autostaging_servlet")
        mock_web_xml_config.should_receive("xml").and_return("somexmlforyoutosave")
      end

      it "should configure autostaging" do
        grails_pack.compile
      end

      it "should save modified web.xml" do
        grails_pack.compile
        expect(File.read(File.join(grails_pack.webapp_path, "WEB-INF", "web.xml"))).to eq "somexmlforyoutosave"
      end

      it "should have the auto reconfiguration jar in the webapp lib path" do
        grails_pack.compile
        File.exist?(File.join(grails_pack.webapp_path, "WEB-INF", "lib", LanguagePack::Spring::AUTOSTAGING_JAR)).should == true
      end
    end
  end

end