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
require 'net/ssh'
require 'net/scp'
require 'net/ssh/proxy/command'
require 'tempfile'

class SSHConnection
  def initialize(host, user, key = nil, pass = nil, proxy_host = nil)
    Log.debug(Log.format_method_start(self.class, __method__))
    @host = host
    @user = user
    @opts = { host_key_alias: @host }
    Log.debug(Log.format_debug_param(host: @host))
    Log.debug(Log.format_debug_param(user: @user))
    @key_file = Tempfile.open('ssh_key')
    @key_file.write(key)
    @key_file.close
    @opts[:user_known_hosts_file] = '/dev/null'
    @opts[:keys] = [@key_file.path] if key
    @opts[:password] = pass if pass
    @opts[:proxy] = Net::SSH::Proxy::Command.new("ssh #{user}@#{proxy_host} -o stricthostkeychecking=no -W %h:%p -i #{@key_file.path}") if proxy_host
  end

  def run_chef_solo(node_json, chef_home = '/tmp/chef-repo')
    Log.debug(Log.format_method_start(self.class, __method__))
    Log.debug(Log.format_debug_param(node_json: node_json))
    Log.debug(Log.format_debug_param(chef_home: chef_home))
    Net::SSH.start(@host, @user, @opts) do |ssh|
      ssh.exec!("echo '#{node_json}' > #{chef_home}/config/node.json")
      check_chef_solo = ssh.exec!("/opt/chef/bin/chef-solo -c #{chef_home}/config/solo.rb -j #{chef_home}/config/node.json")
      Log.debug(Log.format_debug_param(check_chef_solo: check_chef_solo))
    end
  end

  def exec_script(script)
    Log.debug(Log.format_method_start(self.class, __method__))
    Net::SSH.start(@host, @user, @opts) do |ssh|
      ssh.open_channel do |channel|
        channel.on_data do |ch, data|
          data.each_line { |line| Log.info(line) }
        end
        channel.on_extended_data do |ch, type, data|
          data.each_line { |line| Log.error(line) }
        end
        channel.on_request 'exit-status' do |ch, data|
          if data.read_long != 0
            Log.error(Log.format_error_params(
              self.class,
              __method__,
              location: 'channel.on_request',
              channel: ch,
              data: data
            ))
            fail "SSH Failed: process terminated with exit status: #{data.read_long}"
          end
        end
        channel.send_channel_request 'shell' do |ch, success|
          unless success
            Log.error(Log.format_error_params(
              self.class,
              __method__,
              location: 'channel.send_channel_request',
              channel: ch,
              success: success
            ))
            fail 'SSH Failed: could not start user shell'
          end
        end
        channel.send_data(script)
        channel.send_data("\n")
        channel.process
        channel.eof!
      end
      ssh.loop
    end
  end

  def exec!(command)
    Log.debug(Log.format_method_start(self.class, __method__))
    Log.debug(Log.format_debug_param(command: command))
    Net::SSH.start(@host, @user, @opts) do |ssh|
      ssh.exec!(command)
    end
  end

  def scp(src, dst)
    Log.debug(Log.format_method_start(self.class, __method__))
    Net::SSH.start(@host, @user, @opts) do |ssh|
      ssh.scp.upload!(src, dst)
    end
  end
end
