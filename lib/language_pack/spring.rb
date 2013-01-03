require "language_pack/java_web"
# TODO how do we ensure this gem is available?
require "nokogiri"

module LanguagePack
  class Spring < JavaWeb

    AUTOSTAGING_JAR = "auto-reconfiguration-0.6.5.jar"
    DEFAULT_APP_CONTEXT = "/WEB-INF/applicationContext.xml"
    DEFAULT_SERVLET_CONTEXT_SUFFIX = "-servlet.xml"
    ANNOTATION_CONTEXT_CLASS = "org.springframework.web.context.support.AnnotationConfigWebApplicationContext"

    CONTEXT_PARAMS = {
        contextConfigLocation: 'classpath:META-INF/cloud/cloudfoundry-auto-reconfiguration-context.xml',
        contextConfigLocationAnnotationConfig: 'org.cloudfoundry.reconfiguration.spring.web.CloudAppAnnotationConfigAutoReconfig',
        contextInitializerClasses: 'org.cloudfoundry.reconfiguration.spring.CloudApplicationContextInitializer'
    }.freeze

    SERVLET = {
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

    def name
      "Spring"
    end

    def compile
      super
      configure_autostaging
    end

    def configure_autostaging
      autostaging_context = Nokogiri::XML(open(File.join(File.expand_path("../../../resources", __FILE__),
                                                         "autostaging_template_spring.xml")))
      web_config = Nokogiri::XML(open(File.join(webapp_path, "WEB-INF","web.xml")))
      web_config = configure_autostaging_context_param(autostaging_context, web_config)
      web_config = configure_springenv_context_param(autostaging_context, web_config)
      web_config = configure_autostaging_servlet(autostaging_context, web_config)
      save_web_config(web_config)
      copy_autostaging_jar
    end

    private
    # Look for the presence of the "context-param" element in the top level (global context) of WEB-INF/web.xml
    # and for a "contextConfigLocation" node within that.
    # If present, update it if necessary (i.e. it does have a valid location) to include the context reference
    # (provided by autostaging_context) that will handle autostaging.
    # If not present, check for the presence of a default app context at WEB-INF/applicationContext.xml. If a
    # default app context is present, introduce a "contextConfigLocation" element and set its value to include
    # both the default app context as well as the context reference for autostaging.
    def configure_autostaging_context_param(autostaging_context, webapp_config)
      autostaging_context_param_name_node = autostaging_context.xpath("//context-param[param-name='contextConfigLocation']").
          first.xpath("param-name").first
      autostaging_context_param_name = autostaging_context_param_name_node.content.strip
      prefix = get_namespace_prefix(webapp_config)
      autostaging_context_param_anno_node = autostaging_context.xpath("//context-param[param-name='contextConfigLocationAnnotationConfig']").first
      if autostaging_context_param_anno_node
        autostaging_context_param_value_anno_node = autostaging_context_param_anno_node.xpath("param-value").first
      else
        autostaging_context_param_value_anno_node = nil
      end
      cc = webapp_config.xpath("//#{prefix}context-param[contains(normalize-space(#{prefix}param-name), normalize-space('contextClass'))]")
      if autostaging_context_param_value_anno_node && cc.xpath("#{prefix}param-value").text == ANNOTATION_CONTEXT_CLASS
        autostaging_context_param_value_node = autostaging_context_param_value_anno_node
      else
        autostaging_context_param_value_node = autostaging_context.xpath("//context-param/param-value").first
      end
      autostaging_context_param_value = autostaging_context_param_value_node.content

      context_param_nodes =  webapp_config.xpath("//#{prefix}context-param")
      if (context_param_nodes && context_param_nodes.length > 0)
        context_param_node = webapp_config.xpath("//#{prefix}context-param[contains(normalize-space(#{prefix}param-name), normalize-space('#{autostaging_context_param_name}'))]").first
        if (context_param_node)
          webapp_config = update_context_value context_param_node.parent, prefix, "context-param", webapp_config,
                                               autostaging_context_param_name, autostaging_context_param_value
        else
          default_application_context_file = get_default_application_context_file
          if default_application_context_file
            context_param_node = context_param_nodes.first
            webapp_config = configure_default_context(webapp_config, autostaging_context_param_name_node,
                                                      autostaging_context_param_value, context_param_node, DEFAULT_APP_CONTEXT)
          end
        end
      else
        default_application_context_file = get_default_application_context_file
        if default_application_context_file
          context_param_node = Nokogiri::XML::Node.new 'context-param', webapp_config
          webapp_config.root.add_child context_param_node
          webapp_config = configure_default_context(webapp_config, autostaging_context_param_name_node,
                                                    autostaging_context_param_value, context_param_node, DEFAULT_APP_CONTEXT)
        end
      end
      webapp_config
    end

    def configure_springenv_context_param(autostaging_context, webapp_config)
      autostaging_context_param_node = autostaging_context.xpath("//context-param[param-name='contextInitializerClasses']").first
      autostaging_context_param_value_node = autostaging_context_param_node.xpath("param-value").first

      prefix = get_namespace_prefix(webapp_config)
      context_param_node =  webapp_config.xpath("//#{prefix}context-param[#{prefix}param-name='contextInitializerClasses']").first
      if (context_param_node)
        context_param_value_node = context_param_node.xpath("#{prefix}param-value").first
        context_param_value = "#{context_param_value_node.content.strip}, #{autostaging_context_param_value_node.content}"
        context_param_value_node.content = context_param_value
      else
        context_param_node = Nokogiri::XML::Node.new 'context-param', webapp_config
        context_param_node.add_child autostaging_context_param_node.xpath("param-name").first.dup
        context_param_node.add_child autostaging_context_param_value_node.dup
        webapp_config.root.add_child context_param_node
      end
      webapp_config
    end

    # Look for the presence of the "init-param" element in the DispatcherServlet element of WEB-INF/web.xml
    # and for a "contextConfigLocation" node within that.
    # If present, update it to include the context reference (provided by the autostaging_context) that
    # will handle autostaging.
    # If not present, check for the presence of a default servlet context at
    # WEB-INF/<servlet-name>-applicationContext.xml. If a default app context is present,
    # introduce a "contextConfigLocation" element and set its value to include
    # both the default servlet context as well as the context reference for autostaging.
    def configure_autostaging_servlet (autostaging_context, webapp_config)
      autostaging_servlet_class = autostaging_context.xpath("//servlet-class").first.content.strip
      autostaging_init_param_name_node = autostaging_context.xpath("//servlet/init-param/param-name").first
      autostaging_init_param_name = autostaging_init_param_name_node.content.strip
      autostaging_init_param_anno_node = autostaging_context.xpath("//servlet/init-param[param-name='contextConfigLocationAnnotationConfig']").first
      if autostaging_init_param_anno_node
        autostaging_init_param_value_anno_node = autostaging_init_param_anno_node.xpath("param-value").first
      end

      prefix = get_namespace_prefix(webapp_config)
      if autostaging_init_param_value_anno_node &&
          webapp_config.xpath("//#{prefix}servlet/#{prefix}init-param[contains(normalize-space(#{prefix}param-name), normalize-space('contextClass'))]").xpath("#{prefix}param-value").text == ANNOTATION_CONTEXT_CLASS
        autostaging_init_param_value_node = autostaging_init_param_value_anno_node
      else
        autostaging_init_param_value_node = autostaging_context.xpath("//servlet/init-param/param-value").first
      end
      autostaging_init_param_value = autostaging_init_param_value_node.content

      dispatcher_servlet_nodes = webapp_config.xpath("//#{prefix}servlet[contains(normalize-space(#{prefix}servlet-class), normalize-space('#{autostaging_servlet_class}'))]")
      if (dispatcher_servlet_nodes && !dispatcher_servlet_nodes.empty?)
        dispatcher_servlet_nodes.each do |dispatcher_servlet_node|
          dispatcher_servlet_name = dispatcher_servlet_node.xpath("#{prefix}servlet-name").first.content.strip
          default_servlet_context = "/WEB-INF/#{dispatcher_servlet_name}#{DEFAULT_SERVLET_CONTEXT_SUFFIX}"
          init_param_node = dispatcher_servlet_node.xpath("#{prefix}init-param").first
          if init_param_node
            init_param_name_node = dispatcher_servlet_node.xpath("#{prefix}init-param[contains(normalize-space(#{prefix}param-name), normalize-space('#{autostaging_init_param_name}'))]").first
            if init_param_name_node
              webapp_config = update_context_value dispatcher_servlet_node, prefix, "init-param", webapp_config,
                                                   autostaging_init_param_name, autostaging_init_param_value
            else
              webapp_config = configure_init_param_node(autostaging_init_param_name_node, autostaging_init_param_value,
                                                        autostaging_init_param_value_node, default_servlet_context,
                                                        dispatcher_servlet_name, dispatcher_servlet_node, init_param_node,
                                                        webapp_config)
            end
          else
            init_param_node = Nokogiri::XML::Node.new 'init-param', webapp_config
            webapp_config = configure_init_param_node(autostaging_init_param_name_node, autostaging_init_param_value,
                                                      autostaging_init_param_value_node, default_servlet_context,
                                                      dispatcher_servlet_name, dispatcher_servlet_node, init_param_node,
                                                      webapp_config)
          end
        end
      end
      webapp_config
    end

    def get_namespace_prefix(webapp_config)
      name_space = webapp_config.root.namespace
      if name_space
        if name_space.prefix
          prefix = name_space.prefix
        else
          prefix = "xmlns:"
        end
      else
        prefix = ''
      end
    end

    def update_context_value(parent, prefix, selector, webapp_config, autostaging_context_param_name,
        autostaging_context_param_value)
      node = parent.xpath("#{prefix}#{selector}[contains(normalize-space(#{prefix}param-name), normalize-space('#{autostaging_context_param_name}'))]").first
      context_param_value_node = node.xpath("#{prefix}param-value")
      context_param_value = context_param_value_node.first.content

      unless context_param_value.split.include?(autostaging_context_param_value) || context_param_value == ''
        node.xpath("#{prefix}param-value").first.unlink
        context_param_value << " #{autostaging_context_param_value}"

        context_param_value_node = Nokogiri::XML::Node.new 'param-value', webapp_config
        context_param_value_node.content = context_param_value
        node.add_child context_param_value_node
      end
      webapp_config
    end

    def configure_default_context(webapp_config, autostaging_context_param_name_node, autostaging_context_param_value,
        parent, default_context)
      context_param_value = "#{default_context} #{autostaging_context_param_value}"
      context_param_value_node = Nokogiri::XML::Node.new 'param-value', webapp_config
      context_param_value_node.content = context_param_value

      parent.add_child autostaging_context_param_name_node.dup
      parent.add_child context_param_value_node

      webapp_config
    end

    def configure_init_param_node(autostaging_init_param_name_node, autostaging_init_param_value,
        autostaging_init_param_value_node, default_servlet_context, dispatcher_servlet_name, dispatcher_servlet_node,
        init_param_node, webapp_config)
      default_servlet_context_file = get_default_servlet_context_file(dispatcher_servlet_name)
      dispatcher_servlet_node.add_child init_param_node
      if default_servlet_context_file
        webapp_config = configure_default_context webapp_config, autostaging_init_param_name_node,
                                                  autostaging_init_param_value, init_param_node, default_servlet_context
      else
        init_param_node.add_child autostaging_init_param_name_node.dup
        init_param_node.add_child autostaging_init_param_value_node.dup
      end
      webapp_config
    end

    def get_default_application_context_file
      default_application_context = File.join(webapp_path, "WEB-INF", "applicationContext.xml")
      if File.exist? default_application_context
        return default_application_context
      end
      nil
    end

    def get_default_servlet_context_file(servlet_name)
      default_servlet_context = File.join(webapp_path, "WEB-INF", "#{servlet_name}#{DEFAULT_SERVLET_CONTEXT_SUFFIX}")
      if File.exist? default_servlet_context
        return default_servlet_context
      end
      nil
    end

    def save_web_config(web_config)
      File.open(File.join(webapp_path, "WEB-INF", "web.xml"), 'w') {|f| f.write(web_config.to_xml) }
    end

    # TODO get this from a URL
    def copy_autostaging_jar
      FileUtils.cp(File.join(File.expand_path('../../../resources', __FILE__), AUTOSTAGING_JAR),
                   File.join(webapp_path, "WEB-INF", "lib"))
    end
  end
end