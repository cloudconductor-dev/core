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
require 'rest_client'

class CloudEntryPoint < ActiveRecord::Base
  belongs_to :infrastructure
  has_many :machines, dependent: :destroy
  has_many :network_groups, dependent: :destroy
  has_many :volumes, dependent: :destroy
  has_many :machine_images, dependent: :destroy
  has_many :machine_configs, dependent: :destroy
  has_many :credentials, dependent: :destroy
  has_many :floating_ips, dependent: :destroy
  has_many :machine_filters, dependent: :destroy

  def client
    deltacloud_url = "http://#{ConductorConfig.deltacloud_host}:#{ConductorConfig.deltacloud_port}/api"
    default_headers = { headers: {
      Accept: 'application/json',
      :'Content-Type' => 'application/json',
      :'X-Deltacloud-Driver' => infrastructure.driver,
      :'X-Deltacloud-Provider' => entry_point,
      Authorization: "Basic #{Base64.strict_encode64("#{key}:#{secret}")}",
    } }
    RestClient::Resource.new(deltacloud_url, default_headers)
  end

  def external_net_addrs
    Log.debug(Log.format_method_start(self.class, __method__))
    external_network_ref_ids = Gateway.external_network_ref_ids(self)
    external_net_addrs = []
    external_network_ref_ids.each do |ref_id|
      network_addresses = NetworkGroup.network_addresses(self, ref_id)
      external_net_addrs += network_addresses
    end
    external_net_addrs
  rescue
    error_cloud = attributes
    error_cloud['key'] = '***'
    error_cloud['secret'] = '***'
    error_cloud['proxy_user'] = '***'
    error_cloud['proxy_password'] = '***'
    Log.error(Log.format_error_params(
      self.class,
      __method__,
      attributes: error_cloud,
      external_network_ref_ids: external_network_ref_ids,
      external_net_addrs: external_net_addrs
    ))
    raise
  end

  def to_h
    {
      id: id,
      name: name,
      entry_point: entry_point,
      key: key,
      secret: secret,
      infrastructure: infrastructure.to_h,
      proxy_url: proxy_url,
      proxy_user: proxy_user,
      proxy_password: proxy_password,
      no_proxy: no_proxy,
      create_date: created_at,
      update_date: updated_at,
    }
  end
end
