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
require 'pathname'
require 'rubygems' unless defined? ::Gem
require File.dirname( __FILE__ ) + '/app.rb'

# DB Settings
ActiveRecord::Base.configurations = YAML.load_file('config/database.yml')
ActiveRecord::Base.establish_connection(settings.environment)
ActiveRecord::Base.default_timezone = :local

# Autoload Settings
autoload_paths = ['src/models', 'src/controllers', 'src/actions']
autoload_paths.each do |path|
  ActiveSupport::Dependencies.autoload_paths << File.expand_path(path, File.dirname(__FILE__))
end

# preload file
Dir.glob('src/helpers/*').each do |file|
  ActiveSupport::Dependencies.require_or_load(file)
end

# Load settings
ConductorConfig.from_file('config/conductor_config.rb')

# Logger Settings
Log.new("#{ConductorConfig.log_dir}/#{ConductorConfig.log_file}", ConductorConfig.log_level)
# Multi Threading
use ActiveRecord::ConnectionAdapters::ConnectionManagement
Thread.new { EventMachine::run }

# Error Handler settings
disable :show_exceptions

# Run Sinatra
root = Pathname(File.expand_path(__FILE__)).parent.basename.to_s
map ("/#{root}") { run Sinatra::Application }
