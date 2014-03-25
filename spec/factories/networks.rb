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
  factory :network, class: Network do
    name 'subnet-12345678'
    ref_id 'subnet-12345678'
    network_address '10.0.1.0'
    prefix 24
    association :network_group, factory: :network_group
    association :gateway, nil
    before(:create) do |network|
      network.class.skip_callback(:create, :before, :create_network)
    end
    after(:create) do |network|
      network.class.set_callback(:create, :before, :create_network)
    end
  end
end
