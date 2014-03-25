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
  factory :machine_filter, class: MachineFilter do
    association :cloud_entry_point, factory: :openstack
    association :machine_filter_group, factory: :machine_filter_group_address
    ref_id 'fc78e6c7-6cc5-4e62-ac4a-9d1cff490d20'
    before(:create) do |filter|
      filter.class.skip_callback(:create, :before, :create_machine_filter)
    end
    after(:create) do |filter|
      filter.class.set_callback(:create, :before, :create_machine_filter)
    end
  end
end
