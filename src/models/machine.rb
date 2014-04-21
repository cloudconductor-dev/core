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
require 'sinatra/activerecord'
require 'json'
require 'base64'

class Machine < ActiveRecord::Base
  belongs_to :cloud_entry_point
  belongs_to :machine_group
  belongs_to :machine_config
  belongs_to :machine_image
  has_many :network_interfaces, dependent: :destroy
  has_many :networks, through: :network_interfaces
  has_many :volumes
  has_many :floating_ips

  attr_accessor :attach_network
  attr_accessor :machine_name
  attr_accessor :host_name_base
  before_create :create_machine
  after_create :store_network_interfaces
  before_destroy :destroy_machine

  # validation
#  validates :host_name_base, :length => (1..20), :format => /\A[a-zA-Z0-9][a-zA-Z0-9\-\.]+/

  def to_h
    {
      id: id,
      name: machine_name,
      status: state_check(state),
      cloud_entry_point: {
        id: cloud_entry_point.id,
        name: cloud_entry_point.name,
        create_date: cloud_entry_point.created_at,
        update_date: cloud_entry_point.updated_at
      },
      machine_group: {
        id: machine_group.id,
        name: machine_group.name,
        description: machine_group.description,
        create_date: machine_group.created_at,
        update_date: machine_group.updated_at,
        common_machine_image: machine_group.common_machine_image.attributes,
        common_machine_config: machine_group.common_machine_config.attributes
      },
      machine_image: machine_image.attributes,
      machine_config: machine_config.attributes,
      volumes: volumes.map { |volume| volume.attributes },
      addresses: network_interfaces.map { |nic| nic.attributes },
      floating_ip: floating_ips.map { |ip| ip.attributes },
      create_date: created_at,
      update_date: updated_at
    }
  end

  def latest_state
    Log.debug(Log.format_method_start(self.class, __method__))
    response = client["instances/#{ref_id}"].get
    state = JSON.parse(response)['instance']['state']
    update_attributes(state: state)
    state
  rescue
    Log.error(Log.format_error_params(
      self.class,
      __method__,
      attributes: attributes,
      response: response
    ))
    raise
  end

  def wait_for(state, timeout = ConductorConfig.machine.create_timeout)
    Log.debug(Log.format_method_start(self.class, __method__))
    timeout.times do
      st = latest_state
      return true if st == state
      return false if st == 'ERROR'
      sleep 1
    end
    false
  end

  def wait_serial(template)
    Log.debug(Log.format_method_start(self.class, __method__))
    Log.debug(Log.format_debug_param(attributes: attributes))
    template_volumes = template.list('MachineGroup').find { |grp| grp[:name] == machine_group.name }[:volumes]
    loop_count = 0
    loop do
      begin
        loop_count += 1
        Log.debug(Log.format_debug_param(loop_count: loop_count))
        fail "Time out error in checking Cloudinit log.Do you have external ip in a springboard machine? And confirming Cloudinit log in machine #{name}" if loop_count >= ConductorConfig.machine.cloudinit.max_check_number
        m_state = state_check(state, template_volumes)
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ETIMEDOUT, Net::SSH::Disconnect, Net::SSH::AuthenticationFailed, Net::SSH::Proxy::ConnectError
        sleep ConductorConfig.machine.cloudinit.check_interval
        retry
      rescue => e
        Log.error(Log.format_error_params(
          self.class,
          __method__,
          attributes: attributes,
          loop_count: loop_count,
          m_state: m_state
        ))
        raise
      end
      Log.debug(Log.format_debug_param(machine_state: m_state))
      if m_state == 'DONE'
        break
      elsif m_state == 'RUNNING' || m_state == 'PENDING'
        sleep ConductorConfig.machine.cloudinit.check_interval
        next
      else
        Log.error(Log.format_error_params(
          self.class,
          __method__,
          attributes: attributes,
          loop_count: loop_count,
          machine_state: m_state
        ))
        fail "Cloudinit is Failed with machine state #{m_state}"
      end
    end
  end

  private

  def client
    cloud_entry_point.client
  end

  def create_machine
    Log.debug(Log.format_method_start(self.class, __method__))
    machine_filter = machine_group.machine_filter_group.machine_filters.find { |filter| filter.cloud_entry_point.id == cloud_entry_point.id }
    payload = {
      name: machine_name,
      hwp_id: machine_config.ref_id,
      image_id: machine_image.ref_id,
      subnet_id: attach_network.ref_id,
      keyname: cloud_entry_point.credentials.find_by(system: machine_group.system).name,
      user_data: build_userdata,
      firewalls1: machine_filter.ref_id,
    }
    response = client['instances'].post(payload)
    response_hash = JSON.parse(response)
    self.ref_id = response_hash['instance']['id']
    self.state = response_hash['instance']['state']
  rescue => e
    Log.error(Log.format_error_params(
      self.class,
      __method__,
      attributes: attributes,
      payload: payload,
      response: response,
      response_hash: response_hash
    ))
    raise
  end

  def destroy_machine
    Log.debug(Log.format_method_start(self.class, __method__))
    client["instances/#{ref_id}"].delete
  rescue => e
    Log.error(Log.format_error_params(self.class, __method__, attributes: attributes))
    raise
  end

  def store_network_interfaces
    Log.debug(Log.format_method_start(self.class, __method__))
    fail 'Failed to launch machine(state does not change running) in Machine.store_network_interfaces' unless wait_for('RUNNING')
    response = client['network_interfaces'].get
    all_interfaces = JSON.parse(response)['network_interfaces']
    machine_interfaces = all_interfaces.select { |nic| nic['instance']['id'] == ref_id }
    machine_interfaces.each do |nic|
      NetworkInterface.create(
        ref_id: nic['id'],
        ip_address: nic['ip_address'],
        machine: self,
        network: attach_network
      )
    end
  rescue
    Log.error(Log.format_error_params(
      self.class,
      __method__,
      attributes: attributes,
      response: response,
      all_interfaces: all_interfaces
    ))
    raise
  end

  def build_userdata
    Log.debug(Log.format_method_start(self.class, __method__))
    template = XmlParser.new(machine_group.system.template_xml)
    hostname = build_hostname
    mountpoints = build_mountpoints(template)
    self.name = hostname
    userdata_template_file = ConductorConfig.cloudinit_path
    userdata_template = ERB.new(File.read(userdata_template_file), nil, '-')
    proxy = build_proxy_setting
    role = machine_group.role
    chef_attributes = JSON.parse(role.setup_parameters, symbolize_names: true) || {}
    chef_attributes.deep_merge!(build_system_parameters(template, hostname))
    chef_attributes.deep_merge!(JSON.parse(machine_group.user_parameters, symbolize_names: true))
    chef_attributes.deep_merge!(run_list: JSON.parse(role.setup_run_list, symbolize_names: true))
    node_json = JSON.pretty_generate(chef_attributes)
    middlewares = role.middlewares.to_a
    cookbooks = cookbooks_in_run_list(JSON.parse(role.setup_run_list)).uniq
    cloudinit = userdata_template.result(binding)
    Log.debug(Log.format_debug_param(role: role))
    Log.debug(Log.format_debug_param(chef_attributes: chef_attributes))
    Log.debug(Log.format_debug_param(setup_json: node_json))
    Log.debug(Log.format_debug_param(middlewares: middlewares))
    Log.debug(Log.format_debug_param(cookbooks: cookbooks))
    Log.debug(Log.format_debug_param(cloudinit: cloudinit))
    Base64.encode64(cloudinit)
  rescue
    Log.error(Log.format_error_params(
      self.class,
      __method__,
      attributes: attributes,
      userdata_template_file: userdata_template_file,
      proxy: proxy,
      chef_attributes: chef_attributes,
      node_json: node_json,
      middlewares: middlewares,
      cookbooks: cookbooks,
      cloudinit: cloudinit,
    ))
    raise
  end

  def build_mountpoints(template)
    Log.debug(Log.format_method_start(self.class, __method__))
    template_volumes = template.list('MachineGroup').find { |grp| grp[:name] == machine_group.name }[:volumes]
    mountpoints = template_volumes.map { |vol| vol[:mount_point] } if template_volumes
    mountpoints
  end

  def build_proxy_setting
    if admin_server?
      {
        url: cloud_entry_point.proxy_url,
        username: cloud_entry_point.proxy_user,
        password: cloud_entry_point.proxy_password,
        noproxy: cloud_entry_point.no_proxy
      }
    else
      dns_server_ip = NetworkInterface.find_by(
        machine: machine_group.system.dns_server
      ).ip_address
      {
        url: "#{dns_server_ip}:3128",
        noproxy: 'localhost,127.0.0.1,169.254.169.254'
      }
    end
  end

  def build_system_parameters(template, hostname)
    Log.debug(Log.format_method_start(self.class, __method__))
    if admin_server?
      build_server_parameters(template, hostname)
    else
      build_client_parameters(machine_group, hostname)
    end
  end

  def build_server_parameters(template, hostname)
    Log.debug(Log.format_method_start(self.class, __method__))
    server_param = {
      zabbix: {
        hosts: template.list('MachineGroup').map do |machine_group|
          {
            name: machine_group[:name],
            templates: machine_group[:monitorings] ? machine_group[:monitorings].map { |mon| mon[:name] } : []
          }
        end,
        host_group: 'CloudConductor_Zabbix',
        server: {
          ipaddress: '127.0.0.1'
        },
        import_files: template.find('System')[:monitorings].map do |monitoring|
          openuri = ProxyauthOpenUri.new
          {
            file_url: monitoring[:template],
            current_template_name: Nokogiri::XML(openuri.read_url(monitoring[:template])).xpath('*/templates/template/name/text()').first.content,
            update_template_name: monitoring[:name]
          }
        end,
        agent: {
          host_metadata: machine_group.name,
          server: hostname,
          server_active: hostname,
        }
      },
      net: {
        hostname: hostname
      },
      :'cc-bind' => {
        network: machine_group.system.network_groups.find { |ng| ng.cloud_entry_point.id == cloud_entry_point.id }.address_block
      }
    }
    unless cloud_entry_point.proxy_url.blank?
      server_param.deep_merge!(
        squid: {
          cache_peer: "cache_peer #{cloud_entry_point.proxy_url.split(':').first} parent #{cloud_entry_point.proxy_url.split(':').last} 0 no-query\nnever_direct allow all"
        }
      )
    end
    server_param
  end

  def build_client_parameters(machine_group, hostname)
    Log.debug(Log.format_method_start(self.class, __method__))
    dns_server = machine_group.system.dns_server
    {
      zabbix: {
        agent: {
          host_metadata: machine_group.name,
          server: dns_server.name,
          server_active: dns_server.name,
        }
      },
      nsupdate: {
        dns_server: dns_server.network_interfaces.first.ip_address
      },
      net: {
        hostname: hostname
      }
    }
  end

  def cookbooks_in_run_list(run_list)
    Log.debug(Log.format_method_start(self.class, __method__))
    run_list.reduce([]) do |res, r|
      next unless r.include?('recipe')
      cookbook = r.include?('::') ? r.match(%r{recipe\[(.+)::})[1] : r.match(%r{recipe\[(.+)\]})[1]
      res << cookbook
    end
  end

  def state_check(base_state, template_volumes = nil)
    Log.debug(Log.format_method_start(self.class, __method__))
    if base_state == 'DONE' || base_state == 'STOPPING' || base_state == 'STOPPED' || base_state == 'FINISH'
      return base_state
    end
    if admin_server?
      host = floating_ips.first.ip_address
    else
      host = NetworkInterface.find_by(id: id).ip_address
      proxy_host = machine_group.system.gateway_server_ip
    end
    key = machine_group.system.credentials.first.private_key
    entry_point = cloud_entry_point.entry_point
    Log.debug(Log.format_debug_param(ssh_host: host))
    Log.debug(Log.format_debug_param(ssh_proxy_host: proxy_host))
    params = {
      host: host,
      user: 'root',
      key: key,
      pass: nil,
      ssh_proxy: proxy_host,
      entry_point: entry_point,
      c_name: cloud_entry_point.infrastructure.name
    }
    Log.debug(Log.format_debug_param(params: params))
    ssh = SSHConnection.new(params)
    Log.debug(Log.format_debug_param(ssh: ssh))
    log_file = ConductorConfig.cloudinit_log_file
    if ssh.exec!("[ -e #{log_file} ]; echo -n $?").to_i != 0
      state = 'PENDING'
    elsif ssh.exec!("tail #{log_file} | grep -c -e '\\[.*\\] ERROR:'").to_i > 0
      state = 'ERROR'
    elsif ssh.exec!("tail #{log_file} | grep -c -e '\\[.*\\] INFO: Success to setup instance'").to_i == 1
      state = 'DONE'
    else
      if template_volumes && ssh.exec!("tail -n 2 #{log_file} | grep -c -e '\\[.*\\] INFO: Ready for attaching volumes.'").to_i == 1
        attach_volumes(template_volumes)
      end
      state = 'RUNNING'
    end
    update_attributes(state: state)
    state
  end

  def attach_volumes(template_volumes)
    Log.debug(Log.format_method_start(self.class, __method__))
    template_volumes.each do |template_volume|
      volume = Volume.create(
        name: template_volume[:id],
        mount_point: template_volume[:mount_point],
        capacity: template_volume[:size].to_i,
        system: machine_group.system,
        cloud_entry_point: cloud_entry_point,
        machine: self
      )
      volume.attach_volume(id)
    end
  end

  def build_hostname
    Log.debug(Log.format_method_start(self.class, __method__))
    max = -1
    machines = Machine.all

    # find max sequential number from machine record
    machines.each do |m|
      if m[:name] =~ /(.*?)-(\d+)$/ && host_name_base == Regexp.last_match[1]
        max = Regexp.last_match[2].to_i if max < Regexp.last_match[2].to_i
      end
    end

    hostname = sprintf('%s-001', host_name_base)
    hostname = sprintf('%s-%03d', host_name_base, max + 1) if max > 0

    # RFC952
    # TODO: Just throw exception? or chop off basename then create a short name?
    throw 'hostname length exceeded max 24 characters' if hostname.length > 24

    hostname
  end

  def admin_server?
    machine_group.role.attribute_id.downcase.include?('zabbix')
  end
end
