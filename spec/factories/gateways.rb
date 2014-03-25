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
  factory :gateway, class: Gateway do
    ref_id 'igw-12345678'
    name 'igw-12345678'
    association :system, factory: :system
    association :cloud_entry_point, factory: :aws
    before(:create) do |gateway|
      gateway.class.skip_callback(:create, :before, :create_gateway)
    end
    after(:create) do |gateway|
      gateway.class.set_callback(:create, :before, :create_gateway)
    end
  end
end
