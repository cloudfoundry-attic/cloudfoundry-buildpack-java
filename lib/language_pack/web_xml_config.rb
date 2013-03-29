require 'pry'

module LanguagePack
  class WebXmlConfig
    CONTEXT_CONFIG_LOCATION = "contextConfigLocation".freeze
    CONTEXT_INITIALIZER_CLASSES = "contextInitializerClasses".freeze
    ANNOTATION_CONTEXT_CLASS = "org.springframework.web.context.support.AnnotationConfigWebApplicationContext".freeze

    attr_reader :default_app_context_location, :context_params, :servlet_params, :default_servlet_context_locations, :prefix

    def initialize(web_xml, default_app_context_location, context_params, servlet_params,  default_servlet_context_locations={})
      @parsed_xml = XmlWrapper.new(web_xml)
      @default_app_context_location = default_app_context_location
      @context_params = context_params
      @servlet_params = servlet_params
      @default_servlet_context_locations = default_servlet_context_locations
      @prefix = namespace_prefix
    end

    def xml
      @parsed_xml.to_s
    end

    def configure_autostaging_context_param
      xpath = "//#{prefix}context-param"
      context_config_location_node = @parsed_xml.xpath(xpath).find do |node|
        @parsed_xml.first("#{node.xpath}/#{prefix}param-name").text.strip == CONTEXT_CONFIG_LOCATION
      end

      context_param = autostaging_param_value("//#{prefix}context-param")
      if context_config_location_node
        update_param_value("#{prefix}param-value", context_param, ' ', context_config_location_node)
      elsif default_app_context_location
        add_param_node @parsed_xml.root.xpath, "context-param", CONTEXT_CONFIG_LOCATION, "#{default_app_context_location} #{context_param}"
      end
    end

    def configure_springenv_context_param
      xpath = "//#{prefix}context-param[contains(#{prefix}param-name, '#{CONTEXT_INITIALIZER_CLASSES}')]"
      node = @parsed_xml.first(xpath)

      if node
        update_param_value 'param-value', context_params[:contextInitializerClasses], ", ", node
      else
        add_param_node @parsed_xml.root.xpath, "context-param", CONTEXT_INITIALIZER_CLASSES, context_params[:contextInitializerClasses]
      end
    end

    def configure_autostaging_servlet
      dispatcher_servlet_nodes = @parsed_xml.xpath("//#{prefix}servlet[contains(#{prefix}servlet-class, normalize-space('#{servlet_params[:dispatcherServletClass]}'))]")

      dispatcher_servlet_nodes.each do |node|
        init_param = autostaging_param_value "//#{prefix}servlet/#{prefix}init-param"

        xpath = "#{prefix}init-param[contains(#{prefix}param-name, normalize-space('#{CONTEXT_CONFIG_LOCATION}'))]"
        init_param_nodes = @parsed_xml.xpath("#{xpath}", node)

        if init_param_nodes.size > 0
          init_param_nodes.each_with_index do |node, index|
            update_param_value 'param-value', init_param, " ", node
          end
        else
          dispatcher_servlet_names = @parsed_xml.xpath("#{prefix}servlet-name", node).map(&:text).map(&:strip)
          raise "Should not have matched multiple things" if dispatcher_servlet_names.size > 1
          servlet_name = dispatcher_servlet_names.first
          if has_servlet_context_location?(servlet_name)
            init_param = "#{default_servlet_context_locations[servlet_name]} #{init_param}"
          end
          add_param_node node.xpath, "init-param", CONTEXT_CONFIG_LOCATION, init_param
        end
      end
    end

    private

    def add_param_node(path, node_name, name, value)
      parent = @parsed_xml.add_node(path, node_name)
      @parsed_xml.add_node("", "param-name", name, parent)
      @parsed_xml.add_node("", "param-value", value, parent)
    end

    # TODO: the passed in separator is not used in the split, is that supposed to be that way?
    #       It could end up in a state like "a b c,e;f" if several separators are used
    def update_param_value(path, new_value, separator=" ", node = nil)
      @parsed_xml.update_node_text(path, node) do |text|
        if text.split.include?(new_value) || text == ''
          text
        else
          "#{text}#{separator}#{new_value}"
        end
      end
    end

    def autostaging_param_value(xpath)
      node = @parsed_xml.first("//#{xpath}[contains(#{prefix}param-name, 'contextClass')]/#{prefix}param-value")

      condition = node && node.text.strip == ANNOTATION_CONTEXT_CLASS

      if context_params[:contextConfigLocationAnnotationConfig] && condition
        context_params[:contextConfigLocationAnnotationConfig]
      else
        context_params[:contextConfigLocation]
      end
    end

    def namespace_prefix
      name_space = @parsed_xml.root.namespaces.first
      if name_space
        "#{name_space.first}:"
      else
        ''
      end
    end

    def has_servlet_context_location?(dispatcher_servlet_name)
      !!(default_servlet_context_locations && default_servlet_context_locations[dispatcher_servlet_name])
    end
  end
end
