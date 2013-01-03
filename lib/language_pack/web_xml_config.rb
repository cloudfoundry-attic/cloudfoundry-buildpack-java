require "nokogiri"

module LanguagePack
  class WebXmlConfig
    CONTEXT_CONFIG_LOCATION = "contextConfigLocation".freeze

    attr_reader :default_app_context_location, :context_params, :servlet_params, :prefix

    def initialize(web_xml, default_app_context_location, context_params, servlet_params)
      @parsed_xml = Nokogiri::XML(web_xml)
      @default_app_context_location = default_app_context_location
      @context_params = context_params
      @servlet_params = servlet_params
    end

    def xml
      @parsed_xml.to_s
    end

    def configure_autostaging_context_param
      context_config_location_node = @parsed_xml.xpath("//context-param[contains(normalize-space(param-name), normalize-space('#{CONTEXT_CONFIG_LOCATION}'))]").first
      if context_config_location_node
        update_context_value context_config_location_node
      elsif default_app_context_location
        context_param_node = Nokogiri::XML::Node.new 'context-param', @parsed_xml
        add_name_value_pair(context_param_node, CONTEXT_CONFIG_LOCATION, "#{default_app_context_location} #{context_params[:contextConfigLocation]}")
        @parsed_xml.root.add_child context_param_node
      end
    end

    private
    def add_name_value_pair(parent, name, value)
      context_param_name_node = Nokogiri::XML::Node.new 'param-name', @parsed_xml
      context_param_name_node.content = name
      parent.add_child context_param_name_node

      context_param_value_node = Nokogiri::XML::Node.new 'param-value', @parsed_xml
      context_param_value_node.content = value
      parent.add_child context_param_value_node
    end

    def update_context_value(node)
      context_param_value = node.xpath("param-value").first.content
      return if context_param_value.split.include?(context_params[:contextConfigLocation]) || context_param_value == ''

      node.xpath("param-value").first.unlink
      context_param_value << " #{context_params[:contextConfigLocation]}"

      context_param_value_node = Nokogiri::XML::Node.new 'param-value', @parsed_xml
      context_param_value_node.content = context_param_value
      node.add_child context_param_value_node
    end
  end
end