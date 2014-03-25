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
  factory :machine_filter_group, class: MachineFilterGroup do
    name 'MyFilter'
    description 'This is a filter'
    association :system, factory: :system
  end
  factory :machine_filter_group_address, class: MachineFilterGroup do
    name 'MyFilter'
    description 'This is a filter'
    association :system, factory: :system
    after(:create) do |filter|
      FactoryGirl.create(:machine_filter_rule_group_address, machine_filter_group: filter)
    end
  end
  factory :machine_filter_group_filter, class: MachineFilterGroup do
    name 'MyFilter'
    description 'This is a filter'
    association :system, factory: :system
    after(:create) do |filter|
      FactoryGirl.create(:machine_filter_rule_group_filter, machine_filter_group: filter)
    end
  end
end
