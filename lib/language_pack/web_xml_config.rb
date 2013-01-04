require "nokogiri"

module LanguagePack
  class WebXmlConfig
    CONTEXT_CONFIG_LOCATION = "contextConfigLocation".freeze
    CONTEXT_INITIALIZER_CLASSES = "contextInitializerClasses".freeze
    ANNOTATION_CONTEXT_CLASS = "org.springframework.web.context.support.AnnotationConfigWebApplicationContext".freeze

    attr_reader :default_app_context_location, :context_params, :servlet_params, :default_servlet_context_locations, :prefix

    def initialize(web_xml, default_app_context_location, context_params, servlet_params,  default_servlet_context_locations={})
      @parsed_xml = Nokogiri::XML(web_xml)
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
      context_config_location_node = @parsed_xml.xpath("//#{prefix}context-param[contains(normalize-space(#{prefix}param-name), normalize-space('#{CONTEXT_CONFIG_LOCATION}'))]").first
      context_param = autostaging_param_value "#{prefix}context-param"
      if context_config_location_node
        update_param_value context_config_location_node, context_param
      elsif default_app_context_location
        add_param_node @parsed_xml.root, "context-param", CONTEXT_CONFIG_LOCATION, "#{default_app_context_location} #{context_param}"
      end
    end

    def configure_springenv_context_param
      context_param_node =  @parsed_xml.xpath("//#{prefix}context-param[contains(normalize-space(#{prefix}param-name), normalize-space('#{CONTEXT_INITIALIZER_CLASSES}'))]").first
      if context_param_node
        update_param_value context_param_node, context_params[:contextInitializerClasses], ", "
      else
        add_param_node @parsed_xml.root, "context-param", CONTEXT_INITIALIZER_CLASSES, context_params[:contextInitializerClasses]
      end
    end

    def configure_autostaging_servlet
      dispatcher_servlet_nodes = @parsed_xml.xpath("//#{prefix}servlet[contains(normalize-space(#{prefix}servlet-class), normalize-space('#{servlet_params[:dispatcherServletClass]}'))]")
      return unless dispatcher_servlet_nodes

      dispatcher_servlet_nodes.each do |dispatcher_servlet_node|
        dispatcher_servlet_name = dispatcher_servlet_node.xpath("#{prefix}servlet-name").first.content.strip
        init_param_node = dispatcher_servlet_node.xpath("#{prefix}init-param[contains(normalize-space(#{prefix}param-name), normalize-space('#{CONTEXT_CONFIG_LOCATION}'))]").first
        init_param = autostaging_param_value "#{prefix}servlet/#{prefix}init-param"
        if init_param_node
          update_param_value init_param_node, init_param
        else
          init_param = "#{default_servlet_context_locations[dispatcher_servlet_name]} #{init_param}" if has_servlet_context_location?(dispatcher_servlet_name)
          add_param_node dispatcher_servlet_node, "init-param", CONTEXT_CONFIG_LOCATION, init_param
        end
      end
    end

    private
    def add_param_node(parent, node_name, name, value)
      param_node = Nokogiri::XML::Node.new node_name, @parsed_xml

      param_name_node = Nokogiri::XML::Node.new 'param-name', @parsed_xml
      param_name_node.content = name
      param_node.add_child param_name_node

      param_value_node = Nokogiri::XML::Node.new 'param-value', @parsed_xml
      param_value_node.content = value
      param_node.add_child param_value_node

      parent.add_child param_node
    end

    def update_param_value(node, new_value, separator=" ")
      value_node = node.xpath("#{prefix}param-value").first
      old_value = value_node.content
      return if old_value.split.include?(new_value) || old_value == ''

      value_node.content += "#{separator}#{new_value}"
    end

    def autostaging_param_value(xpath)
      contextClass = @parsed_xml.xpath("//#{xpath}[contains(normalize-space(#{prefix}param-name), normalize-space('contextClass'))]")
      if context_params[:contextConfigLocationAnnotationConfig] && contextClass.xpath("#{prefix}param-value").text.strip == ANNOTATION_CONTEXT_CLASS
        context_params[:contextConfigLocationAnnotationConfig]
      else
        context_params[:contextConfigLocation]
      end
    end

    def namespace_prefix
      name_space = @parsed_xml.root.namespace
      if name_space
        name_space.prefix ? name_space.prefix : "xmlns:"
      else
        ''
      end
    end

    def has_servlet_context_location?(dispatcher_servlet_name)
      default_servlet_context_locations && default_servlet_context_locations[dispatcher_servlet_name]
    end
  end
end