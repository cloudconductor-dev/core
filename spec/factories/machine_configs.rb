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
  # MachineConfig for AWS
  factory :aws_t1_micro, class: MachineConfig do
    name 't1.micro'
    ref_id 't1.micro'
    cpu 1
    memory 613
    association :cloud_entry_point, factory: :aws
    association :common_machine_config, factory: :tiny
    before(:create) { |config| config.class.skip_callback(:create, :before, :find_machine_config) }
    after(:create) { |config| config.class.set_callback(:create, :before, :find_machine_config) }
  end
  factory :aws_m1_small, class: MachineConfig do
    name 'm1.small'
    ref_id 'm1.small'
    cpu 1
    memory 1740
    association :cloud_entry_point, factory: :aws
    association :common_machine_config, factory: :small
    before(:create) { |config| config.class.skip_callback(:create, :before, :find_machine_config) }
    after(:create) { |config| config.class.set_callback(:create, :before, :find_machine_config) }
  end
  factory :aws_m1_medium, class: MachineConfig do
    name 'm1.medium'
    ref_id 'm1.medium'
    cpu 2
    memory 3840
    association :cloud_entry_point, factory: :aws
    association :common_machine_config, factory: :medium
    before(:create) { |config| config.class.skip_callback(:create, :before, :find_machine_config) }
    after(:create) { |config| config.class.set_callback(:create, :before, :find_machine_config) }
  end
  # MachineConfig for OpenStack
  factory :openstack_m1_small, class: MachineConfig do
    name 'm1.small'
    ref_id 2
    cpu 1
    memory 1740
    association :cloud_entry_point, factory: :openstack
    association :common_machine_config, factory: :small
    before(:create) { |config| config.class.skip_callback(:create, :before, :find_machine_config) }
    after(:create) { |config| config.class.set_callback(:create, :before, :find_machine_config) }
  end
  factory :openstack_m1_medium, class: MachineConfig do
    name 'm1.medium'
    ref_id 3
    cpu 2
    memory 3840
    association :cloud_entry_point, factory: :openstack
    association :common_machine_config, factory: :medium
    before(:create) { |config| config.class.skip_callback(:create, :before, :find_machine_config) }
    after(:create) { |config| config.class.set_callback(:create, :before, :find_machine_config) }
  end

end
