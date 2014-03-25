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

class MachineConfig < ActiveRecord::Base
  belongs_to :infrastructure
  belongs_to :common_machine_config
  belongs_to :cloud_entry_point
  has_many :machines

  before_create :find_machine_config

  def client
    cloud_entry_point.client
  end

  def find_machine_config
    Log.debug(Log.format_method_start(self.class, __method__))
    response = client['hardware_profiles'].get
    configs = JSON.parse(response)['hardware_profiles']
    configs.select! do |config|
      config['properties']['cpu'].to_i >= common_machine_config.min_cpu &&
      config['properties']['memory'].to_f >= common_machine_config.min_memory
    end
    if configs.size == 0
      Log.error(Log.format_error_params(
        self.class,
        __method__,
        attributes: attributes,
        response: response,
        configs: configs
      ))
      fail 'Not found machine config to satisfy requirements.'
    end
    configs.sort! do |a, b|
      if a['properties']['cpu'] != b['properties']['cpu']
        a['properties']['cpu'].to_i <=> b['properties']['cpu'].to_i
      else
        a['properties']['memory'].to_f <=> b['properties']['memory'].to_f
      end
    end
    config = configs.first
    self.ref_id = config['id']
    self.name = config['name']
    self.cpu = config['properties']['cpu'].to_i
    self.memory = config['properties']['memory'].to_i
  rescue
    Log.error(Log.format_error_params(
      self.class,
      __method__,
      attributes: attributes,
      response: response,
      configs: configs
    ))
    raise
  end
end
