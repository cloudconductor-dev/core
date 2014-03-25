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

class MachineFilterRuleGroup < ActiveRecord::Base
  belongs_to :machine_filter_group
  has_many :machine_filter_rules, dependent: :destroy

  before_create :create_machine_filter_rule_group

  def to_h
    {
      id: id,
      direction: direction,
      port_range_min: port_range_min,
      port_range_max: port_range_max,
      protocol: protocol,
      action: action,
      remote_machine_filter_group: remote_machine_filter_group_id,
      remote_ip_address: remote_ip_address,
      create_date: created_at,
      update_date: updated_at
    }
  end

  private

  def create_machine_filter_rule_group
    Log.debug(Log.format_method_start(self.class, __method__))
    if remote_ip_address
      self.remote_ip_address = remote_ip_address.match('/') ? remote_ip_address : "#{remote_ip_address}/32"
    end
  end
end
