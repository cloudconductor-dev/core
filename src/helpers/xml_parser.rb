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
require 'nokogiri'

class XmlParser
  attr_reader :xml, :doc

  def initialize(xml)
    Log.debug(Log.format_method_start(self.class, __method__))
    @xml = xml
    @doc = Nokogiri::XML(xml)
    validate
    patch_xml
    replace_import
  end

  def namespace
    Log.debug(Log.format_method_start(self.class, __method__))
    @doc.root.namespace rescue nil
  end

  def validate
    Log.debug(Log.format_method_start(self.class, __method__))
    if @doc && @doc.root && @doc.root.attributes.key?('schemaLocation')
      schema_locations = Hash[@doc.root.attributes['schemaLocation'].value.scan(/(\S+)\s+(\S+)/)]
    else
      # TODO: Fix after schemaLocation added to XML
      schema_locations = { cc: File.expand_path('../../config/system_template.xsd', File.dirname(__FILE__)) }
    end
    errors = []
    schema_locations.each do |namespace, location|
      xsd = Nokogiri::XML::Schema(open(location).read)
      errors += xsd.validate(@doc)
    end
    fail "validation failed. #{errors.map { |e| e.message }.join("\n")}" unless errors.empty?
  end

  def list(element_name, filters = {})
    Log.debug(Log.format_method_start(self.class, __method__))
    node_path = '//' + element_name.split('/').map { |name| "#{namespace.prefix}:#{name}" }.join('/')
    filter_path = '[' + filters.map do |key, value|
      key.start_with?('@') ? "#{key}='#{value}'" : "#{namespace.prefix}:#{key}/text()='#{value}'"
    end.join(' and ') + ']' unless filters.empty?
    xpath = filter_path.nil? ? node_path : node_path + filter_path
    parse(@doc.xpath(xpath))
  end

  def find(element_name, filters = {})
    Log.debug(Log.format_method_start(self.class, __method__))
    list(element_name, filters).first
  end

  def parse(element, reference_level = 5)
    case element
    when Nokogiri::XML::Text
      element.content.strip
    when Nokogiri::XML::NodeSet
      element.map { |e| parse(e, reference_level) }
    when Nokogiri::XML::Element
      # reject blank text
      children = element.children.reject { |e| e.comment? || (e.text? && e.content.strip.empty?) }
      return nil if children.empty? && element.attributes.empty?
      # if element has only text, return content string
      if element.element_children.size == 0 && element.attributes.empty?
        element.content.strip
      # if element is group, return array
      elsif children.map { |e| e.name }.uniq.size == 1 && children.first.name.pluralize == element.name
        children.map { |e| parse(e, reference_level) }
      else
        hash = {}
        element.attributes.each do |key, attr|
          if key == 'ref' && reference_level > 0
            ref_id = element.attributes['ref'].value
            ref_element = element.document.xpath("//*[@id='#{ref_id}']").first
            ref_hash = parse(ref_element, reference_level - 1)
            hash.merge!(ref_hash) { |k, self_val, other_val| self_val }
          else
            hash[key.underscore.to_sym] = attr.value
          end
        end
        children.each do |e|
          hash[e.name.underscore.to_sym] = parse(e, reference_level)
        end
        hash
      end
    else
      Log.error(Log.format_error_params(self.class, __method__, element: element))
      fail ArgumentError, "Unsupported argument #{element.class}"
    end
  end

  private

  # Replace keyname <Import> to preferable name
  def replace_import
    Log.debug(Log.format_method_start(self.class, __method__))
    default_repository = 'https://raw.github.com/cloudconductor-dev/xml-store/master/'
    prefix = namespace.prefix
    @doc.xpath("//#{prefix}:Import").each do |import|
      if import.attributes.key?('type')
        case import.attributes['type'].value
        when 'chef_attribute'
          key_name = 'Parameters'
        when 'chef_runlist'
          key_name = 'RunList'
        end
        if key_name
          import.name = key_name
          import.remove_attribute('type')
        end
      elsif import.attributes.key?('filetype')
        case import.attributes['filetype'].value
        when 'zabbix'
          key_name = 'Template'
        end
        import.name = key_name
        import.remove_attribute('filetype')
      end
    end
  end

  # Add NodeType/Name, MinSize, MaxSize to <MachineGroup>
  def patch_xml
    Log.debug(Log.format_method_start(self.class, __method__))
    prefix = namespace.prefix
    @doc.xpath("//#{prefix}:MachineGroup").each do |machine_group|
      node_type = machine_group.xpath("#{prefix}:NodeType").first
      # Add NodeType name to xml
      node = Nokogiri::XML::Node.new('Name', @doc)
      node.content = node_type.first_element_child.name
      node_type.add_child(node)
      # Add min/max machine size
      case node.content
      when 'Single'
        max_size = min_size = 1
      when 'HA'
        max_size = min_size = 2
      when 'Cluster'
        max_size = node_type.xpath("#{prefix}:Cluster/MaxSize").content.to_i
        min_size = node_type.xpath("#{prefix}:Cluster/MinSize").content.to_i
      else
        fail "Unknown node_type #{node_type}"
      end
      max_size_node = Nokogiri::XML::Node.new('MaxSize', @doc)
      max_size_node.content = max_size
      min_size_node = Nokogiri::XML::Node.new('MinSize', @doc)
      min_size_node.content = min_size
      machine_group.add_child(max_size_node)
      machine_group.add_child(min_size_node)
    end
  end
end
