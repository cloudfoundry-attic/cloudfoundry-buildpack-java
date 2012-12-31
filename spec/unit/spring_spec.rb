require "tmpdir"
require "language_pack/spring"
require "rspec"

CLOUD_APPLICATION_CONTEXT_INITIALIZER = 'org.cloudfoundry.reconfiguration.spring.CloudApplicationContextInitializer'
CLOUD_APP_ANNOTATION_CONFIG_CLASS = 'org.cloudfoundry.reconfiguration.spring.web.CloudAppAnnotationConfigAutoReconfig'
AUTOSTAGING_JAR = "auto-reconfiguration-0.6.5.jar"

describe "Spring Language Pack" do

  attr_reader :tmpdir, :spring_pack

  before do
    @tmpdir = Dir.mktmpdir
    @spring_pack = LanguagePack::Spring.new(tmpdir)
    # TODO pass in Mock
    @spring_pack.stub(:install_java)
  end

  after do
    FileUtils.rm_r(@tmpdir) if @tmpdir
  end

  describe "detect" do

    it "should be used if Spring class is present" do
      Dir.chdir(tmpdir) do
        FileUtils.mkdir_p("WEB-INF/classes/org/springframework")
        LanguagePack::Spring.use?.should == true
      end
    end

    it "should be used if Spring class is present in installed Tomcat dir" do
      Dir.chdir(tmpdir) do
        FileUtils.mkdir_p("webapps/ROOT/WEB-INF/classes/org/springframework")
        LanguagePack::Spring.use?.should == true
      end
    end

    it "should be used if Spring jar with shortname is present" do
      Dir.chdir(tmpdir) do
        FileUtils.mkdir_p("WEB-INF/lib")
        FileUtils.touch "WEB-INF/lib/spring-core-2.5.6.jar"
        LanguagePack::Spring.use?.should == true
      end
    end

    it "should be used if Spring jar with shortname is present in installed Tomcat dir" do
      Dir.chdir(tmpdir) do
        FileUtils.mkdir_p("webapps/ROOT/WEB-INF/lib")
        FileUtils.touch "webapps/ROOT/WEB-INF/lib/spring-core-2.5.6.jar"
        LanguagePack::Spring.use?.should == true
      end
    end

    it "should be used if Spring jar with fullname is present" do
      Dir.chdir(tmpdir) do
        FileUtils.mkdir_p("WEB-INF/lib")
        FileUtils.touch "WEB-INF/lib/org.springframework.core-3.0.4.RELEASE.jar"
        LanguagePack::Spring.use?.should == true
      end
    end

    it "should be used if Spring jar with fullname is present in installed Tomcat dir" do
      Dir.chdir(tmpdir) do
        FileUtils.mkdir_p("webapps/ROOT/WEB-INF/lib")
        FileUtils.touch "webapps/ROOT/WEB-INF/lib/org.springframework.core-3.0.4.RELEASE.jar"
        LanguagePack::Spring.use?.should == true
      end
    end

    it "should not be used if no Spring classes or jars" do
      Dir.chdir(tmpdir) do
        LanguagePack::Spring.use?.should == false
      end
    end

  end

  describe "compile" do

    before do
      @spring_pack.stub(:install_tomcat)
      @spring_pack.stub(:install_database_drivers)
      Dir.chdir(tmpdir) do
        FileUtils.mkdir_p("WEB-INF/lib")
      end
    end

    describe "A Spring web application without a context-param in its web config and without a default application context config" do
      before do
        copy_app_resources("spring_no_context_config", tmpdir)
      end

      it "should have a 'contextInitializerClasses' context-param with only the CloudApplicationContextInitializer" do
        spring_pack.compile
        assert_context_param tmpdir, 'contextInitializerClasses', CLOUD_APPLICATION_CONTEXT_INITIALIZER
      end

      it "should have the auto reconfiguration jar in the webapp lib path" do
        spring_pack.compile
        File.exist?(File.join(spring_pack.webapp_path, "WEB-INF", "lib", AUTOSTAGING_JAR)).should == true
      end
    end

    describe "A Spring web application without a context-param in its web config and with a default application context config" do
      before do
        copy_app_resources("spring_default_appcontext_no_context_config", tmpdir)
      end

      it "should have a context-param in its web config after staging" do
        spring_pack.compile
        web_config_file = File.join(spring_pack.webapp_path, "WEB-INF", "web.xml")
        File.exist?(web_config_file).should == true

        web_config = Nokogiri::XML(open(web_config_file))
        context_param_node =  web_config.xpath("//context-param")
        context_param_node.length.should_not == 0
      end

      it "should have a 'contextConfigLocation' where the default application context precedes the auto-reconfiguration context" do
        spring_pack.compile
        web_config_file = File.join(spring_pack.webapp_path, "WEB-INF", "web.xml")
        web_config = Nokogiri::XML(open(web_config_file))
        context_param_name_node = web_config.xpath("//context-param[contains(normalize-space(param-name), normalize-space('contextConfigLocation'))]")
        context_param_name_node.length.should_not == 0

        context_param_value_node = context_param_name_node.first.xpath("param-value")
        context_param_value_node.length.should_not == 0

        context_param_value = context_param_value_node.first.content
        default_context_index = context_param_value.index("/WEB-INF/applicationContext.xml")
        default_context_index.should_not == nil

        auto_reconfig_context_index = context_param_value.index("classpath:META-INF/cloud/cloudfoundry-auto-reconfiguration-context.xml")
        auto_reconfig_context_index.should_not == nil

        auto_reconfig_context_index.should > default_context_index + "/WEB-INF/applicationContext.xml".length
      end

      it "should have a 'contextInitializerClasses' context-param with only the CloudApplicationContextInitializer" do
        spring_pack.compile
        assert_context_param(tmpdir, 'contextInitializerClasses', CLOUD_APPLICATION_CONTEXT_INITIALIZER)
      end

      it "should have the auto reconfiguration jar in the webapp lib path" do
        spring_pack.compile
        File.exist?(File.join(spring_pack.webapp_path, "WEB-INF", "lib", AUTOSTAGING_JAR)).should == true
      end

    end

    describe "A Spring web application with a context-param but without a 'contextConfigLocation' param-name in its web " +
                 "config and with a default application context config" do
      before do
        copy_app_resources("spring_default_appcontext_context_param_no_context_config", tmpdir)
      end

      it "should have a 'contextConfigLocation' where the default application context precedes the auto-reconfiguration context" do
        spring_pack.compile
        web_config = Nokogiri::XML(open(File.join(spring_pack.webapp_path, "WEB-INF", "web.xml")))
        context_param_name_node = web_config.xpath("//context-param[contains(normalize-space(param-name), normalize-space('contextConfigLocation'))]")
        context_param_name_node.length.should_not == 0

        context_param_value_node = context_param_name_node.first.xpath("param-value")
        context_param_value_node.length.should_not == 0

        context_param_value = context_param_value_node.first.content
        default_context_index = context_param_value.index('/WEB-INF/applicationContext.xml')
        default_context_index.should_not == nil

        auto_reconfig_context_index = context_param_value.index('classpath:META-INF/cloud/cloudfoundry-auto-reconfiguration-context.xml')
        auto_reconfig_context_index.should_not == nil

        auto_reconfig_context_index.should > default_context_index + "/WEB-INF/applicationContext.xml".length
      end

      it "should have a 'contextInitializerClasses' context-param with only the CloudApplicationContextInitializer" do
        spring_pack.compile
        assert_context_param tmpdir, 'contextInitializerClasses', CLOUD_APPLICATION_CONTEXT_INITIALIZER
      end

      it "should have the auto reconfiguration jar in the webapp lib path" do
        spring_pack.compile
        File.exist?(File.join(spring_pack.webapp_path,"WEB-INF", "lib", AUTOSTAGING_JAR)).should == true
      end
    end

    describe "A Spring web application with a context-param containing a 'contextConfigLocation' of 'foo' in its web config" do
      before do
        copy_app_resources("spring_context_config_foo",tmpdir)
      end

      it "should have the 'foo' context precede the auto-reconfiguration context in the 'contextConfigLocation' param-value" do
        spring_pack.compile
        web_config = Nokogiri::XML(open(File.join(spring_pack.webapp_path, "WEB-INF", "web.xml")))
        context_param_name_node = web_config.xpath("//context-param[contains(normalize-space(param-name), normalize-space('contextConfigLocation'))]").first
        context_param_value_node = context_param_name_node.xpath("param-value")
        context_param_value = context_param_value_node.first.content
        foo_index = context_param_value.index('foo')
        foo_index.should_not == nil

        auto_reconfig_context_index = context_param_value.index('classpath:META-INF/cloud/cloudfoundry-auto-reconfiguration-context.xml')
        auto_reconfig_context_index.should_not == nil

        auto_reconfig_context_index.should > foo_index + "foo".length
      end

      it "should have a 'contextInitializerClasses' context-param with only the CloudApplicationContextInitializer" do
        spring_pack.compile
        assert_context_param tmpdir, 'contextInitializerClasses', CLOUD_APPLICATION_CONTEXT_INITIALIZER
      end
    end

    describe "A Spring web application with a context-param containing a 'contextInitializerClasses' of 'foo' in its web config" do
      before do
        copy_app_resources("spring_context_initializer_foo", tmpdir)
      end

      it "should have the 'foo' initializer precede the auto-reconfiguration initializer 'contextInitializerClasses' param-value" do
        spring_pack.compile
        assert_context_param tmpdir, 'contextInitializerClasses', "foo, #{CLOUD_APPLICATION_CONTEXT_INITIALIZER}"
      end

      it "should have the auto reconfiguration jar in the webapp lib path" do
        spring_pack.compile
        File.exist?(File.join(spring_pack.webapp_path,"WEB-INF", "lib", AUTOSTAGING_JAR)).should == true
      end
    end

    describe "A Spring web application without a Spring DispatcherServlet in its web config" do
      before do
        copy_app_resources("spring_context_config_foo", tmpdir)
      end

      it "should have a 'contextInitializerClasses' context-param with only the CloudApplicationContextInitializer" do
        spring_pack.compile
        assert_context_param tmpdir, 'contextInitializerClasses', CLOUD_APPLICATION_CONTEXT_INITIALIZER
      end

      it "should have the auto reconfiguration jar in the webapp lib path" do
        spring_pack.compile
        File.exist?(File.join(spring_pack.webapp_path,"WEB-INF", "lib", AUTOSTAGING_JAR)).should == true
      end
    end

    describe "A Spring web application with a Spring DispatcherServlet in its web config that does not have a default " +
                 "servlet context config or an 'init-param' config" do
      before do
        copy_app_resources("spring_servlet_no_init_param", tmpdir)
      end

      it "should have a init-param in its web config after staging" do
        spring_pack.compile
        web_config_file = File.join(spring_pack.webapp_path, "WEB-INF", "web.xml")
        File.exist?(web_config_file).should == true

        web_config = Nokogiri::XML(open(web_config_file))
        init_param_node =  web_config.xpath("//init-param")
        init_param_node.length.should_not == 0
      end

      it "should have a 'contextConfigLocation' that includes the auto-reconfiguration context in its init-param" do
        spring_pack.compile
        web_config = Nokogiri::XML(open(File.join(spring_pack.webapp_path, "WEB-INF", "web.xml")))
        init_param_name_node = web_config.xpath("//init-param[contains(normalize-space(param-name), normalize-space('contextConfigLocation'))]")
        init_param_name_node.length.should_not == 0

        init_param_value_node = init_param_name_node.xpath("param-value")
        init_param_value_node.length.should_not == 0

        init_param_value = init_param_value_node.first.content
        auto_reconfig_context_index = init_param_value.index('classpath:META-INF/cloud/cloudfoundry-auto-reconfiguration-context.xml')
        auto_reconfig_context_index.should_not == nil
      end

      it "should have a 'contextInitializerClasses' context-param with only the CloudApplicationContextInitializer" do
        spring_pack.compile
        assert_context_param tmpdir, 'contextInitializerClasses', CLOUD_APPLICATION_CONTEXT_INITIALIZER
      end

      it "should have the auto reconfiguration jar in the webapp lib path" do
        spring_pack.compile
        File.exist?(File.join(spring_pack.webapp_path,"WEB-INF", "lib", AUTOSTAGING_JAR)).should == true
      end
    end

    describe "A Spring web application with a Spring DispatcherServlet in its web config and containing a default " +
                 "servlet context config but no 'init-param' config" do
      before do
        copy_app_resources("spring_default_servletcontext_no_init_param", tmpdir)
      end

      it "should have a init-param in its web config after staging" do
        spring_pack.compile
        web_config_file = File.join(spring_pack.webapp_path, "WEB-INF", "web.xml")
        File.exist?(web_config_file).should == true

        web_config = Nokogiri::XML(open(web_config_file))
        init_param_node =  web_config.xpath("//init-param")
        init_param_node.length.should_not == 0
      end

      it "should have the default servlet context precede the auto-reconfiguration context in the DispatcherServlet's " +
             "'contextConfigLocation' param-value" do
        spring_pack.compile
        web_config = Nokogiri::XML(open(File.join(spring_pack.webapp_path, "WEB-INF", "web.xml")))
        init_param_name_node = web_config.xpath("//init-param[contains(normalize-space(param-name), normalize-space('contextConfigLocation'))]")
        init_param_name_node.length.should_not == 0

        init_param_value_node = init_param_name_node.xpath("param-value")
        init_param_value_node.length.should_not == 0

        init_param_value = init_param_value_node.first.content
        dispatcher_servlet_index = init_param_value.index('/WEB-INF/dispatcher-servlet.xml')
        dispatcher_servlet_index.should_not == nil

        auto_reconfiguration_context_index = init_param_value.index('classpath:META-INF/cloud/cloudfoundry-auto-reconfiguration-context.xml')
        auto_reconfiguration_context_index.should_not == nil

        auto_reconfiguration_context_index.should > dispatcher_servlet_index + "/WEB-INF/dispatcher-servlet.xml".length
      end

      it "should have a 'contextInitializerClasses' context-param with only the CloudApplicationContextInitializer" do
        spring_pack.compile
        assert_context_param tmpdir, 'contextInitializerClasses', CLOUD_APPLICATION_CONTEXT_INITIALIZER
      end

      it "should have the auto reconfiguration jar in the webapp lib path" do
        spring_pack.compile
        File.exist?(File.join(spring_pack.webapp_path,"WEB-INF", "lib", AUTOSTAGING_JAR)).should == true
      end
    end

    describe "A Spring web application with a Spring DispatcherServlet in its web config and containing a default servlet context config but no 'contextConfigLocation' in its 'init-param' config" do
      before do
        copy_app_resources("spring_default_servletcontext_init_param_no_context_config", tmpdir)
      end

      it "should have the default servlet context precede the auto-reconfiguration context in the DispatcherServlet's 'contextConfigLocation' param-value" do
        spring_pack.compile
        web_config = Nokogiri::XML(open(File.join(spring_pack.webapp_path, "WEB-INF", "web.xml")))
        init_param_name_node = web_config.xpath("//init-param[contains(normalize-space(param-name), normalize-space('contextConfigLocation'))]")
        init_param_name_node.length.should_not == 0

        init_param_value_node = init_param_name_node.xpath("param-value")
        init_param_value_node.length.should_not == 0

        init_param_value = init_param_value_node.first.content
        dispatcher_servlet_index = init_param_value.index('/WEB-INF/dispatcher-servlet.xml')
        dispatcher_servlet_index.should_not == nil

        auto_reconfig_context_index = init_param_value.index('classpath:META-INF/cloud/cloudfoundry-auto-reconfiguration-context.xml')
        auto_reconfig_context_index.should_not == nil

        auto_reconfig_context_index.should > dispatcher_servlet_index + "/WEB-INF/dispatcher-servlet.xml".length
      end

      it "should have a 'contextInitializerClasses' context-param with only the CloudApplicationContextInitializer" do
        spring_pack.compile
        assert_context_param tmpdir, 'contextInitializerClasses', CLOUD_APPLICATION_CONTEXT_INITIALIZER
      end

      it "should have the auto reconfiguration jar in the webapp lib path" do
        spring_pack.compile
        File.exist?(File.join(spring_pack.webapp_path,"WEB-INF", "lib", AUTOSTAGING_JAR)).should == true
      end

    end

    describe "A Spring web application with a Spring DispatcherServlet in its web config with an 'init-param' config containing a 'contextConfigLocation' of 'foo' in its web config" do
      before do
        copy_app_resources("spring_servlet_context_config_foo", tmpdir)
      end

      it "should have the 'foo' context precede the auto-reconfiguration context in the DispatcherServlet's 'contextConfigLocation' param-value" do
        spring_pack.compile
        web_config = Nokogiri::XML(open(File.join(spring_pack.webapp_path, "WEB-INF", "web.xml")))
        init_param_name_node = web_config.xpath("//init-param[contains(normalize-space(param-name), normalize-space('contextConfigLocation'))]")
        init_param_name_node.length.should_not == 0

        init_param_value_node = init_param_name_node.xpath("param-value")
        init_param_value_node.length.should_not == 0

        init_param_value = init_param_value_node.first.content
        foo_index = init_param_value.index('foo')
        foo_index.should_not == nil

        auto_reconfig_context_index = init_param_value.index('classpath:META-INF/cloud/cloudfoundry-auto-reconfiguration-context.xml')
        auto_reconfig_context_index.should_not == nil

        auto_reconfig_context_index.should > foo_index + "foo".length
      end

      it "should have a 'contextInitializerClasses' context-param with only the CloudApplicationContextInitializer" do
        spring_pack.compile
        assert_context_param tmpdir, 'contextInitializerClasses', CLOUD_APPLICATION_CONTEXT_INITIALIZER
      end

      it "should have the auto reconfiguration jar in the webapp lib path" do
        spring_pack.compile
        File.exist?(File.join(spring_pack.webapp_path,"WEB-INF", "lib", AUTOSTAGING_JAR)).should == true
      end
    end


    describe "A Spring web application with 2 Spring DispatcherServlet in its web config containing a default servlet context config but no 'init-param' configs" do
      before do
        copy_app_resources("spring_multiple_dispatcherservlets_no_init_param", tmpdir)
      end

      it "should have 2 init-params in its web config after staging" do
        spring_pack.compile
        web_config_file = File.join(spring_pack.webapp_path, "WEB-INF", "web.xml")
        File.exist?(web_config_file).should == true

        web_config = Nokogiri::XML(open(web_config_file))
        init_param_node =  web_config.xpath("//init-param")
        init_param_node.length.should == 2
      end

      it "the 2 init-params in its web config after staging should be valid" do
        spring_pack.compile
        web_config_file = File.join(spring_pack.webapp_path, "WEB-INF", "web.xml")
        File.exist?(web_config_file).should == true

        web_config = Nokogiri::XML(open(web_config_file))
        init_param_nodes =  web_config.xpath("//init-param")
        init_param_nodes.each do |init_param_node|
          init_param_name_node = init_param_node.xpath("param-name")
          init_param_name_node.length.should == 1

          init_param_value_node = init_param_node.xpath("param-value")
          init_param_value_node.length.should == 1
        end
      end

      it "should have a 'contextInitializerClasses' context-param with only the CloudApplicationContextInitializer" do
        spring_pack.compile
        assert_context_param tmpdir, 'contextInitializerClasses', CLOUD_APPLICATION_CONTEXT_INITIALIZER
      end

      it "should have the auto reconfiguration jar in the webapp lib path" do
        spring_pack.compile
        File.exist?(File.join(spring_pack.webapp_path,"WEB-INF", "lib", AUTOSTAGING_JAR)).should == true
      end

    end

    describe "A Spring web application being staged with 2 Spring DispatcherServlets in its web config with an 'init-param' config in each containing a 'contextConfigLocation' of 'foo' in its web config" do
      before do
        copy_app_resources("spring_multiple_dispatcherservlets_context_config_foo", tmpdir)
      end

      it "should have the 'foo' context precede the auto-reconfiguration context in 2 the DispatcherServlet's 'contextConfigLocation' param-value" do
        spring_pack.compile
        web_config = Nokogiri::XML(open(File.join(spring_pack.webapp_path, "WEB-INF", "web.xml")))
        init_param_name_nodes = web_config.xpath("//init-param[contains(normalize-space(param-name), normalize-space('contextConfigLocation'))]")
        init_param_name_nodes.length.should == 2

        init_param_value_nodes = web_config.xpath("//init-param/param-value")
        init_param_value_nodes.length.should == 2

        init_param_value_nodes.each do |init_param_value_node|
          init_param_value = init_param_value_node.content
          foo_index = init_param_value.index('foo')
          foo_index.should_not == nil

          auto_reconfig_context_index = init_param_value.index('classpath:META-INF/cloud/cloudfoundry-auto-reconfiguration-context.xml')
          auto_reconfig_context_index.should_not == nil

          auto_reconfig_context_index.should > foo_index + "foo".length
        end
      end

      it "should have a 'contextInitializerClasses' context-param with only the CloudApplicationContextInitializer" do
        spring_pack.compile
        assert_context_param tmpdir, 'contextInitializerClasses', CLOUD_APPLICATION_CONTEXT_INITIALIZER
      end

      it "should have the auto reconfiguration jar in the webapp lib path" do
        spring_pack.compile
        File.exist?(File.join(spring_pack.webapp_path,"WEB-INF", "lib", AUTOSTAGING_JAR)).should == true
      end
    end

    describe "A Spring web application using an AnnotationConfigWebApplicationContext in its web config and a contextConfigLocation of 'foo' specified" do
      before do
        copy_app_resources("spring_annotation_context_config_foo", tmpdir)
      end

      it "should have the 'foo' context precede the AnnotationConfigWebApplicationContext in the 'contextConfigLocation' param-value" do
        spring_pack.compile
        web_config = Nokogiri::XML(open(File.join(spring_pack.webapp_path, "WEB-INF", "web.xml")))
        init_param_name_node = web_config.xpath("//context-param[contains(normalize-space(param-name), normalize-space('contextConfigLocation'))]")
        init_param_name_node.length.should_not == 0

        init_param_value_node = init_param_name_node.xpath("param-value")
        init_param_value_node.length.should_not == 0

        init_param_value = init_param_value_node.first.content
        foo_index = init_param_value.index('foo')
        foo_index.should_not == nil

        auto_reconfig_context_index = init_param_value.index(CLOUD_APP_ANNOTATION_CONFIG_CLASS)
        auto_reconfig_context_index.should_not == nil

        auto_reconfig_context_index.should > foo_index + "foo".length
        auto_reconfig_context_index.should < foo_index + 5
      end

      it "should have a 'contextInitializerClasses' context-param with only the CloudApplicationContextInitializer" do
        spring_pack.compile
        assert_context_param tmpdir, 'contextInitializerClasses', CLOUD_APPLICATION_CONTEXT_INITIALIZER
      end

      it "should have the auto reconfiguration jar in the webapp lib path" do
        spring_pack.compile
        File.exist?(File.join(spring_pack.webapp_path,"WEB-INF", "lib", AUTOSTAGING_JAR)).should == true
      end

    end

    describe "A Spring web application using an AnnotationConfigWebApplicationContext in its web config and a contextConfigLocation of 'foo' specified plus has a servlet init-param using an AnnotationConfigWebApplicationContext and a contextConfigLocation of 'bar'" do
      before do
        copy_app_resources("spring_annotation_context_config_and_servletcontext", tmpdir)
      end

      it "should have the 'foo' context precede the AnnotationConfigWebApplicationContext in the 'contextConfigLocation' param-value" do
        spring_pack.compile
        web_config = Nokogiri::XML(open(File.join(spring_pack.webapp_path, "WEB-INF", "web.xml")))
        init_param_name_node = web_config.xpath("//context-param[contains(normalize-space(param-name), normalize-space('contextConfigLocation'))]")
        init_param_name_node.length.should_not == 0

        init_param_value_node = init_param_name_node.xpath("param-value")
        init_param_value_node.length.should_not == 0

        init_param_value = init_param_value_node.first.content
        foo_index = init_param_value.index('foo')
        foo_index.should_not == nil

        auto_reconfig_context_index = init_param_value.index(CLOUD_APP_ANNOTATION_CONFIG_CLASS)
        auto_reconfig_context_index.should_not == nil

        auto_reconfig_context_index.should > foo_index + "foo".length
        auto_reconfig_context_index.should < foo_index + 5
      end

      it "should have the 'bar' context precede the AnnotationConfigWebApplicationContext in the DispatcherServlet's 'contextConfigLocation' param-value" do
        spring_pack.compile

        web_config = Nokogiri::XML(open(File.join(spring_pack.webapp_path, "WEB-INF", "web.xml")))
        init_param_name_node = web_config.xpath("//init-param[contains(normalize-space(param-name), normalize-space('contextConfigLocation'))]")
        init_param_name_node.length.should_not == 0

        init_param_value_node = init_param_name_node.xpath("param-value")
        init_param_value_node.length.should_not == 0

        init_param_value = init_param_value_node.first.content
        bar_index = init_param_value.index('bar')
        bar_index.should_not == nil

        auto_reconfig_context_index = init_param_value.index(CLOUD_APP_ANNOTATION_CONFIG_CLASS)
        auto_reconfig_context_index.should_not == nil

        auto_reconfig_context_index.should > bar_index + "bar".length
        auto_reconfig_context_index.should < bar_index + 5
      end

      it "should have a 'contextInitializerClasses' context-param with only the CloudApplicationContextInitializer" do
        spring_pack.compile
        assert_context_param tmpdir, 'contextInitializerClasses', CLOUD_APPLICATION_CONTEXT_INITIALIZER
      end

      it "should have the auto reconfiguration jar in the webapp lib path" do
        spring_pack.compile
        File.exist?(File.join(spring_pack.webapp_path,"WEB-INF", "lib", AUTOSTAGING_JAR)).should == true
      end
    end

    describe "A Spring web application using a namespace and an AnnotationConfigWebApplicationContext in its web config and a contextConfigLocation of 'foo' specified plus has a servlet init-param using an AnnotationConfigWebApplicationContext and a contextConfigLocation of 'bar'" do
      before do
        copy_app_resources("spring_annotation_context_config_and_servletcontext_ns", tmpdir)
      end

      it "should have the 'foo' context precede the AnnotationConfigWebApplicationContext in the 'contextConfigLocation' param-value" do
        spring_pack.compile
        web_config = Nokogiri::XML(open(File.join(spring_pack.webapp_path, "WEB-INF", "web.xml")))
        init_param_name_node = web_config.xpath("//xmlns:context-param[contains(normalize-space(xmlns:param-name), normalize-space('contextConfigLocation'))]")
        init_param_name_node.length.should_not == 0

        init_param_value_node = init_param_name_node.xpath("xmlns:param-value")
        init_param_value_node.length.should_not == 0

        init_param_value = init_param_value_node.first.content
        foo_index = init_param_value.index('foo')
        foo_index.should_not == nil

        auto_reconfig_context_index = init_param_value.index(CLOUD_APP_ANNOTATION_CONFIG_CLASS)
        auto_reconfig_context_index.should_not == nil

        auto_reconfig_context_index.should > foo_index + "foo".length
        auto_reconfig_context_index.should < foo_index + 5
      end

      it "should have the 'bar' context precede the AnnotationConfigWebApplicationContext in the DispatcherServlet's 'contextConfigLocation' param-value" do
        spring_pack.compile
        web_config = Nokogiri::XML(open(File.join(spring_pack.webapp_path, "WEB-INF", "web.xml")))
        init_param_name_node = web_config.xpath("//xmlns:init-param[contains(normalize-space(xmlns:param-name), normalize-space('contextConfigLocation'))]")
        init_param_name_node.length.should_not == 0

        init_param_value_node = init_param_name_node.xpath("xmlns:param-value")
        init_param_value_node.length.should_not == 0

        init_param_value = init_param_value_node.first.content
        bar_index = init_param_value.index('bar')
        bar_index.should_not == nil

        auto_reconfig_context_index = init_param_value.index(CLOUD_APP_ANNOTATION_CONFIG_CLASS)
        auto_reconfig_context_index.should_not == nil

        auto_reconfig_context_index.should > bar_index + "bar".length
        auto_reconfig_context_index.should < bar_index + 5
      end

      it "should have a 'contextInitializerClasses' context-param with only the CloudApplicationContextInitializer" do
        spring_pack.compile
        assert_context_param tmpdir, 'contextInitializerClasses', CLOUD_APPLICATION_CONTEXT_INITIALIZER, "xmlns:"
      end

      it "should have the auto reconfiguration jar in the webapp lib path" do
        spring_pack.compile
        File.exist?(File.join(spring_pack.webapp_path,"WEB-INF", "lib", AUTOSTAGING_JAR)).should == true
      end
    end

    describe "A Spring web application using an AnnotationConfigWebApplicationContext in its web config and a dispatcher servlet that does not have a default servlet 'init-param' config" do
      before do
        copy_app_resources("spring_annotation_context_config_and_servletcontext_empty", tmpdir)
      end

      it "should have the 'foo' context precede the AnnotationConfigWebApplicationContext in the 'contextConfigLocation' param-value" do
        spring_pack.compile
        web_config = Nokogiri::XML(open(File.join(spring_pack.webapp_path, "WEB-INF", "web.xml")))
        init_param_name_node = web_config.xpath("//context-param[contains(normalize-space(param-name), normalize-space('contextConfigLocation'))]")
        init_param_name_node.length.should_not == 0

        init_param_value_node = init_param_name_node.xpath("param-value")
        init_param_value_node.length.should_not == 0

        init_param_value = init_param_value_node.first.content
        foo_index = init_param_value.index('foo')
        foo_index.should_not == nil

        auto_reconfig_context_index = init_param_value.index(CLOUD_APP_ANNOTATION_CONFIG_CLASS)
        auto_reconfig_context_index.should_not == nil

        auto_reconfig_context_index.should > foo_index + "foo".length
        auto_reconfig_context_index.should < foo_index + 5
      end

      it "should have a init-param in its web config after staging" do
        spring_pack.compile
        web_config_file = File.join(spring_pack.webapp_path, "WEB-INF", "web.xml")
        File.exist?(web_config_file).should == true

        web_config = Nokogiri::XML(open(web_config_file))
        init_param_node =  web_config.xpath("//init-param")
        init_param_node.length.should_not == 0
      end

      it "should have the default servlet context precede the auto-reconfiguration context in the DispatcherServlet's 'contextConfigLocation' param-value" do
        spring_pack.compile
        web_config = Nokogiri::XML(open(File.join(spring_pack.webapp_path, "WEB-INF", "web.xml")))
        init_param_name_node = web_config.xpath("//init-param[contains(normalize-space(param-name), normalize-space('contextConfigLocation'))]")
        init_param_name_node.length.should_not == 0

        init_param_value_node = init_param_name_node.xpath("param-value")
        init_param_value_node.length.should_not == 0

        init_param_value = init_param_value_node.first.content
        dispatcher_servlet_index = init_param_value.index('/WEB-INF/dispatcher-servlet.xml')
        dispatcher_servlet_index.should_not == nil

        auto_reconfig_context_index = init_param_value.index('classpath:META-INF/cloud/cloudfoundry-auto-reconfiguration-context.xml')
        auto_reconfig_context_index.should_not == nil

        auto_reconfig_context_index.should > dispatcher_servlet_index + "/WEB-INF/dispatcher-servlet.xml".length
      end

      it "should have a 'contextInitializerClasses' context-param with only the CloudApplicationContextInitializer" do
        spring_pack.compile
        assert_context_param tmpdir, 'contextInitializerClasses', CLOUD_APPLICATION_CONTEXT_INITIALIZER
      end

      it "should have the auto reconfiguration jar in the webapp lib path" do
        spring_pack.compile
        File.exist?(File.join(spring_pack.webapp_path,"WEB-INF", "lib", AUTOSTAGING_JAR)).should == true
      end

    end

    describe "A Spring web application with a context-param but without a 'contextConfigLocation' param-name in its web config and using a dispatcher servlet that does have an 'init-param' config with an AnnotationConfigWebApplicationContext" do
      before do
        copy_app_resources("spring_annotation_context_config_empty_with_servletcontext", tmpdir)
      end

      it "should have a 'contextConfigLocation' where the default application context precedes the auto-reconfiguration context" do
        spring_pack.compile
        web_config = Nokogiri::XML(open(File.join(spring_pack.webapp_path, "WEB-INF", "web.xml")))
        context_param_name_node = web_config.xpath("//context-param[contains(normalize-space(param-name), normalize-space('contextConfigLocation'))]")
        context_param_name_node.length.should_not == 0

        context_param_value_node = context_param_name_node.first.xpath("param-value")
        context_param_value_node.length.should_not == 0

        context_param_value = context_param_value_node.first.content
        default_context_index = context_param_value.index('/WEB-INF/applicationContext.xml')
        default_context_index.should_not == nil

        auto_reconfig_context_index = context_param_value.index('classpath:META-INF/cloud/cloudfoundry-auto-reconfiguration-context.xml')
        auto_reconfig_context_index.should_not == nil

        auto_reconfig_context_index.should > default_context_index + "/WEB-INF/applicationContext.xml".length
      end

      it "should have the 'bar' context precede the AnnotationConfigWebApplicationContext in the DispatcherServlet's 'contextConfigLocation' param-value" do
        spring_pack.compile
        web_config = Nokogiri::XML(open(File.join(spring_pack.webapp_path, "WEB-INF", "web.xml")))
        init_param_name_node = web_config.xpath("//init-param[contains(normalize-space(param-name), normalize-space('contextConfigLocation'))]")
        init_param_name_node.length.should_not == 0

        init_param_value_node = init_param_name_node.xpath("param-value")
        init_param_value_node.length.should_not == 0

        init_param_value = init_param_value_node.first.content
        bar_index = init_param_value.index('bar')
        bar_index.should_not == nil

        auto_reconfig_context_index = init_param_value.index(CLOUD_APP_ANNOTATION_CONFIG_CLASS)
        auto_reconfig_context_index.should_not == nil

        auto_reconfig_context_index.should > bar_index + "bar".length
        auto_reconfig_context_index.should < bar_index + 5
      end

      it "should have a 'contextInitializerClasses' context-param with only the CloudApplicationContextInitializer" do
        spring_pack.compile
        assert_context_param tmpdir, 'contextInitializerClasses', CLOUD_APPLICATION_CONTEXT_INITIALIZER
      end

      it "should have the auto reconfiguration jar in the webapp lib path" do
        spring_pack.compile
        File.exist?(File.join(spring_pack.webapp_path,"WEB-INF", "lib", AUTOSTAGING_JAR)).should == true
      end
    end

    describe "A Spring web application using an AnnotationConfigWebApplicationContext in its servlet init-param and a contextConfigLocation of 'bar' specified" do
      before do
        copy_app_resources("spring_annotation_servletcontext_no_context_config", tmpdir)
      end

      it "should have the 'bar' context precede the AnnotationConfigWebApplicationContext in the DispatcherServlet's 'contextConfigLocation' param-value" do
        spring_pack.compile
        web_config = Nokogiri::XML(open(File.join(spring_pack.webapp_path, "WEB-INF", "web.xml")))
        init_param_name_node = web_config.xpath("//init-param[contains(normalize-space(param-name), normalize-space('contextConfigLocation'))]")
        init_param_name_node.length.should_not == 0

        init_param_value_node = init_param_name_node.xpath("param-value")
        init_param_value_node.length.should_not == 0

        init_param_value = init_param_value_node.first.content
        bar_index = init_param_value.index('bar')
        bar_index.should_not == nil

        auto_reconfig_context_index = init_param_value.index(CLOUD_APP_ANNOTATION_CONFIG_CLASS)
        auto_reconfig_context_index.should_not == nil

        auto_reconfig_context_index.should > bar_index + "bar".length
        auto_reconfig_context_index.should < bar_index + 5
      end

      it "should have a 'contextInitializerClasses' context-param with only the CloudApplicationContextInitializer" do
        spring_pack.compile
        assert_context_param tmpdir, 'contextInitializerClasses', CLOUD_APPLICATION_CONTEXT_INITIALIZER
      end

      it "should have the auto reconfiguration jar in the webapp lib path" do
        spring_pack.compile
        File.exist?(File.join(spring_pack.webapp_path,"WEB-INF", "lib", AUTOSTAGING_JAR)).should == true
      end
    end
  end

  private
  def copy_app_resources(app_name, dest_dir)
    FileUtils.cp_r(File.join(File.expand_path("../../fixtures/#{app_name}", __FILE__), "."), dest_dir)
  end

  def assert_context_param dest_dir, param_name, param_value, prefix=""
    web_config_file = File.join(dest_dir, 'webapps/ROOT/WEB-INF/web.xml')
    web_config = Nokogiri::XML(open(web_config_file))
    context_param_name_node = web_config.xpath("//#{prefix}context-param[contains(normalize-space(#{prefix}param-name), normalize-space('#{param_name}'))]")
    context_param_name_node.length.should_not == 0

    context_param_value_node = context_param_name_node.first.xpath("#{prefix}param-value")
    context_param_value_node.length.should_not == 0

    context_param_value = context_param_value_node.first.content
    context_param_value.should == param_value
  end
end