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

class Gateway < ActiveRecord::Base
  belongs_to :cloud_entry_point
  belongs_to :system
  has_many :networks

  before_create :create_gateway
  before_destroy :destroy_gateway

  def attach(network_group_id)
    Log.debug(Log.format_method_start(self.class, __method__))
    payload = {
      network_id: NetworkGroup.find_by(id: network_group_id).ref_id
    }
    client["gateways/#{ref_id}/attach"].put(payload)
  rescue
    Log.error(Log.format_error_params(
      self.class,
      __method__,
      attributes: attributes,
      payload: payload
    ))
    raise
  end

  def detach
    Log.debug(Log.format_method_start(self.class, __method__))
    client["gateways/#{ref_id}/detach"].put({})
  rescue
    Log.error(Log.format_error_params(self.class, __method__, attributes: attributes))
    raise
  end

  def add_interface(network_id)
    Log.debug(Log.format_method_start(self.class, __method__))
    payload = {
      subnet_id: Network.find_by(id: network_id).ref_id,
    }
    response = client["gateways/#{ref_id}/add_interface"].put(payload)
  rescue
    Log.error(Log.format_error_params(
      self.class,
      __method__,
      attributes: attributes,
      payload: payload
    ))
    raise
  end

  def remove_interface(network_id = nil)
    Log.debug(Log.format_method_start(self.class, __method__))
    payload = {}
    payload[:subnet_id] = Network.find_by(id: network_id).ref_id unless network_id.nil?
    response = client["gateways/#{ref_id}/remove_interface"].put(payload)
  rescue
    Log.error(Log.format_error_params(
      self.class,
      __method__,
      attributes: attributes,
      payload: payload
    ))
    raise
  end

  def self.external_network_ref_ids(cloud_entry_point)
    Log.debug(Log.format_method_start(self.class, __method__))
    client = cloud_entry_point.client
    response = client['gateways'].get
    gateways = JSON.parse(response)['gateways']
    external_network_ref_ids = []
    gateways.each do |gateway|
      external_network = gateway['network']
      external_network_ref_ids << external_network['id'] if external_network
    end
    external_network_ref_ids.compact.uniq
  rescue
    Log.error(Log.format_error_params(
      self.class,
      __method__,
      attributes: attributes,
      payload: payload,
      response: response,
      gateways: gateways,
      external_network_ref_ids: external_network_ref_ids
    ))
    raise
  end

  private

  def client
    cloud_entry_point.client
  end

  def create_gateway
    Log.debug(Log.format_method_start(self.class, __method__))
    payload = { name: name }
    response = client['gateways'].post(payload)
    response_hash = JSON.parse(response)
    self.ref_id = response_hash['gateway']['id']
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

  def destroy_gateway
    Log.debug(Log.format_method_start(self.class, __method__))
    remove_interface
    detach
    client["gateways/#{ref_id}"].delete
  rescue
    Log.error(Log.format_error_params(self.class, __method__, attributes: attributes))
    raise
  end
end
