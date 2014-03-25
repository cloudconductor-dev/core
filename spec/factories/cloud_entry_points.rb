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
  factory :aws, class: CloudEntryPoint do
    name 'AWS Tokyo'
    entry_point 'ap-northeast-1'
    key 'AKIAJHVY6PW4MECKHITQ'
    secret '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'
    association :infrastructure, factory: :aws_infra
  end
  factory :openstack, class: CloudEntryPoint do
    name 'My OpenStack'
    entry_point 'http://localhost:5000/v2.0/'
    key 'demo+demo'
    secret 'demo'
    proxy_url '172.26.1.7:8080'
#    proxy_user 'cloud-conductor'
#    proxy_password 'conductor'
    no_proxy 'localhost,127.0.0.1,169.254.169.254'
    association :infrastructure, factory: :openstack_infra
  end
end
