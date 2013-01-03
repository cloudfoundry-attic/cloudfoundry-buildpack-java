require 'spec_helper'

describe LanguagePack::WebXmlConfig do
  let(:context_params) do
    {
        contextConfigLocation: 'SOME_RANDOM_CONTEXT_CONFIG_LOCATION',
        contextConfigLocationAnnotationConfig: 'org.cloudfoundry.reconfiguration.spring.web.CloudAppAnnotationConfigAutoReconfig',
        contextInitializerClasses: 'org.cloudfoundry.reconfiguration.spring.CloudApplicationContextInitializer'
    }
  end
  let(:servlet_params) do
    {
        dispatcherServletClass: "org.springframework.web.servlet.DispatcherServlet"
    }
  end

  describe '.new' do
    let(:default_app_context_location) { 'foo/bar' }
    let(:xml) { '<web-app></web-app>' }

    subject { LanguagePack::WebXmlConfig.new(xml, default_app_context_location, context_params, servlet_params) }

    its(:xml) { should include '<web-app' }
    its(:xml) { should be_a String }
    its(:context_params) { should eq context_params }
    its(:servlet_params) { should eq servlet_params }
    its(:default_app_context_location) { should eq default_app_context_location }
  end

  describe '#configure_autostaging_context_param' do
    let(:default_app_context_location) { nil }
    let(:web_config) { LanguagePack::WebXmlConfig.new(xml, default_app_context_location, context_params, servlet_params) }
    let(:mutated_xml) {  XmlSimple.xml_in(web_config.xml, 'ForceArray' => false, 'AttrPrefix' => true, 'KeepRoot' => true) }
    let(:xml) { "<web-app></web-app>" }

    subject { web_config.configure_autostaging_context_param }

    context 'when context-param does not exist' do
      context 'and there is an applicationContext.xml' do
        let(:default_app_context_location) { 'foo/bar/baz.xml' }

        it "adds contextConfigLocation" do
          subject
          expect(mutated_xml["web-app"]["context-param"]).to eq(
              "param-name" => 'contextConfigLocation',
              "param-value" => "#{default_app_context_location} #{context_params[:contextConfigLocation]}"
          )
        end
      end

      context 'and there is no applicationContext.xml' do
        let(:default_app_context_location) { nil }

        it "doesn't do anything" do
          subject
          expect(mutated_xml["web-app"]).not_to have_key "context-param"
        end
      end
    end

    describe 'context-param/contextConfigLocation (http://static.springsource.org/spring/docs/3.0.x/spring-framework-reference/html/beans.html)' do
      context 'when the contextConfigLocation is already pointing to the correct location' do
        let(:xml) { "<web-app><context-param><param-name>contextConfigLocation</param-name><param-value>#{context_params[:contextConfigLocation]}</param-value></context-param></web-app>" }

        it "adds autoreconfig context to contextConfigLocation" do
          subject
          expect(mutated_xml["web-app"]["context-param"]).to eq(
              "param-name" => 'contextConfigLocation',
              "param-value" => context_params[:contextConfigLocation]
          )
        end
      end

      context 'when its present' do
        let(:xml) { "<web-app><context-param><param-name>contextConfigLocation</param-name><param-value>foo</param-value></context-param></web-app>" }

        it "adds autoreconfig context to contextConfigLocation" do
          subject
          expect(mutated_xml["web-app"]["context-param"]).to eq(
              "param-name" => 'contextConfigLocation',
              "param-value" => "foo #{context_params[:contextConfigLocation]}"
          )
        end

        context 'and it has whitespace in the param-value' do
          let(:original_param_value) {"\n   foo  \n"}
          let(:xml) { "<web-app><context-param><param-name>contextConfigLocation</param-name><param-value>#{original_param_value}</param-value></context-param></web-app>" }

          it "adds autoreconfig context to contextConfigLocation" do
            subject
            expect(mutated_xml["web-app"]["context-param"]).to eq(
                "param-name" => 'contextConfigLocation',
                "param-value" => "#{original_param_value} #{context_params[:contextConfigLocation]}"
            )
          end
        end

        context 'and it has whitespace in the param-name' do
          let(:param_name) { "   contextConfigLocation\n" }
          let(:xml) { "<web-app><context-param><param-name>#{param_name}</param-name><param-value>foo</param-value></context-param></web-app>" }

          it "adds autoreconfig context to contextConfigLocation" do
            subject
            expect(mutated_xml["web-app"]["context-param"]).to eq(
                "param-name" => param_name,
                "param-value" => "foo #{context_params[:contextConfigLocation]}"
            )
          end
        end
      end

      context 'when is not present' do
        let(:xml) { "<web-app><context-param><param-name>foobar</param-name><param-value>foo</param-value></context-param></web-app>" }

        context 'and there is an applicationContext.xml' do
          let(:default_app_context_location) { 'foo/bar/baz.xml' }

          it "adds contextConfigLocation" do
            subject
            expect(mutated_xml["web-app"]["context-param"]).to eq([
                {
                  "param-name" => 'foobar',
                  "param-value" => "foo"
                }, {
                  "param-name" => 'contextConfigLocation',
                  "param-value" => "#{default_app_context_location} #{context_params[:contextConfigLocation]}"
                }
            ])
          end
        end

        context 'and there is no applicationContext.xml' do
          let(:default_app_context_location) { nil }
        end
      end
    end
  end

  describe '#configure_springenv'
end