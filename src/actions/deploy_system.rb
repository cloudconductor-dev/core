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
module Action
  def deploy_system(system_id)
    system = System.find_by(id: system_id)
    fail "System##{system_id} is not found in Action.deploy_system" unless system
    template = XmlParser.new(system.template_xml.force_encoding('UTF-8'))
    create_roles(system, template)
    create_credential(system, template)
    create_network_groups(system, template)
    create_networks(system, template)
    create_gateway(system, template)
    associate_all_networks_to_gateway(system)
    create_machine_filters(system, template)
    create_machine_filter_rules(system, template)
    create_machine_groups(system, template)
    system.machine_groups.order('priority DESC').each do |machine_group|
      launch_machines(system, machine_group, template)
    end
  end

  private

  def default_address_block
    ConductorConfig.address_block
  end

  def default_network_address
    ConductorConfig.subnet_address_block
  end

  # If default network address conflicts allocated network addresses,
  # count up the third octet of default network address.
  def allocate_network_address(cloud, network_group)
    allocated_net_addrs = cloud.external_net_addrs
    network_group.networks.each do |network|
      allocated_net_addrs << "#{network.network_address}\/#{network.prefix}"
    end
    net_addr = default_network_address
    while allocated_net_addrs.include?(net_addr)
      addr, prefix = net_addr.split('/')
      octet = addr.split('.')
      octet[2] = (octet[2].to_i + 1).to_s
      net_addr = "#{octet.join('.')}\/#{prefix}"
    end
    net_addr
  end

  def load_all_clouds(system, template)
    template.find('System')[:infrastructures].reduce([]) do |res, infra|
      cloud_param = JSON.parse(system.cloud_relation_parameters).select { |k, v| k == infra[:id] }
      res << CloudEntryPoint.find_by(id: cloud_param.values)
    end
  end

  def load_specify_cloud(system, infrastructure_id)
    cloud_param = JSON.parse(system.cloud_relation_parameters).select { |k, v| k == infrastructure_id }
    CloudEntryPoint.find_by(id: cloud_param.values)
  end

  def create_roles(system, template)
    openuri = ProxyauthOpenUri.new
    template.parse(template.doc.xpath('//cc:System/cc:Roles')).first.each do |r|
      run_list = load_file(system, r[:run_list])
      attribute = load_file(system, r[:parameters])
      role = system.roles.create(
        name: r[:name],
        setup_run_list: JSON.generate(run_list['setup']),
        deploy_run_list: JSON.generate(run_list['deploy']),
        setup_parameters: JSON.generate(attribute['setup']),
        deploy_parameters: JSON.generate(attribute['deploy']),
        attribute_id: r[:id],
      )
      r[:middlewares].each do |m|
        role.middlewares.create(
          name: m[:id],
          cookbook_name: m[:cookbook_name],
          repository: m[:repository],
        )
      end
    end
  end

  def load_file(system, url)
    unless url =~ URI.regexp
      url = "#{system.template_uri[0..system.template_uri.rindex('/')]}#{url}"
    end
    openuri = ProxyauthOpenUri.new
    JSON.parse(openuri.read_url(url))
  rescue
    Log.error(Log.format_error_params(
      self.class,
      __method__,
      url: url
    ))
    raise
  end

  def create_credential(system, template)
    clouds = load_all_clouds(system, template)
    clouds.each do |cloud|
      system.credentials.create(
        name: "cloudconductor_#{system.id}",
        cloud_entry_point: cloud,
      )
    end
  end

  def create_network_groups(system, template)
    clouds = load_all_clouds(system, template)
    clouds.each do |cloud|
      system.network_groups.create(
        name: "Network Group for #{system.name}",
        address_block: default_address_block, # FIXME
        cloud_entry_point: cloud,
      )
    end
  end

  def create_networks(system, template)
    template_network_groups = template.find('NetworkGroups')
    template_network_groups.each do |template_network_group|
      infrastructure_ids = template_network_group[:networks].map do |net|
        net[:infrastructures].map { |infra| infra[:id] }
      end.flatten
      infrastructure_ids.each do |infrastructure_id|
        cloud = load_specify_cloud(system, infrastructure_id)
        network_group = NetworkGroup.find_by(system: system, cloud_entry_point: cloud)
        cidr = allocate_network_address(cloud, network_group)
        net_addr, prefix = cidr.split('/')
        Network.create(
          name: template_network_group[:name],
          network_group: NetworkGroup.find_by(system: system, cloud_entry_point: cloud),
          network_address: net_addr,
          prefix: prefix
        )
      end
    end
  end

  def create_gateway(system, template)
    system.network_groups.map do |network_group|
      gateway = system.gateways.create(
        name: "Internet Gateway for #{system.name}",
        cloud_entry_point: network_group.cloud_entry_point,
      )
      gateway.attach(network_group.id)
    end
  end

  def associate_all_networks_to_gateway(system)
    system.gateways.each do |gateway|
      system.network_groups.each do |network_group|
        next unless network_group.cloud_entry_point == gateway.cloud_entry_point
        network_group.networks.each do |network|
          gateway.add_interface(network.id)
        end
      end
    end
  end

  def create_machine_groups(system, template)
    template_machine_groups = template.find('MachineGroups')
    template_machine_groups.each do |template_machine_group|
      common_machine_config = CommonMachineConfig.find_by(name: template_machine_group[:spec_type])
      common_machine_image = CommonMachineImage.find_by(os: template_machine_group[:os_type],
                                                        version: template_machine_group[:os_version])
      machine_filter_group = MachineFilterGroup.find_by(name: template_machine_group[:id], system: system)
      template_role = template_machine_group[:roles].first
      role = Role.find_by(
        attribute_id: template_role[:id],
        system: system,
      )
      priority = template_machine_group[:name].downcase.include?('zabbix') ? 20 : 10
      system.machine_groups.create(
        name: template_machine_group[:name],
        common_machine_config: common_machine_config,
        common_machine_image: common_machine_image,
        machine_filter_group: machine_filter_group,
        min_size: template_machine_group[:min_size],
        max_size: template_machine_group[:max_size],
        node_type: template_machine_group[:node_type][:name],
        role: role,
        user_parameters: JSON.generate(build_user_parameters(system, template_machine_group)),
        priority: priority
      )
    end
  end

  def build_user_parameters(system, template_machine_group)
    # Build Rule :
    #   system.user_parameters is expected valid JSON and its first key has only two pattern
    #     1. machine_groups : MachineGroup's user_input_key in XML
    #     2. roles : Role's user_input_key in XML
    #   second key separates '.'
    #     1. machine_groups : (machine_group id in XML).(user_input_key)
    #     2. roles : (role id in XML).(user_input_key)
    #   attention : we expect only one role in template_machine_group
    user_input_keys = JSON.parse(system.user_parameters)
    a_to_h = proc do |array, hash|
      key = array.shift
      key.nil? ? hash : a_to_h.call(array, key => hash)
    end
    params = {}
    user_input_keys['roles'].each do |k, v|
      keys = k.split('.')
      next unless keys.first == template_machine_group[:roles].first[:id]
      last = { keys.last => v }
      params.deep_merge!(a_to_h.call(keys[1..-2].reverse, last))
    end unless user_input_keys['roles'].nil?
    user_input_keys['machine_groups'].each do |k, v|
      keys = k.split('.')
      next unless keys.first == template_machine_group[:id]
      last = { keys.last => v }
      params.deep_merge!(a_to_h.call(keys[1..-2].reverse, last))
    end unless user_input_keys['machine_groups'].nil?
    params
  end

  def launch_machines(system, machine_group, template)
    template_machine_group = template.list('MachineGroup').find { |grp| grp[:name] == machine_group.name }
    clouds = template_machine_group[:infrastructures].map { |infra| load_specify_cloud(system, infra[:id]) }
    network_name = template_machine_group[:network_interfaces].first[:name]
    machine_group.min_size.times do |i|
      cloud = clouds[i % clouds.length]
      machine_config = MachineConfig.where(
        cloud_entry_point: cloud,
        common_machine_config: machine_group.common_machine_config
      ).first_or_create
      machine_image = MachineImage.where(
        cloud_entry_point: cloud,
        common_machine_image: machine_group.common_machine_image
      ).first_or_create
      network_group = NetworkGroup.find_by(system: machine_group.system, cloud_entry_point: cloud)
      host_name_base = template_machine_group[:id]
      machine = machine_group.machines.create(
        machine_name: machine_group.name + (i + 1).to_s,
        host_name_base: host_name_base,
        cloud_entry_point: cloud,
        machine_config: machine_config,
        machine_image: machine_image,
        attach_network: Network.find_by(network_group: network_group, name: network_name)
      )
      create_interfaces(machine, template)
      associate_floating_ip(machine) unless template_machine_group[:floating_ip].nil?
      machine.wait_serial(template)
    end
  end

  def create_interfaces(machine, template)
    # Add other NetworkInterfaces
    template_network_interfaces = template.list('MachineGroup').find { |grp| grp[:name] == machine.machine_group.name }[:network_interfaces]
    other_interfaces = template_network_interfaces[1..-1] || []
    other_interfaces.each do |template_other_interface|
      network = Network.find_by(cloud_entry_point: machine.cloud_entry_point, name: template_other_interface[:name])
      network_interface = NetworkInterface.create(
        machine: machine,
        network: network,
      )
    end
  end

  def associate_floating_ip(machine)
    floating_ip = FloatingIp.create(
      system: machine.machine_group.system,
      cloud_entry_point: machine.cloud_entry_point,
    )
    floating_ip.associate(machine.id)
  end

  def create_machine_filters(system, template)
    clouds = load_all_clouds(system, template)
    template.list('MachineGroups').first.map do |template_machine_group|
      # create machine_filter_group
      machine_filter_group = MachineFilterGroup.create(
        name: template_machine_group[:id],
        description: "This is #{template_machine_group[:name]} filter", # FIXME
        system: system
      )
      # create machine_filter
      clouds.each do |cloud|
        MachineFilter.create(
          machine_filter_group: machine_filter_group,
          cloud_entry_point: cloud
        )
      end
    end
  end

  def create_machine_filter_rules(system, template)
    # create machine_filter_rule_groups
    template.list('MachineGroups').first.each do |template_machine|
      machine_filter_group = MachineFilterGroup.find_by(system: system, name: template_machine[:id])
      template_machine_filters = template_machine[:machine_filters] || []
      template_machine_filters.each do |template_machine_filter|
        prms = {
          direction: template_machine_filter[:direction],
          protocol: template_machine_filter[:protocol],
          action: template_machine_filter[:rule_action],
          machine_filter_group: machine_filter_group
        }
        if template_machine_filter.key?(:port)
          add_port(prms, template_machine_filter[:port])
        end
        if template_machine_filter.key?(:ethertype)
          prms.store(:ethertype, template_machine_filter[:ethertype])
        else
          prms.store(:ethertype, 'IPv4')
        end
        if template_machine_filter.key?(:source) && template_machine_filter[:source].kind_of?(Hash)
          create_machine_filter_rules_from_network_group(system, template_machine_filter, prms)
        else
          create_machine_filter_rule_from_ip_address(template_machine_filter, prms)
        end
      end
    end
    # create machine_filter_rules
    machine_filter_groups = MachineFilterGroup.where(system: system)
    machine_filter_groups.each do |machine_filter_group|
      machine_filter_group.machine_filters.each do |machine_filter|
        machine_filter_group.machine_filter_rule_groups.each do |machine_filter_rule_group|
          MachineFilterRule.create(
            machine_filter: machine_filter,
            machine_filter_rule_group: machine_filter_rule_group
          )
        end
      end
    end
  end
  # create a machine filter that sourced from ip addresses
  def create_machine_filter_rule_from_ip_address(template_machine_filter, prms)
    remote_ip_address = template_machine_filter[:source] if template_machine_filter[:source]
    remote_ip_address = template_machine_filter[:destination] if template_machine_filter[:destination]
    prms.store(:remote_ip_address, remote_ip_address == 'all' ? '0.0.0.0/0' : remote_ip_address)
    MachineFilterRuleGroup.create(prms)
  end
  # create a machine filter that sourced from a network group
  def create_machine_filter_rules_from_network_group(system, template_machine_filter, prms)
    network_groups = NetworkGroup.where(system: system)
    networks = network_groups.map do |network_group|
      Network.find_by(network_group: network_group, name: template_machine_filter[:source][:name])
    end
    networks.each do |network|
      prms.store(:remote_ip_address, "#{network[:network_address]}/#{network[:prefix]}")
      MachineFilterRuleGroup.create(prms)
    end
  end

  def add_port(prms, str)
    if prms[:protocol] == 'tcp' || prms[:protocol] == 'udp'
      case str
      when 'all' then h = { port_range_min: 0, port_range_max: 65_535 }
      else h = { port_range_min: str, port_range_max: str }
      end
    elsif prms[:protocol] == 'icmp'
      case str
      when 'all' then h = { port_range_min: 0, port_range_max: 255 }
      else h = { port_range_min: str, port_range_max: str }
      end
    end
    prms.merge!(port_range_min: h[:port_range_min], port_range_max: h[:port_range_max])
  end
end
