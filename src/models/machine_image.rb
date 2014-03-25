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
require 'sinatra/activerecord'
require 'json'
require 'yaml'

class MachineImage < ActiveRecord::Base
  belongs_to :infrastructure
  belongs_to :cloud_entry_point
  belongs_to :common_machine_image
  has_many :machines

  before_create :create_machine_image

  def client
    cloud_entry_point.client
  end

  def create_machine_image
    Log.debug(Log.format_method_start(self.class, __method__))
    # get machine images from the cloud, to check name exists
    case cloud_entry_point.infrastructure.driver
    when 'ec2'
      Log.debug(Log.format_debug_param(to_create_machine_image: 'ec2'))
      begin
        os = common_machine_image.os
        version = common_machine_image.version
        cpu_arch = common_machine_image.cpu_arch || 'x86_64'
        yaml = File.read(File.expand_path('../../config/aws_images.yml', File.dirname(__FILE__)))
        images = YAML.load(yaml)
        if images.key?(os) && images[os].key?(version) && images[os][version].key?(cpu_arch)
          self.ref_id = images[os][version][cpu_arch][cloud_entry_point.entry_point]
        else
          fail "Not fount requested MachineImage on '#{cloud_entry_point.name}'"
        end
      rescue
        Log.error(Log.format_error_params(
          self.class,
          __method__,
          attributes: attributes,
          common_machine_image: common_machine_image,
          images: images
        ))
        raise
      end
    when 'openstack'
      Log.debug(Log.format_debug_param(to_create_machine_image: 'openstack'))
      begin
        response = JSON.parse(client['images'].get)
        images = response['images']
        if !images.is_a?(Array) || images.size == 0
          fail "There is no image in the OpenStack '#{cloud_entry_point.name}'\nPlease register image"
        end
        images.each do |image|
          if image['name'] == common_machine_image.name
            self.ref_id = image['id']
            return true
          end
        end
        fail "Not fount requested MachineImage on '#{cloud_entry_point.name}'"
      rescue
        Log.error(Log.format_error_params(
          self.class,
          __method__,
          attributes: attributes,
          response: response,
          images: images
        ))
        raise
      end
    end
  end
end
