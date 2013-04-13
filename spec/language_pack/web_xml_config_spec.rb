require 'spec_helper'

describe LanguagePack::WebXmlConfig do
  shared_examples "web xml tests with or without namespaces" do
    let(:context_params) do
      {
        contextConfigLocation: 'SOME_RANDOM_CONTEXT_CONFIG_LOCATION',
        contextConfigLocationAnnotationConfig: 'SOME_RANDOM_ANNOTATION',
        contextInitializerClasses: 'SOME_RANDOM_INIT_CLASS'
      }
    end
    let(:servlet_params) do
      {
        dispatcherServletClass: 'SOME_RANDOM_DISPATCHER'
      }
    end
    let(:default_app_context_location) { nil }
    let(:default_servlet_context_locations) { nil }
    let(:web_config) { LanguagePack::WebXmlConfig.new(xml, default_app_context_location, context_params, servlet_params, default_servlet_context_locations) }
    let(:mutated_xml) { XmlSimple.xml_in(web_config.xml, 'ForceArray' => false, 'AttrPrefix' => true, 'KeepRoot' => true) }

    describe '.new' do
      let(:default_app_context_location) { 'foo/bar' }
      let(:default_servlet_context_locations) { {"myservlet" => 'foo/my-servlet.xml'} }
      let(:xml) { "<web-app#{namespace_declaration}></web-app>" }

      subject { web_config }

      its(:xml) { should include '<web-app' }
      its(:xml) { should be_a String }
      its(:context_params) { should eq context_params }
      its(:servlet_params) { should eq servlet_params }
      its(:default_app_context_location) { should eq default_app_context_location }
      its(:default_servlet_context_locations) { should eq default_servlet_context_locations }
      its(:prefix) { should eq namespace }
    end

    describe '#configure_autostaging_context_param' do
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

          it "does not add it again" do
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

          context('and a contextClass param is present and set to the ANNOTATION_CONTEXT_CLASS') do
            let(:xml) { <<-XML
              <web-app>
                <context-param>
                  <param-name>contextConfigLocation</param-name>
                  <param-value>foo</param-value>
                </context-param>
                <context-param>
                  <param-name>contextClass</param-name>
                  <param-value>#{LanguagePack::WebXmlConfig::ANNOTATION_CONTEXT_CLASS}</param-value>
                </context-param>
              </web-app>
            XML
            }

            it "adds the annotation autoreconfig class to contextConfigLocation" do
              subject
              expect(mutated_xml["web-app"]["context-param"]).to eq([
                {"param-name" => 'contextConfigLocation',
                  "param-value" => "foo #{context_params[:contextConfigLocationAnnotationConfig]}"
                },
                {"param-name" => 'contextClass',
                  "param-value" => LanguagePack::WebXmlConfig::ANNOTATION_CONTEXT_CLASS
                }
              ])
            end

          end

          context("and a contextConfigLocationAnnotationConfig param is not specified") do
            let(:context_params) do
              {
                contextConfigLocation: 'SOME_RANDOM_CONTEXT_CONFIG_LOCATION'
              }
            end

            it "adds autoreconfig context to contextConfigLocation" do
              subject
              expect(mutated_xml["web-app"]["context-param"]).to eq(
                "param-name" => 'contextConfigLocation',
                "param-value" => "foo #{context_params[:contextConfigLocation]}"
              )
            end

          end

          context 'and it has whitespace in the param-value' do
            let(:original_param_value) { "\n   foo  \n" }
            let(:xml) { "<web-app><context-param><param-name>contextConfigLocation</param-name><param-value>#{original_param_value}</param-value></context-param></web-app>" }

            it "correctly understands the whitespace" do
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

            it "correctly understands the whitespace" do
              subject
              expect(mutated_xml["web-app"]["context-param"]).to eq(
                "param-name" => param_name,
                "param-value" => "foo #{context_params[:contextConfigLocation]}"
              )
            end
          end
        end

        context 'when it is not present' do
          let(:xml) { "<web-app><context-param><param-name>foobar</param-name><param-value>foo</param-value></context-param></web-app>" }

          context 'and there is an applicationContext.xml' do
            let(:default_app_context_location) { 'foo/bar/baz.xml' }

            context('and a contextClass param is present and set to the ANNOTATION_CONTEXT_CLASS') do
              let(:xml) { "<web-app><context-param><param-name>foobar</param-name><param-value>foo</param-value></context-param><context-param><param-name>contextClass</param-name><param-value>   #{LanguagePack::WebXmlConfig::ANNOTATION_CONTEXT_CLASS}</param-value></context-param></web-app>" }

              it "adds the annotation autoreconfig class to contextConfigLocation" do
                subject
                expect(mutated_xml["web-app"]["context-param"]).to eq([
                  {
                    "param-name" => 'foobar',
                    "param-value" => "foo"
                  },
                  {
                    "param-name" => 'contextClass',
                    "param-value" => "   #{LanguagePack::WebXmlConfig::ANNOTATION_CONTEXT_CLASS}"
                  },
                  {
                    "param-name" => 'contextConfigLocation',
                    "param-value" => "#{default_app_context_location} #{context_params[:contextConfigLocationAnnotationConfig]}"
                  }
                ])
              end

            end

            context 'and there is no ANNOTATION_CONTEXT_CLASS in contextClass' do
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

            context('and a contextConfigLocationAnnotationConfig is not defined') do
              let(:context_params) do
                {
                  contextConfigLocation: 'SOME_RANDOM_CONTEXT_CONFIG_LOCATION'
                }
              end

              it "adds autoreconfig context to contextConfigLocation" do
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
          end

          context 'and there is no applicationContext.xml' do
            let(:default_app_context_location) { nil }

            it "adds nothing" do
              subject
              expect(mutated_xml["web-app"]["context-param"]).to eq(
                "param-name" => 'foobar',
                "param-value" => "foo"
              )
            end
          end
        end
      end
    end

    describe '#configure_springenv_context_param' do
      subject { web_config.configure_springenv_context_param }

      context "when contextInitializerClasses is present" do
        let(:xml) { "<web-app><context-param><param-name>contextInitializerClasses</param-name><param-value>foo</param-value></context-param></web-app>" }

        it "appends auto-reconfig class" do
          subject
          expect(mutated_xml["web-app"]["context-param"]).to eq(
            "param-name" => 'contextInitializerClasses',
            "param-value" => "foo, #{context_params[:contextInitializerClasses]}"
          )
        end

        context 'and it has whitespace in the param-value' do
          let(:original_param_value) { "\n   foo  \n" }
          let(:xml) { "<web-app><context-param><param-name>contextInitializerClasses</param-name><param-value>#{original_param_value}</param-value></context-param></web-app>" }

          it "correctly understands the whitespace" do
            subject
            expect(mutated_xml["web-app"]["context-param"]).to eq(
              "param-name" => 'contextInitializerClasses',
              "param-value" => "#{original_param_value}, #{context_params[:contextInitializerClasses]}"
            )
          end
        end

        context 'and it has whitespace in the param-name' do
          let(:param_name) { "   contextInitializerClasses\n" }
          let(:xml) { "<web-app><context-param><param-name>#{param_name}</param-name><param-value>foo</param-value></context-param></web-app>" }

          it "correctly understands the whitespace" do
            subject
            expect(mutated_xml["web-app"]["context-param"]).to eq(
              "param-name" => param_name,
              "param-value" => "foo, #{context_params[:contextInitializerClasses]}"
            )
          end
        end
      end

      context "when contextInitializerClasses is not present" do
        let(:xml) { "<web-app><context-param><param-name>foo</param-name><param-value>bar</param-value></context-param></web-app>" }

        it "adds contextInitializerClasses param" do
          subject
          expect(mutated_xml["web-app"]["context-param"]).to eq([
            {
              "param-name" => 'foo',
              "param-value" => "bar"
            }, {
            "param-name" => 'contextInitializerClasses',
            "param-value" => context_params[:contextInitializerClasses]
          }
          ])
        end
      end

      context "when context-param is not present" do
        let(:xml) { "<web-app/>" }

        it "adds contextInitializerClasses param node" do
          subject
          expect(mutated_xml["web-app"]["context-param"]).to eq(
            "param-name" => 'contextInitializerClasses',
            "param-value" => context_params[:contextInitializerClasses]
          )
        end
      end
    end

    describe '#configure_autostaging_servlet' do
      let(:xml) { "<web-app><servlet><servlet-name>MyServlet</servlet-name><servlet-class>#{servlet_params[:dispatcherServletClass]}</servlet-class>#{init_param}</servlet></web-app>" }

      subject { web_config.configure_autostaging_servlet }

      context "when a single servlet with dispatcherServletClass exists" do

        context "and it has an init-param node with contextConfigLocation" do
          let(:init_param) { "<init-param><param-name>contextConfigLocation</param-name><param-value>someLocation</param-value></init-param>" }

          it "adds the autoconfig contextConfigLocation" do
            subject
            expect(mutated_xml["web-app"]["servlet"]["init-param"]).to eq(
              "param-name" => 'contextConfigLocation',
              "param-value" => "someLocation #{context_params[:contextConfigLocation]}"
            )
          end

          context('and a contextClass param is present and set to the ANNOTATION_CONTEXT_CLASS') do
            let(:init_param) { "<init-param><param-name>contextClass</param-name><param-value>#{LanguagePack::WebXmlConfig::ANNOTATION_CONTEXT_CLASS}</param-value></init-param><init-param><param-name>contextConfigLocation</param-name><param-value>someLocation</param-value></init-param>" }

            it "adds the annotation autoreconfig class to contextConfigLocation" do
              subject
              expect(mutated_xml["web-app"]["servlet"]["init-param"]).to eq([
                {"param-name" => 'contextClass',
                  "param-value" => LanguagePack::WebXmlConfig::ANNOTATION_CONTEXT_CLASS
                },
                {"param-name" => 'contextConfigLocation',
                  "param-value" => "someLocation #{context_params[:contextConfigLocationAnnotationConfig]}"
                }
              ])
            end

          end

          context 'and it has whitespace in the param-value' do
            let(:original_param_value) { "\n   foo  \n" }
            let(:init_param) { "<init-param><param-name>contextConfigLocation</param-name><param-value>#{original_param_value}</param-value></init-param>" }

            it "correctly understands the whitespace" do
              subject
              expect(mutated_xml["web-app"]["servlet"]["init-param"]).to eq(
                "param-name" => 'contextConfigLocation',
                "param-value" => "#{original_param_value} #{context_params[:contextConfigLocation]}"
              )
            end
          end

          context "and the param-value is blank" do
            let(:init_param) { "<init-param><param-name>contextConfigLocation</param-name><param-value></param-value></init-param>" }

            it "correctly understand the blank" do
              subject
              expect(mutated_xml["web-app"]["servlet"]["init-param"]).to eq(
                "param-name" => 'contextConfigLocation',
                "param-value" => {}
              )
            end
          end

          context 'and it has whitespace in the param-name' do
            let(:param_name) { "   contextConfigLocation\n" }
            let(:init_param) { "<init-param><param-name>#{param_name}</param-name><param-value>foo</param-value></init-param>" }

            it "correctly understands the whitespace" do
              subject
              expect(mutated_xml["web-app"]["servlet"]["init-param"]).to eq(
                "param-name" => param_name,
                "param-value" => "foo #{context_params[:contextConfigLocation]}"
              )
            end
          end
        end

        context "and it has no contextConfigLocation init-param node" do
          let(:init_param) { "" }

          context "and there is a servlet context file" do
            let(:default_servlet_context_locations) { {"MyServlet" => 'foo/my-servlet.xml'} }
            it "adds an contextConfigLocation initParam" do
              subject
              expect(mutated_xml["web-app"]["servlet"]["init-param"]).to eq(
                "param-name" => 'contextConfigLocation',
                "param-value" => "foo/my-servlet.xml #{context_params[:contextConfigLocation]}"
              )
            end

            context('and a contextClass param is present and set to the ANNOTATION_CONTEXT_CLASS') do
              let(:init_param) { "<init-param><param-name>contextClass</param-name><param-value>#{LanguagePack::WebXmlConfig::ANNOTATION_CONTEXT_CLASS}</param-value></init-param>" }

              it "adds the annotation autoreconfig class to contextConfigLocation" do
                subject
                expect(mutated_xml["web-app"]["servlet"]["init-param"]).to eq([
                  {"param-name" => 'contextClass',
                    "param-value" => LanguagePack::WebXmlConfig::ANNOTATION_CONTEXT_CLASS
                  },
                  {"param-name" => 'contextConfigLocation',
                    "param-value" => "foo/my-servlet.xml #{context_params[:contextConfigLocationAnnotationConfig]}"
                  }
                ])
              end

            end
          end

          context "and there is no servlet context file" do
            let(:default_servlet_context_locations) { nil }

            it "adds an contextConfigLocation initParam" do
              subject
              expect(mutated_xml["web-app"]["servlet"]["init-param"]).to eq(
                "param-name" => 'contextConfigLocation',
                "param-value" => context_params[:contextConfigLocation]
              )
            end

            context('and a contextClass param is present and set to the ANNOTATION_CONTEXT_CLASS') do
              let(:init_param) { "<init-param><param-name>contextClass</param-name><param-value>#{LanguagePack::WebXmlConfig::ANNOTATION_CONTEXT_CLASS}</param-value></init-param>" }

              it "adds the annotation autoreconfig class to contextConfigLocation" do
                subject
                expect(mutated_xml["web-app"]["servlet"]["init-param"]).to eq([
                  {"param-name" => 'contextClass',
                    "param-value" => LanguagePack::WebXmlConfig::ANNOTATION_CONTEXT_CLASS
                  },
                  {"param-name" => 'contextConfigLocation',
                    "param-value" => context_params[:contextConfigLocationAnnotationConfig]
                  }
                ])
              end

            end
          end
        end
      end

      context "when no servlets with dispatcherServletClass exist" do
        let(:xml) { "<web-app><servlet><servlet-name>MyServlet</servlet-name><servlet-class>someRandomServletClass</servlet-class></servlet></web-app>" }

        it "does not modify the XML" do
          subject
          expect(mutated_xml["web-app"]["servlet"]["init-param"]).to be_nil
        end
      end

      context "when multiple servlets with dispatcherServletClass exists" do

        context "and they have an init-param node with contextConfigLocation" do
          let(:xml) { <<-XML
            <web-app>
              <servlet>
                <servlet-name>MyServlet</servlet-name>
                <servlet-class>#{servlet_params[:dispatcherServletClass]}</servlet-class>
                <init-param>
                  <param-name>contextConfigLocation</param-name>
                  <param-value>someLocation</param-value>"
                </init-param>
              </servlet>
              <servlet>
                <servlet-name>OtherServlet</servlet-name>
                <servlet-class>#{servlet_params[:dispatcherServletClass]}</servlet-class>
                <init-param>
                  <param-name>contextConfigLocation</param-name>
                  <param-value>someOtherLocation</param-value>
                </init-param>
              </servlet>
            </web-app>
            XML
            }

          it "adds the autoconfig contextConfigLocation to both" do
            subject
            expect(mutated_xml["web-app"]["servlet"].find { |x| x["servlet-name"] == "MyServlet" }["init-param"]).to eq(
              "param-name" => 'contextConfigLocation',
              "param-value" => "someLocation #{context_params[:contextConfigLocation]}"
            )
            expect(mutated_xml["web-app"]["servlet"].find { |x| x["servlet-name"] == "OtherServlet" }["init-param"]).to eq(
              "param-name" => 'contextConfigLocation',
              "param-value" => "someOtherLocation #{context_params[:contextConfigLocation]}"
            )
          end
        end

        context "and they have no init-param nodes" do
          let(:xml) { <<-XML
                      <web-app>
                        <servlet>
                          <servlet-name>MyServlet</servlet-name>
                          <servlet-class>#{servlet_params[:dispatcherServletClass]}</servlet-class>
                        </servlet>
                        <servlet>
                          <servlet-name>OtherServlet</servlet-name>
                          <servlet-class>#{servlet_params[:dispatcherServletClass]}</servlet-class>
                        </servlet>
                      </web-app>
                      XML
                    }

          context "and there are servlet context files" do
            let(:default_servlet_context_locations) { {"MyServlet" => 'foo/my-servlet.xml', "OtherServlet" => 'bar/other-servlet.xml'} }
            it "adds contextConfigLocation initParams" do
              subject

              expect(mutated_xml["web-app"]["servlet"].find { |x| x["servlet-name"] == "MyServlet" }["init-param"]).to eq(
                "param-name" => 'contextConfigLocation',
                "param-value" => "foo/my-servlet.xml #{context_params[:contextConfigLocation]}"
              )
              expect(mutated_xml["web-app"]["servlet"].find { |x| x["servlet-name"] == "OtherServlet" }["init-param"]).to eq(
                "param-name" => 'contextConfigLocation',
                "param-value" => "bar/other-servlet.xml #{context_params[:contextConfigLocation]}"
              )
            end
          end

          context "and there are no servlet context files" do
            let(:default_servlet_context_locations) { nil }
            it "adds contextConfigLocation initParams" do
              subject
              expect(mutated_xml["web-app"]["servlet"].find { |x| x["servlet-name"] == "MyServlet" }["init-param"]).to eq(
                "param-name" => 'contextConfigLocation',
                "param-value" => context_params[:contextConfigLocation]
              )
              expect(mutated_xml["web-app"]["servlet"].find { |x| x["servlet-name"] == "OtherServlet" }["init-param"]).to eq(
                "param-name" => 'contextConfigLocation',
                "param-value" => context_params[:contextConfigLocation]
              )
            end
          end
        end
      end
    end
  end

  describe "Web XML without namespace declarations" do
    let(:namespace_declaration) { '' }
    let(:namespace) { '' }

    include_examples "web xml tests with or without namespaces"
  end

  describe "Web XML with namespace declarations" do
    let(:namespace_declaration) { " version=\"2.5\" xmlns=\"http://java.sun.com/xml/ns/javaee\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xsi:schemaLocation=\"http://java.sun.com/xml/ns/javaee http://java.sun.com/xml/ns/javaee/web-app_2_5.xsd\"" }
    let(:namespace) { "xmlns:" }

    include_examples "web xml tests with or without namespaces"
  end
end
