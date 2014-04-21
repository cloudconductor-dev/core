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
  factory :machine_group, class: MachineGroup do
    name 'Apache Web Server'
    min_size 1
    max_size 1
    node_type 'single'
    priority 10
    user_parameters '{"key1": "value1", "key2": "value2"}'
    association :system, factory: :system
    association :common_machine_config, factory: :small
    association :common_machine_image, factory: :centos
    association :role, factory: :web_role
    association :machine_filter_group, factory: :machine_filter_group
  end
end
