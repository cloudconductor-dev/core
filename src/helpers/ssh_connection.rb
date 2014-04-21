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
require 'uri'

class SSHConnection
  # def initialize(entry_point, host, user, key = nil, pass = nil, ssh_proxy = nil)
  def initialize(params)
    Log.debug(Log.format_method_start(self.class, __method__))
    @host = params[:host]
    @user = params[:user]
    @opts = { host_key_alias: @host }
    Log.debug(Log.format_debug_param(host: @host))
    Log.debug(Log.format_debug_param(user: @user))
    @key_file = Tempfile.open('ssh_key')
    @key_file.write(params[:key])
    @key_file.close
    @opts[:user_known_hosts_file] = '/dev/null'
    @opts[:keys] = [@key_file.path] if params[:key]
    @opts[:password] = params[:pass] if params[:pass]
    Log.debug(' ----- Create http_proxy ----- ')
    Log.debug(Log.format_debug_param(params_entry_point: params[:entry_point]))
    Log.debug(Log.format_debug_param(params_c_name: params[:c_name]))
    http_proxy = find_http_proxy(params[:entry_point], params[:c_name])
    ssh_proxy = params[:ssh_proxy]
    if ssh_proxy && http_proxy
      @opts[:proxy] = Net::SSH::Proxy::Command.new("ssh -o 'ProxyCommand nc -X connect -x #{http_proxy} #{ssh_proxy} 22' -o stricthostkeychecking=no -i #{@key_file.path} -l #{@user} #{ssh_proxy} -W %h:%p")
    elsif ssh_proxy && http_proxy.nil?
      @opts[:proxy] = Net::SSH::Proxy::Command.new("ssh #{@user}@#{ssh_proxy} -o stricthostkeychecking=no -W %h:%p -i #{@key_file.path}")
    elsif ssh_proxy.nil? && http_proxy
      @opts[:proxy] = Net::SSH::Proxy::Command.new("nc -X connect -x #{http_proxy} #{@host} 22")
    end
    Log.debug(Log.format_debug_param(opts_proxy: @opts[:proxy]))
    Log.debug(Log.format_debug_param(ssh_proxy_command_template: @opts[:proxy].command_line_template)) unless @opts[:proxy].nil?
  end

  def run_chef_solo(node_json, chef_home = '/tmp/chef-repo')
    Log.debug(Log.format_method_start(self.class, __method__))
    Log.debug(Log.format_debug_param(node_json: node_json))
    Log.debug(Log.format_debug_param(chef_home: chef_home))
    begin
      Net::SSH.start(@host, @user, @opts) do |ssh|
        Log.debug(Log.format_debug_param(host: @host))
        Log.debug(Log.format_debug_param(user: @user))
        Log.debug(Log.format_debug_param(opts: @opts))
        ssh.exec!("echo '#{node_json}' > #{chef_home}/config/node.json")
        run_check = ssh.exec!("/opt/chef/bin/chef-solo -c #{chef_home}/config/solo.rb -j #{chef_home}/config/node.json -l debug -L /tmp/run_chef_solo.log ; echo $?").to_i
        Log.debug(Log.format_debug_param(run_check: run_check))
        fail 'Chef_solo_error' unless run_check == 0
      end
    rescue RuntimeError => e
      Log.error(Log.format_error_params(
        self.class,
        __method__,
        host: @host,
        user: @user,
        opts: @opts
      ))
      raise 'Chef_solo is Failed. Please Check target server log'
    rescue
      Log.error(Log.format_error_params(
        self.class,
        __method__,
        host: @host,
        user: @user,
        opts: @opts
      ))
      raise
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

  def find_http_proxy(entry_point, c_name)
    Log.debug(Log.format_method_start(self.class, __method__))
    Log.debug(Log.format_debug_param(entry_point: entry_point))
    Log.debug(Log.format_debug_param(c_name: c_name))
    unless c_name == 'AWS'
      Log.debug(' ----- c_name is not AWS ----- ')
      entry_point_uri = URI.parse(entry_point)
      unless entry_point_uri.find_proxy.nil?
        Log.debug(' ----- entry_point_uri is not Nil!! ----- ')
        if ENV['https_proxy']
          proxy_uri = URI.parse(ENV['https_proxy'])
        elsif ENV['http_proxy']
          proxy_uri = URI.parse(ENV['http_proxy'])
        end
      end
    end

    unless proxy_uri.nil?
      Log.debug(' ----- proxy_uri is not Nil!! ----- ')
      Log.debug(Log.format_debug_param(proxy_uri: proxy_uri))
      if proxy_uri.userinfo.nil?
        proxy = "#{proxy_uri.host}:#{proxy_uri.port}"
      else
        proxy = "#{proxy_uri.userinfo}@#{proxy_uri.host}:#{proxy_uri.port}"
      end
    end
  end
end
