require "language_pack/java_web"
require "language_pack/autostaging_helpers"

module LanguagePack
  class Spring < JavaWeb
    include LanguagePack::AutostagingHelpers

    DEFAULT_APP_CONTEXT = "/WEB-INF/applicationContext.xml"
    DEFAULT_SERVLET_CONTEXT_SUFFIX = "-servlet.xml"

    CONTEXT_PARAMS = {
        contextConfigLocation: 'classpath:META-INF/cloud/cloudfoundry-auto-reconfiguration-context.xml',
        contextConfigLocationAnnotationConfig: 'org.cloudfoundry.reconfiguration.spring.web.CloudAppAnnotationConfigAutoReconfig',
        contextInitializerClasses: 'org.cloudfoundry.reconfiguration.spring.CloudApplicationContextInitializer'
    }.freeze

    SERVLET_PARAMS = {
        dispatcherServletClass: "org.springframework.web.servlet.DispatcherServlet"
    }.freeze

    def self.use?
      spring_files_found = (Dir.glob("WEB-INF/classes/org/springframework").any? ||
          Dir.glob("WEB-INF/lib/spring-core*.jar").any? || Dir.glob("WEB-INF/lib/org.springframework.core*.jar").any?)
      unless spring_files_found
        spring_files_found = (Dir.glob("webapps/ROOT/WEB-INF/classes/org/springframework").any? ||
            Dir.glob("webapps/ROOT/WEB-INF/lib/spring-core*.jar").any? ||
            Dir.glob("webapps/ROOT/WEB-INF/lib/org.springframework.core*.jar").any?)
      end
      spring_files_found
    end

    def initialize(build_path, cache_path=nil, web_config=nil)
      super(build_path, cache_path)
      @web_config = web_config
    end

    def name
      "Spring"
    end

    def compile
      super
      Dir.chdir(webapp_path) do
        configure_autostaging unless system_properties["spring.autoconfig"] == false
      end
    end

    def default_app_context
      if File.exist? (File.join(webapp_path, 'WEB-INF','applicationContext.xml'))
        DEFAULT_APP_CONTEXT
      end
    end

    def default_servlet_contexts
      servlet_contexts = {}
      Dir.chdir(File.join(webapp_path, "WEB-INF")) do
        Dir.glob("*#{DEFAULT_SERVLET_CONTEXT_SUFFIX}").each do |servlet_context|
          servlet_name = servlet_context.scan(/(.*)#{Regexp.escape(DEFAULT_SERVLET_CONTEXT_SUFFIX)}/).first.first
          servlet_contexts[servlet_name] = "/WEB-INF/#{servlet_context}"
        end
      end
      servlet_contexts
    end

    private
    def configure_autostaging
      web_config.configure_autostaging_context_param
      web_config.configure_springenv_context_param
      web_config.configure_autostaging_servlet
      save_web_config(web_config.xml)
      copy_autostaging_jar File.join(webapp_path, "WEB-INF", "lib")
    end

    def web_config
      @web_config ||= WebXmlConfig.new(open(File.join(webapp_path, "WEB-INF", "web.xml")), default_app_context, CONTEXT_PARAMS,
        SERVLET_PARAMS, default_servlet_contexts)
    end

    def save_web_config(web_config)
      File.open(File.join(webapp_path, "WEB-INF", "web.xml"), 'w') {|f| f.write(web_config) }
    end
  end
end