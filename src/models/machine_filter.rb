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

class MachineFilter < ActiveRecord::Base
  belongs_to :cloud_entry_point
  belongs_to :machine_filter_group
  has_many :machine_filter_rules

  before_create :create_machine_filter
  before_destroy :destroy_machine_filter

  private

  def client
    cloud_entry_point.client
  end

  def create_machine_filter
    Log.debug(Log.format_method_start(self.class, __method__))

    response = client['firewalls'].get
    firewalls = JSON.parse(response)['firewalls']
    index = 1

    firewalls.each do |x|
      name = x['name']
      if name =~ /#{machine_filter_group.name}-(\d+)$/
        index = Regexp.last_match(1).to_i + 1 if index <= Regexp.last_match(1).to_i
      end
    end

    network_group = NetworkGroup.find_by(
      cloud_entry_point: cloud_entry_point,
      system: machine_filter_group.system
    )

    payload = {
      name: "#{machine_filter_group.name}-#{index}",
      description: machine_filter_group.description,
      network_id: network_group.ref_id,
    }
    response = client['firewalls'].post(payload)
    response_hash = JSON.parse(response)['firewall']
    self.ref_id = response_hash['id']
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

  def destroy_machine_filter
    Log.debug(Log.format_method_start(self.class, __method__))
    client["firewalls/#{ref_id}"].delete
  rescue
    Log.error(Log.format_error_params(self.class, __method__, attributes: attributes))
    raise
  end
end
