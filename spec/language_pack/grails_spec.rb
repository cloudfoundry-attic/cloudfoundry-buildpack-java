require "spec_helper"

describe LanguagePack::Grails, type: :with_temp_dir do
  describe 'detect' do
    let(:tmpdir) { @tmpdir }

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

  describe '#compile' do

  end

  describe '#name' do

  end
end