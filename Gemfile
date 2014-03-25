# Copyright 2014 TIS inc.
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

source 'https://rubygems.org'

gem 'sinatra', '>= 1.1.6'
gem 'sinatra-contrib', :require => 'sinatra/json'
gem 'unicorn'
gem 'rake'

gem 'sqlite3'
gem 'activerecord', '>= 4.0.0'
gem 'activesupport', :require => 'active_support/dependencies'
gem 'sinatra-activerecord', :require => 'sinatra/activerecord'
gem 'eventmachine'
gem 'rest-client'
gem 'kaminari', :require => 'kaminari/sinatra'
gem 'padrino-helpers'
gem 'net-ssh', :require => 'net/ssh'
gem 'net-scp', :require => 'net/scp'
gem 'nokogiri'
gem 'rack-parser'
gem 'mixlib-log'
gem 'mixlib-config'
gem 'rb-readline'

group :test do
  gem 'rack', :require => 'rack/test'
  gem 'rspec'
  gem 'rspec_junit_formatter'
  gem 'spork'
  gem 'webmock', '< 1.10', :require => 'webmock/rspec'
  gem 'vcr'
  gem 'factory_girl'
  gem 'guard'
  gem 'guard-spork'
  gem 'guard-rspec'
  gem 'guard-compass'
  gem 'rubocop'
  gem 'simplecov'
  gem 'simplecov-rcov'
  gem 'database_cleaner'
end
