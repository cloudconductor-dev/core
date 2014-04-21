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
require 'uri'
require 'bundler/setup'
Bundler.require(:default, :test)
require_relative '../src/helpers/log'

# coverage setting
SimpleCov.formatter = SimpleCov::Formatter::RcovFormatter
SimpleCov.start

Spork.prefork do
  $LOAD_PATH.unshift ENV['RBENV_DIR']
  ActiveRecord::Base.configurations = YAML.load_file('config/database.yml')
  ActiveRecord::Base.establish_connection(:test)
  ActiveRecord::Base.default_timezone = :local
  ActiveRecord::Base.logger = Logger.new('log/test_activerecord.log')

  autoload_paths = ['../src/models', '../src/controllers', '../src/actions', '../src/helpers']
  autoload_paths.each do |path|
    ActiveSupport::Dependencies.autoload_paths << File.expand_path(File.dirname(__FILE__) + '/' + path)
  end

  FactoryGirl.definition_file_paths = %w{./factories ./spec/factories}
  FactoryGirl.find_definitions
  VCR.configure do |c|
    c.cassette_library_dir = 'spec/vcr'
    c.hook_into :webmock
    # c.allow_http_connections_when_no_cassette = true
  end
  Log.new('log/test_conductor.log', Logger::INFO)
  ConductorConfig.from_file(File.expand_path('spec/fixtures/conductor_config.rb'))
  Thread.new { EventMachine.run }
  RSpec.configure do |config|
    config.before(:suite) do
      DatabaseCleaner.strategy = :truncation
      DatabaseCleaner.clean
    end
  end
end

Spork.each_run do
  FactoryGirl.reload
end
