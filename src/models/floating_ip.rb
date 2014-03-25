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

class FloatingIp < ActiveRecord::Base
  belongs_to :system
  belongs_to :cloud_entry_point
  belongs_to :machine

  before_create :create_floating_ip
  before_destroy :destroy_floating_ip

  def associate(machine_id)
    Log.debug(Log.format_method_start(self.class, __method__))
    payload = { instance_id: Machine.find_by(id: machine_id).ref_id }
    response = client["addresses/#{ref_id}/associate"].post(payload)
    update_attributes(machine_id: machine_id)
  rescue
    Log.error(Log.format_error_params(
      self.class,
      __method__,
      attributes: attributes,
      payload: payload,
      machine_id: machine_id
    ))
    raise
  end

  def disassociate
    Log.debug(Log.format_method_start(self.class, __method__))
    client["addresses/#{ref_id}"].post({})
  rescue
    Log.error(Log.format_error_params(self.class, __method__, attributes: attributes))
    raise
  end

  private

  def client
    cloud_entry_point.client
  end

  def create_floating_ip
    Log.debug(Log.format_method_start(self.class, __method__))
    response = client['addresses'].post({})
    response_hash = JSON.parse(response)
    self.ref_id = response_hash['address']['id']
    self.ip_address = response_hash['address']['ip_address']
  rescue
    Log.error(Log.format_error_params(
      self.class,
      __method__,
      attributes: attributes,
      response: response,
      response_hash: response_hash
    ))
    raise
  end

  def destroy_floating_ip
    Log.debug(Log.format_method_start(self.class, __method__))
    client["addresses/#{ref_id}"].delete
  rescue
    Log.error(Log.format_error_params(self.class, __method__, attributes: attributes))
    raise
  end
end
