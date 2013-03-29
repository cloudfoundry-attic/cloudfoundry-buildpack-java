require "rexml/document"

class XmlWrapper
  def initialize(xml_string)
    @document = REXML::Document.new xml_string
  end

  def xpath(path, relative_node = @document)
    REXML::XPath.match(relative_node, path)
  end

  def first(path)
    result = xpath(path)
    result && result.first
  end

  def root
    @document.root
  end

  def to_s
    @document.to_s
  end

  def add_node(path, name, value = nil, relative_node = @document)
    child = REXML::Element.new(name)
    child.text = value

    xpath(path, relative_node).first << child
    child
  end

  def update_node_text(path, relative_node = @document)
    xpath(path, relative_node).each do |node|
      node.text = yield node.text
    end
  end
end
