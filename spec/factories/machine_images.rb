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
  # MachineImage for AWS
  factory :aws_centos, class: MachineImage do
    name 'CentOS 6.4 + cloud-init'
    ref_id 'ami-651a9b64'
    association :cloud_entry_point, factory: :aws
    association :common_machine_image, factory: :centos
    before(:create) { |image| image.class.skip_callback(:create, :before, :create_machine_image) }
    after(:create) { |image| image.class.set_callback(:create, :before, :create_machine_image) }
  end
  # MachineImage for OpenStack
  factory :openstack_centos, class: MachineImage do
    name 'CentOS 6.5 + cloud-init'
    ref_id 'b20ffa73-661e-404e-8b53-220d1b2d047c'
    association :cloud_entry_point, factory: :openstack
    association :common_machine_image, factory: :centos
    before(:create) { |image| image.class.skip_callback(:create, :before, :create_machine_image) }
    after(:create) { |image| image.class.set_callback(:create, :before, :create_machine_image) }
  end
end
