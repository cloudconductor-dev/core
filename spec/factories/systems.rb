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
require 'json'

FactoryGirl.define do
  factory :system, class: System do
    before(:create) do |system|
      system.cloud_relation_parameters = { cloud1: "#{FactoryGirl.create(:openstack).id}" }.to_json
    end
    name 'New System'
    description 'New System Description'
    state 'creating'
    response_message ''
    template_uri 'https://raw.github.com/cloudconductor-dev/xml-store/master/template.xml'
    template_xml File.read(File.expand_path('../fixtures/system_template.xml', File.dirname(__FILE__)))
    meta_xml '<meta_xml>...</meta_xml>'
    user_parameters '{"name": "rspec-system", "description": "this is a test system", "machine_id": {"1.apache.server.hostname": "test"}}'
  end
end
