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
require 'pp'

class MachineFilterRule < ActiveRecord::Base
  belongs_to :machine_filter_rule_group
  belongs_to :machine_filter

  before_create :create_machine_filter_rule
  before_destroy :destroy_machine_filter_rule

  private

  def client
    machine_filter.cloud_entry_point.client
  end

  def create_machine_filter_rule
    Log.debug(Log.format_method_start(self.class, __method__))
    return true if machine_filter_rule_group.action.upcase == 'DENY'
    payload = {
      protocol: machine_filter_rule_group.protocol,
      port_from: machine_filter_rule_group.port_range_min,
      port_to: machine_filter_rule_group.port_range_max,
      direction: machine_filter_rule_group.direction,
      ethertype: machine_filter_rule_group.ethertype,
      ip_address: machine_filter_rule_group.remote_ip_address
    }

    response = client["firewalls/#{machine_filter.ref_id}/rules"].post(payload)
    rules = JSON.parse(response.body)['firewall']['rules']
    match_rule = nil

    (1..ConductorConfig.machine_filter_rule.create_retry).each do |count|
      response = client["firewalls/#{machine_filter.ref_id}"].get
      rules = JSON.parse(response.body)['firewall']['rules']

      match_rule = rules.find do |rule|
        b1 = rule['allow_protocol'] == machine_filter_rule_group.protocol &&
        rule['port_from'].to_i == machine_filter_rule_group.port_range_min &&
        rule['port_to'].to_i == machine_filter_rule_group.port_range_max &&
        rule['direction'] ==  machine_filter_rule_group.direction
        b2 = false

        rule['sources'] && rule['sources'].each do |s|
          b2 = s['type'] == 'address' &&
               s['family'].upcase == machine_filter_rule_group.ethertype.upcase &&
               s['address'] == machine_filter_rule_group.remote_ip_address.split('/').first &&
               s['prefix'] == machine_filter_rule_group.remote_ip_address.split('/').last ||
               s['type'] == 'group' &&
               s['remote_group_id'] == machine_filter_rule_group.remote_machine_filter_group_id
          break if b2
        end

        b1 && b2
      end

      break unless match_rule.nil?
      Log.warn("firewall rule match failed retrying #{count}")
      sleep ConductorConfig.machine_filter_rule.create_timeout
    end

    fail 'Not found filter rule in cloud matching with machine_filter_rule_group' if match_rule.nil?
    self.ref_id = match_rule['id']
  rescue
    Log.error(Log.format_error_params(
      self.class,
      __method__,
      attributes: attributes,
      payload: payload,
      response: response,
      rules: rules,
      machine_filter_rule_group: machine_filter_rule_group
    ))
    raise
  end

  def destroy_machine_filter_rule
    Log.debug(Log.format_method_start(self.class, __method__))
    client["firewalls/#{machine_filter.ref_id}/rules/#{ref_id}"].delete
  rescue
    Log.error(Log.format_error_params(self.class, __method__, attributes: attributes))
    raise
  end
end
