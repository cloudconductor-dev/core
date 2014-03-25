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

class NetworkInterface < ActiveRecord::Base
  belongs_to :machine
  belongs_to :network

  before_create :create_network_interface
  before_destroy :destroy_network_interface

  private

  def client
    machine.cloud_entry_point.client
  end

  def create_network_interface
    Log.debug(Log.format_method_start(self.class, __method__))
    return true if ref_id
    payload = {
      instance: machine.ref_id,
      network: network.ref_id,
    }
    response = client['network_interfaces'].post(payload)
    response_hash = JSON.parse(response)['network_interface']
    self.ref_id = response_hash['id']
    self.ip_address = response_hash['ip_address']
  rescue
    Log.error(Log.format_error_params(
      self.class,
      __method__,
      attributes: attributes,
      payload: payload,
      response: response,
      response_hash: response_hash
    ))
    raise
  end

  def destroy_network_interface
    Log.debug(Log.format_method_start(self.class, __method__))
    client["network_interfaces/#{ref_id}"].delete
  rescue
    Log.error(Log.format_error_params(self.class, __method__, attributes: attributes))
    raise
  end
end
