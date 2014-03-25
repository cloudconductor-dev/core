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
require 'mixlib/config'

class ConductorConfig
  extend Mixlib::Config
  default :cloudinit_log_file,  '/tmp/cloudconductor-cloudinit.log'
  default :log_level, :error
  default :subnet_address_block, address_block
  default :target_os_type, 'centos'

  config_context :machine do
    default :create_timeout, 30
    config_context :cloudinit do
      default :check_interval, 60
      default :max_check_number, 120
    end
  end

  config_context :machine_filter_rule do
    default :create_timeout, 2
    default :create_retry, 5
  end

  def self.from_file(file)
    super(file)

    # simple validation, throws exception if IP range is not valid
    IPAddr.new(address_block)
    IPAddr.new(subnet_address_block)

    addr, prefix = subnet_address_block.split('/')
    octet = addr.split('.')
    fail 'subnet_address_block 3rd octet should be <= 254' if octet[2].to_i >= 255
    case target_os_type.downcase
    when 'centos', 'rhel'
      self.cloudinit_path = File.join(File.expand_path('../userdata', File.dirname(__FILE__)), 'rhel/cloud_init.erb')
    else
      fail 'Missing or Forbidden target os type in Config file'
    end

    # should be specified deltacloud settings
    fail 'deltacloud_host is not specified'  unless keys.include?(:deltacloud_host)
    fail 'deltacloud_port is not specified'  unless keys.include?(:deltacloud_port)
  end
end
