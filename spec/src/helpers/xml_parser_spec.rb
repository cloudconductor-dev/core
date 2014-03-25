# -*- coding: utf-8 -*-
# Copyright 2014 TIS Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
describe 'XmlParser' do
  let(:template_xml) do
    xml_path = File.expand_path('../../fixtures/system_template.xml', File.dirname(__FILE__))
    File.read(xml_path)
  end

  let(:template) do
    XmlParser.new(template_xml)
  end

  describe '.initialize' do
    describe 'When called with unparsable document' do
      it 'should raise RuntimeError' do
        text = 'unparsable document'
        expect { XmlParser.new(text) }.to raise_error(RuntimeError)
      end
    end
    describe 'When called with undesirable xml' do
      it 'should raise RuntimeError' do
        text = '<XML></XML>'
        expect { XmlParser.new(text) }.to raise_error(RuntimeError)
      end
    end
    describe 'When called with valid system template xml' do
      it 'should return XmlParser object' do
        result = XmlParser.new(template_xml)
        expect(result).to be_instance_of(XmlParser)
      end
    end
  end

  describe '#list' do
    describe 'When called with valid element_name' do
      it 'should return ' do
        result = template.list('MachineGroup')
        expect(result).to be_instance_of(Array)
        expect(result.size).to eq(4)
      end
    end
  end

  describe '#find' do
    describe 'When called with valid element_name' do
      it "should return first element's hash" do
        result = template.find('MachineGroup')
        expect(result).to be_instance_of(Hash)
        expect(result[:id]).to eq('web-server-g')
      end
    end
  end

  describe '#parse' do
    it 'should raise ArgumentError when called with non element' do
      expect { template.parse('string') }.to raise_error(ArgumentError)
    end
    it 'should return String when called with Nokogiri::XML::Text' do
      text = template.doc.xpath('//cc:MachineGroup/cc:Name/text()').first
      result = template.parse(text)
      expect(result).to be_instance_of(String)
      expect(result.empty?).to be_false
    end
    it 'should return Array when called with Nokogiri::XML::NodeSet' do
      node_set = template.doc.xpath('//cc:MachineGroup')
      result = template.parse(node_set)
      expect(result).to be_instance_of(Array)
      expect(result.empty?).to be_false
      expect(result.first).to eq(template.parse(node_set.first))
    end
    it 'should return Hash when called with Nokogiri::XML::Element' do
      element = template.doc.xpath('//cc:MachineGroup').first
      result = template.parse(element)
      expect(result).to be_instance_of(Hash)
      expect(result).to be_key(:network_interfaces)
      expect(result[:network_interfaces].first).to be_key(:networks)
    end
  end

  describe '#replace_import' do
    it 'should exist Role/Parameters' do
      expect(template.doc.xpath('//cc:Role/cc:Parameters').empty?).to be_false
    end
    it 'should exist Role/RunList' do
      expect(template.doc.xpath('//cc:Role/cc:RunList').empty?).to be_false
    end
    it 'should exist Monitoring/Template' do
      expect(template.doc.xpath('//cc:Monitoring/cc:Template').empty?).to be_false
    end
  end

  describe '#patch_xml' do
    it 'should insert MachineGroup/NodeType/Name' do
      nodes = template.doc.xpath('//cc:MachineGroup/cc:NodeType/cc:Name')
      expect(nodes.empty?).to be_false
      nodes.each do |node|
        expect(%w(Single HA Cluster).include?(node.content)).to be_true
      end
    end
    it 'should insert MachineGroup/MaxSize' do
      nodes = template.doc.xpath('//cc:MachineGroup/cc:MaxSize')
      expect(nodes.empty?).to be_false
      nodes.each do |node|
        expect(node.content.to_i > 0).to be_true
      end
    end
    it 'should insert MachineGroup/MinSize' do
      nodes = template.doc.xpath('//cc:MachineGroup/cc:MinSize')
      expect(nodes.empty?).to be_false
      nodes.each do |node|
        expect(node.content.to_i > 0).to be_true
      end
    end
  end
end
