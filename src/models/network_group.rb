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

class NetworkGroup < ActiveRecord::Base
  belongs_to :system
  belongs_to :cloud_entry_point
  has_many :networks, dependent: :destroy

  before_create :create_network_group
  before_destroy :destroy_network_group

  def to_h
    {
      id: id,
      name: name,
      networks: networks.map do |net|
        {
          id: net.id,
          name: net.name,
          network_address: net.network_address,
          prefix: net.prefix,
          createDate: net.created_at,
          updateDate: net.updated_at,
        }
      end,
      createDate: created_at,
      updateDate: updated_at,
    }
  end

  def self.network_addresses(cloud_entry_point, ref_id)
    Log.debug(Log.format_method_start(self.class, __method__))
    client = cloud_entry_point.client
    response = client["networks/#{ref_id}"].get
    response_hash = JSON.parse(response)
    response_hash['network']['address_blocks']
  rescue
    Log.error(Log.format_error_params(
      self.class,
      __method__,
      response: response,
      response_hash: response_hash
    ))
    raise
  end

  private

  def client
    cloud_entry_point.client
  end

  def create_network_group
    Log.debug(Log.format_method_start(self.class, __method__))
    payload = {
      name: name,
      address_block: address_block,
    }
    response = client['networks'].post(payload)
    response_hash = JSON.parse(response)
    self.ref_id = response_hash['network']['id']
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

  def destroy_network_group
    Log.debug(Log.format_method_start(self.class, __method__))
    client["networks/#{ref_id}"].delete
  rescue
    Log.error(Log.format_error_params(self.class, __method__, attributes: attributes))
    raise
  end
end
