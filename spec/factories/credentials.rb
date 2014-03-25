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
  factory :aws_key, class: Credential do
    name 'aws_key'
    public_key 'public_key_string'
    private_key 'private_key_string'
    association :cloud_entry_point, factory: :aws
    association :system, factory: :system
    before(:create) do |credential|
      credential.class.skip_callback(:create, :before, :create_credential)
    end
    after(:create) do |credential|
      credential.class.set_callback(:create, :before, :create_credential)
    end
  end

  factory :openstack_key, class: Credential do
    name 'openstack-key'
    public_key 'public_key_string'
    private_key 'private_key_signature'
    association :cloud_entry_point, factory: :openstack
    association :system, factory: :system
    before(:create) do |credential|
      credential.class.skip_callback(:create, :before, :create_credential)
    end
    after(:create) do |credential|
      credential.class.set_callback(:create, :before, :create_credential)
    end
  end
end
