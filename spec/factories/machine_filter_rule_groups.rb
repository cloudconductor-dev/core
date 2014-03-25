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
FactoryGirl.define do
  factory :machine_filter_rule_group_address, class: MachineFilterRuleGroup do
    direction 'ingress'
    port_range_min 10_225
    port_range_max 20_225
    protocol 'tcp'
    action 'ALLOW'
    ethertype 'IPv4'
    remote_ip_address '0.0.0.0/0'
  end
  factory :machine_filter_rule_group_filter, class: MachineFilterRuleGroup do
    direction 'ingress'
    port_range_min 1
    port_range_max 65_532
    protocol 'tcp'
    action 'ALLOW'
    ethertype 'IPv4'
    association :remote_machine_filter_group_id, factory: :machine_filter_group_address
  end
end
