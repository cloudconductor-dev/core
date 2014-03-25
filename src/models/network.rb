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

class Network < ActiveRecord::Base
  belongs_to :network_group
  belongs_to :gateway
  has_many :network_interfaces

  before_create :create_network
  before_destroy :destroy_network

  private

  def client
    network_group.cloud_entry_point.client
  end

  def create_network
    Log.debug(Log.format_method_start(self.class, __method__))
    payload = {
      name: name,
      network_id: network_group.ref_id,
      address_block: "#{network_address}/#{prefix}",
    }
    response = client['subnets'].post(payload)
    response_hash = JSON.parse(response)
    self.ref_id = response_hash['subnet']['id']
    self.state = response_hash['subnet']['state']
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

  def destroy_network
    Log.debug(Log.format_method_start(self.class, __method__))
    response = client["subnets/#{ref_id}"].delete
  rescue
    Log.error(Log.format_error_params(self.class, __method__, attributes: attributes))
    raise
  end
end
