require 'spec_helper'

describe XmlWrapper do
  let(:xml) { xml = XmlWrapper.new("<doc><name>Tom</name><job>Programmer</job><name>Agnes</name></doc>") }

  it "finds a node" do
    expect(xml.first("/doc/name").text).to eq "Tom"
    expect(xml.first("/doc/job").text).to eq "Programmer"
  end

  it "returns empty arrays when it doesn't find anything" do
    expect(xml.xpath("/not_here")).to eq([])
  end

  it "returns the root node" do
    expect(xml.root.name).to eq "doc"
  end

  it "returns its string representation" do
    expect(xml.to_s).to eq "<doc><name>Tom</name><job>Programmer</job><name>Agnes</name></doc>"
  end

  it "adds a node" do
    xml.add_node(path: "/doc", name: "age", value: "15")
    expect(xml.first("/doc/age").text).to eq "15"
  end

  it "adds an empty node" do
    xml.add_node(path: "/doc", name: "nothing")
    expect(xml.first("/doc/nothing")).to_not be_nil
  end

  it "updates a node's content" do
    xml.update_node_text("/doc/name") { |text| "#{text}_1" }
    expect(xml.xpath("/doc/name").first.text).to eq("Tom_1")
    expect(xml.xpath("/doc/name")[1].text).to eq("Agnes_1")
  end

  describe "complicated tree" do
    let(:xml) { xml = XmlWrapper.new("<doc><name><first>Tom</first><last>Mayer</last></name><job>Programmer</job><name><first>Agnes</first><last>Deliboard</last></name></doc>") }
    let(:tom) { tom = xml.first("//doc/name") }

    it "finds a node relative to another node" do
      toms_name = xml.xpath("first", tom)
      expect(toms_name.size).to eq(1)
      expect(toms_name[0].text).to eq("Tom")
    end

    it "updates the right node" do
      xml.update_node_text("first", tom) { |name| "Barry" }
      expect(xml.xpath("/doc/name/first")[0].text).to eq "Barry"
      expect(xml.xpath("/doc/name/first")[1].text).to eq "Agnes"
    end

    it "adds a node" do
      xml.add_node(name: "middle", value: "Jesus", relative_node: tom)
      expect(xml.xpath("/doc/name/middle")[0].text).to eq "Jesus"
    end
  end
end
