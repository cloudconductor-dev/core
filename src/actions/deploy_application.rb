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
  def deploy_application(application)
    @application = application
    Log.debug(Log.format_method_start(self.class, __method__))
    Log.debug(Log.format_debug_param(attributes: @application.attributes))
    web_file = @application.application_files.find { |file| file.machine_group.role.type == 'web' }
    ap_file = @application.application_files.find { |file| file.machine_group.role.type == 'ap' }
    db_file = @application.application_files.find { |file| file.machine_group.role.type == 'db' }
    Log.debug(Log.format_debug_param(web_file: web_file))
    Log.debug(Log.format_debug_param(ap_file: ap_file))
    Log.debug(Log.format_debug_param(db_file: db_file))
    passwd = application_database_password
    @application.system.machine_groups.each do |machine_group|
      Log.debug(Log.format_debug_param(machine_group_role_deploy_parameters: machine_group.role.deploy_parameters))
      deploy_json = deploy_attributes(passwd).deep_merge(
        JSON.parse(machine_group.role.deploy_parameters, symbolize_names: true)
      )
      deploy_json.deep_merge!(run_list: JSON.parse(machine_group.role.deploy_run_list, symbolize_names: true))
      machine_group.machines.each do |machine|
        begin
          hostname = machine.name
          Log.debug(Log.format_debug_param(ssh_hostname: hostname))
          credential = Credential.find_by(system: @application.system, cloud_entry_point: machine.cloud_entry_point)
          Log.debug(Log.format_debug_param(use_crednetial_name: credential.name))
          gateway_server_ip = @application.system.gateway_server_ip
          Log.debug(Log.format_debug_param(ssh_gateway_server_ip: gateway_server_ip))
          entry_point = machine.cloud_entry_point.entry_point
          params = {
            host: hostname,
            user: 'root',
            key: credential.private_key,
            pass: nil,
            ssh_proxy: gateway_server_ip,
            entry_point: entry_point,
            c_name: machine.cloud_entry_point.infrastructure.name
          }
          ssh = SSHConnection.new(params)
          Log.debug(' ----- Start SCP command !! ----- ')
          Log.debug(Log.format_debug_param(machine_group_role_type: machine_group.role.type))
          ssh.scp(ap_file.path, "/tmp/#{@application.name}-#{ap_file.name}") if ap_file && machine_group.role.type == 'ap'
          ssh.scp(db_file.path, "/tmp/#{@application.name}-#{db_file.name}") if db_file && machine_group.role.type == 'db'
          c_list = JSON.generate(deploy_json)
          Log.debug(Log.format_debug_param(c_list: c_list))
          ssh.run_chef_solo(c_list)
        rescue
          if credential
            error_credential = credential.attributes
            error_credential['private_key'] = '****'
          end
          Log.error(Log.format_error_params(
            self.class,
            __method__,
            attributes: @application.attributes,
            web_file: web_file,
            ap_file: ap_file,
            db_file: db_file,
            deploy_json: deploy_json,
            hostname: hostname,
            using_credential: error_credential
          ))
          raise
        end
      end
    end
    Log.debug("application [#{@application.name}] deploy end")
  end

  private

  def deploy_attributes(passwd)
    web_file = @application.application_files.find { |file| file.machine_group.role.type == 'web' }
    ap_file = @application.application_files.find { |file| file.machine_group.role.type == 'ap' }
    db_file = @application.application_files.find { |file| file.machine_group.role.type == 'db' }
    ap_machine_groups = @application.system.machine_groups.select { |mg| mg.role.type == 'ap' }
    db_machine_groups = @application.system.machine_groups.select { |mg| mg.role.type == 'db' }
    {
      :'cc-deploy' => {
        applications: [{
          name: @application.name,
          source_path: ap_file ? "/tmp/#{@application.name}-#{ap_file.name}" : nil
        }],
        database: {
          dbname: @application.name,
          username: @application.name,
          password: passwd,
          source_path: db_file ? "/tmp/#{@application.name}-#{db_file.name}" : nil
        },
        application_servers: ap_machine_groups && ap_machine_groups.map do |ap_machine_group|
          ap_machine_group.machines.map do |machine|
            { host: machine.name }
          end
        end.flatten,
        database_servers: db_machine_groups && db_machine_groups.map do |db_machine_group|
          db_machine_group.machines.map do |machine|
            { host: machine.name }
          end
        end.flatten
      }
    }
  end

  def application_database_password(length = 16)
    [*0..9, *'a'..'z', *'A'..'Z'].sample(length).join
  end
end
