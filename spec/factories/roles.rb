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
  factory :web_role, class: Role do
    name 'Apache 2.4'
    attribute_id 'web_role'
    setup_run_list '["recipe[apache2]"]'
    deploy_run_list '["recipe[apache2::deploy]"]'
    setup_parameters '{}'
    deploy_parameters '{}'
    association :system, factory: :system
    after(:create) do |role|
      FactoryGirl.create(:apache, role: role)
    end
  end
  factory :ap_role, class: Role do
    name 'Tomcat 7'
    attribute_id 'ap_role'
    setup_run_list '["recipe[tomcat]"]'
    deploy_run_list '["recipe[tomcat::deploy]"]'
    setup_parameters '{}'
    deploy_parameters <<-EOS
    {"tomcat": {
        "base_version": 6,
        "keytool":"/usr/bin/keytool",
        "roles": ["manager-gui", "admin-gui"],
        "users": [{
          "id": "tomcat7",
          "password": "tomcat7",
          "roles": ["manager-gui", "admin-gui"]
        }]
    },
    "java": {
      "install_flavor": "openjdk",
      "jdk_version": 6,
      "java_home": "/usr/share/java"
    },
    "application_java" : {
      "name" : "<%= params[:app_name] %>",
      "path" : "<%= params[:path] %>",
      "repository" : "<%= params[:repository] %>",
      "username" : "<%= params[:app_name] %>",
      "password" : "<%= params[:app_name] %>",
      "driver"   : "org.postgresql.Driver",
      "adapter"  : "postgresql",
      "host"     : "<%= params[:host] %>",
      "port"     : "5432",
      "database" : "<%= params[:app_name] %>",
      "max_active" : 5,
      "max_idle"   : 5,
      "max_wait"   : -1
    }}
    EOS
    association :system, factory: :system
    after(:create) do |role|
      FactoryGirl.create(:tomcat, role: role)
    end
  end
  factory :db_role, class: Role do
    name 'Postgresql 9.3'
    attribute_id 'db_role'
    setup_run_list '["recipe[postgresql]"]'
    deploy_run_list '["recipe[postgresql::deploy]"]'
    setup_parameters '{}'
    deploy_parameters '{}'
    association :system, factory: :system
    after(:create) do |role|
      FactoryGirl.create(:postgresql, role: role)
    end
  end
  factory :zabbix_role, class: Role do
    name 'Zabbix'
    attribute_id 'zabbix_dns_role'
    setup_run_list '["recipe[zabbix]"]'
    deploy_run_list '{}'
    setup_parameters '{}'
    deploy_parameters '{}'
    association :system, factory: :system
    after(:create) do |role|
      FactoryGirl.create(:zabbix, role: role)
    end
  end
end
