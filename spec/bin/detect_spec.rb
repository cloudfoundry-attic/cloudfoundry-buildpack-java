describe "detect" do
  BIN_DIR = File.expand_path("../../../bin", __FILE__)
  FIXTURES_DIR = File.expand_path("../../fixtures", __FILE__)

  subject { `#{BIN_DIR}/detect #{FIXTURES_DIR}/#{path}` }

  def self.it_succeeds
    it "exits 0" do
      subject
      expect($?).to be_success
    end
  end

  def self.it_fails
    it "exits 1" do
      subject
      expect($?).to_not be_success
    end
  end

  context "with a Grails app" do
    context "at the 'toplevel'" do
      let(:path) { "grails/toplevel" }
      it { should == "Grails\n" }
      it_succeeds
    end

    context "under /webapps" do
      let(:path) { "grails/under_webapps" }
      it { should == "Grails\n" }
      it_succeeds
    end
  end

  context "with a Java Web app" do
    context "at the 'toplevel'" do
      let(:path) { "java_web/toplevel" }
      it { should == "Java Web\n" }
      it_succeeds
    end

    context "under /webapps" do
      let(:path) { "java_web/under_webapps" }
      it { should == "Java Web\n" }
      it_succeeds
    end
  end

  context "with a Play app" do
    context "at the 'toplevel'" do
      let(:path) { "play/toplevel" }
      it { should == "Play\n" }
      it_succeeds
    end

    context "under some directory" do
      let(:path) { "play/nested" }
      it { should == "Play\n" }
      it_succeeds
    end
  end

  context "with a Java app" do
    context "when a .jar file is found" do
      let(:path) { "java/with_jar" }
      it { should == "Java\n" }
      it_succeeds
    end

    context "when a .class file is found" do
      let(:path) { "java/with_class" }
      it { should == "Java\n" }
      it_succeeds
    end
  end

  context "with a Spring app" do
    context "at the toplevel" do
      context "when classes/org/springframework exists" do
        let(:path) { "spring/toplevel/with_springframework_dir" }
        it { should == "Spring\n" }
        it_succeeds
      end

      context "when spring-core*.jar exists" do
        let(:path) { "spring/toplevel/with_spring_jar" }
        it { should == "Spring\n" }
        it_succeeds
      end

      context "when org.springframework.core*.jar exists" do
        let(:path) { "spring/toplevel/with_org_springframework_jar" }
        it { should == "Spring\n" }
        it_succeeds
      end
    end

    context "under /webapps" do
      context "when classes/org/springframework exists" do
        let(:path) { "spring/under_webapps/with_springframework_dir" }
        it { should == "Spring\n" }
        it_succeeds
      end

      context "when spring-core*.jar exists" do
        let(:path) { "spring/under_webapps/with_spring_jar" }
        it { should == "Spring\n" }
        it_succeeds
      end

      context "when org.springframework.core*.jar exists" do
        let(:path) { "spring/under_webapps/with_org_springframework_jar" }
        it { should == "Spring\n" }
        it_succeeds
      end
    end
  end

  context "when nothing is detected" do
    let(:path) { "none_of_the_above" }

    it { should == "no\n" }
    it_fails
  end
end
