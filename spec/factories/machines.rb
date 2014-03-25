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
  factory :machine, class: Machine do
    name 'Web Server 1'
    ref_id 'i-12345678'
    state 'RUNNING'
    association :cloud_entry_point, factory: :aws
    association :machine_group, factory: :machine_group
    association :machine_config, factory: :aws_m1_small
    association :machine_image, factory: :aws_centos
    before(:create) do |machine|
      unless Credential.find_by(system: machine.machine_group.system, cloud_entry_point: machine.cloud_entry_point)
        FactoryGirl.create(:aws_key)
      end
      machine.class.skip_callback(:create, :before, :create_machine)
      machine.class.skip_callback(:create, :after, :store_network_interfaces)
    end
    after(:create) do |machine|
      machine.class.set_callback(:create, :before, :create_machine)
      machine.class.set_callback(:create, :after, :store_network_interfaces)
      FactoryGirl.create(:network_interface, machine: machine)
      FactoryGirl.create(:floating_ip, machine: machine, system: machine.machine_group.system)
    end
  end
end
