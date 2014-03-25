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
  factory :apache, class: Middleware do
    name 'apache2'
    cookbook_name 'apache2'
    repository 'https://github.com/opscode-cookbooks/apache2.git'
    association :role, factory: :web_role
  end
  factory :tomcat, class: Middleware do
    name 'tomcat7'
    cookbook_name 'tomcat7'
    repository 'https://github.com/opscode-cookbooks/tomcat7.git'
    association :role, factory: :ap_role
  end
  factory :postgresql, class: Middleware do
    name 'postgresql'
    cookbook_name 'postgresql'
    repository 'https://github.com/opscode-cookbooks/postgresql.git'
    association :role, factory: :db_role
  end
  factory :zabbix, class: Middleware do
    name 'zabbix'
    cookbook_name 'zabbix'
    repository 'https://github.com/opscode-cookbooks/zabbix.git'
    association :role, factory: :zabbix_role
  end
end
