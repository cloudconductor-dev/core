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
describe Machine do
  before(:all) do
    cloud = FactoryGirl.create(:aws)
    key = URI.encode_www_form_component(cloud.key)
    secret = URI.encode_www_form_component(cloud.secret)
    @deltacloud_url = "http://#{key}:#{secret}@#{ConductorConfig.deltacloud_host}:#{ConductorConfig.deltacloud_port}/api"
    machine_group = FactoryGirl.create(:machine_group)
    machine_filter = FactoryGirl.create(:machine_filter, machine_filter_group: machine_group.machine_filter_group, cloud_entry_point: cloud)
    credential = FactoryGirl.create(:aws_key, cloud_entry_point: cloud, system: machine_group.system)
    xml_uri = machine_group.system.template_uri
    @url = xml_uri[0..xml_uri.rindex('/')]
    @params = {
      machine_name: 'machine name',
      host_name_base: 'hostname',
      cloud_entry_point: cloud,
      ref_id: 'uuid',
      machine_image: FactoryGirl.create(:aws_centos),
      machine_config: FactoryGirl.create(:aws_m1_small),
      machine_group: machine_group,
      attach_network: FactoryGirl.create(:network)
    }
    # zabbix server (proxy host)
    zabbix_role = FactoryGirl.create(:zabbix_role)
    zabbix_group = FactoryGirl.create(:machine_group,
                                      name: 'Zabbix Server',
                                      system: machine_group.system,
                                      role: zabbix_role)
    ip = FactoryGirl.create(:floating_ip, ip_address: '123.456.789.012')
    FactoryGirl.create(:machine, machine_group: zabbix_group, state: 'BUILDING', floating_ips: [ip])
  end

  let(:machine) do
    response_post_instance = <<-'EOS'
      {"instance":{
        "id":"0e4ae618-34d7-410a-b131-0fe57310535f",
        "href":"http://localhost:9292/api/instances/0e4ae618-34d7-410a-b131-0fe57310535f",
        "name":"machine name",
        "state":"PENDING",
        "owner":"demo",
        "image":{
          "href":"http://localhost:9292/api/images/ec4eff4b-06e1-4e04-8cbb-b68450cd9289",
          "id":"ec4eff4b-06e1-4e04-8cbb-b68450cd9289",
          "rel":"image"
        },
        "realm":{
          "href":"http://localhost:9292/api/realms/default",
          "id":"default",
          "rel":"realm"
        },
        "actions":[],
        "hardware_profile":{
          "id":"1",
          "href":"http://localhost:9292/api/hardware_profiles/1",
          "rel":"hardware_profile",
          "properties":{}
        },
        "public_addresses":[],
        "private_addresses":[],
        "create_time":"2013-11-01T00:50:14Z",
        "storage_volumes":[],
        "authentication_type":"key",
        "authentication":{
          "keyname":"credential-name",
          "user":"root",
          "password":"k6GZY9viJCby"
        }
      }}
    EOS
    response_get_instance = <<-'EOS'
      {"instance": {
        "id": "0e4ae618-34d7-410a-b131-0fe57310535f",
        "state": "RUNNING"
      }}
    EOS
    response_get_network_interfaces = <<-'EOS'
      {"network_interfaces": [
        {
          "instance": {"id": "0e4ae618-34d7-410a-b131-0fe57310535f"},
          "id": "uuid",
          "ip_address": "10.0.0.1"
        }
      ]}
    EOS
    WebMock.stub_request(:post, %r(#{@deltacloud_url}/instances))
      .to_return(status: 201, body: response_post_instance)
    WebMock.stub_request(:get, %r(#{@deltacloud_url}/instances/.*))
      .to_return(status: 200, body: response_get_instance)
    WebMock.stub_request(:get, %r(#{@deltacloud_url}/network_interfaces))
      .to_return(status: 200, body: response_get_network_interfaces)
    machine = Machine.create(@params)
  end

  before(:each) do
    response_cookbooks_in_run_list = <<-'EOS'
      {"run_list": [
        "recipe[apache2]"
      ]}
    EOS
    allow(ProxyauthOpenUri).to receive(:new).and_return(double('mock', read_url: response_cookbooks_in_run_list))
  end

  describe 'on self.create' do
    context 'When DeltaCloud server returns 201 Created' do
      it 'should store parameters and return Machine object' do
        expect(machine.ref_id).to eq('0e4ae618-34d7-410a-b131-0fe57310535f')
        expect(machine.machine_name).to eq(@params[:machine_name])
        expect(machine.name).to eq(@params[:host_name_base] + '-001')
        expect(machine.state).to eq('RUNNING')
      end
    end

    context 'When DeltaCloud server returns 500 Internal Server Error' do
      before do
        WebMock.stub_request(:post, %r(#{@deltacloud_url}/instances))
          .to_return(status: 500)
      end
      it 'should raise RuntimeError' do
        expect do
          Machine.create(@params)
        end.to raise_error(RuntimeError, '500 Internal Server Error')
      end
    end

    context 'When occurred exception in build_userdata' do
      it 'should raise RuntimeError' do
        machine = FactoryGirl.build_stubbed(:machine)
        allow(machine).to receive(:build_hostname).and_raise
        expect do
          machine.send(:build_userdata)
        end.to raise_error(RuntimeError)
      end
    end
  end

  describe 'on latest_state' do
    context 'When DeltaCloud server returns 200' do
      it 'should be getting latest machine state' do
        latest_state = machine.send(:latest_state)
        expect(latest_state).to be
        expect(latest_state).to eq('RUNNING')
      end
    end
    context 'When DeltaCloud server returns 500 error' do
      before do
        WebMock.stub_request(:get, %r(#{@deltacloud_url}/instances/.*))
          .to_return(status: 500)
      end
      it 'should raise execption' do
        machine = FactoryGirl.build_stubbed(:machine)
        expect { machine.send(:latest_state) }.to raise_error
      end
    end
  end

  describe 'on wait_serial' do
    context 'When machine state change to DONE and through wait_serial' do
      it 'should be nothing to do' do
        allow(machine).to receive(:state_check).and_return('DONE')
        result = machine.send(:wait_serial)
        expect(result).to be_nil
      end
    end
    context 'When raise unexpected execption in check state' do
      it 'should raise exception' do
        allow(machine).to receive(:state_check).and_raise(RuntimeError)
        expect { machine.send(:wait_serial) }.to raise_error(RuntimeError)
      end
    end
    context 'When return unexpected state in check state' do
      it 'should raise exception' do
        allow(machine).to receive(:state_check).and_return('UNKNOWN_STATE')
        expect { machine.send(:wait_serial) }.to raise_error(RuntimeError)
      end
    end
  end

  describe 'on #destroy' do
    context 'When DeltaCloud Server returns 404 Resource Not Found' do
      before do
        WebMock.stub_request(:delete, %r(#{@deltacloud_url}/network_interfaces/.*))
          .to_return(status: 404)
      end
      it 'should raise RuntimeError' do
        id = machine.id
        expect { machine.destroy }.to raise_error(RuntimeError, '404 Resource Not Found')
        expect(Machine.find_by(id: id)).to be
      end
    end

    context 'When DeltaCloud Server returns 204 No Content' do
      before do
        WebMock.stub_request(:delete, %r(#{@deltacloud_url}/instances/#{machine.ref_id}))
          .to_return(status: 204)
        WebMock.stub_request(:delete, %r(#{@deltacloud_url}/network_interfaces/.*))
          .to_return(status: 204)
      end
      it 'should delete record and return true' do
        id = machine.id
        result = machine.destroy
        expect(Machine.find_by(id: id)).to be_nil
        expect(result).to be_true
      end
    end
  end

  describe 'machine.to_h check' do
    context 'When state_check return' do
      before(:all) do
        @system1 =  FactoryGirl.create(
          :system,
          name: 'system1',
          description: 'System number 1'
        )
        @cloudentrypoint1 = FactoryGirl.create(:aws)
        @credentialkey1 = FactoryGirl.create(
          :aws_key,
          name: "key_#{@system1.id}",
          cloud_entry_point_id: @cloudentrypoint1.id,
          system: @system1
        )
        @machinegroup1 = FactoryGirl.create(
          :machine_group,
          name: "Web_#{@system1.id}",
          max_size: 3,
          system: @system1
        )
        @machinegroup2 = FactoryGirl.create(
          :machine_group,
          name: "Zabbix_#{@system1.id}",
          role: FactoryGirl.create(:zabbix_role),
          system: @system1
        )
        @machine1 = FactoryGirl.create(
          :machine,
          name: "web_server_#{@system1.id}",
          machine_group_id: @machinegroup1.id,
          cloud_entry_point_id: @cloudentrypoint1.id,
          state: 'BUILDING'
        )
        @machine2 = FactoryGirl.create(
          :machine,
          name: "zabbix_server_#{@system1.id}",
          machine_group_id: @machinegroup2.id,
          cloud_entry_point_id: @cloudentrypoint1.id,
          state: 'BUILDING'
        )
      end
      after do
      end
      it 'machine to_h state is PENDING' do
        machine_groups = @system1.machine_groups
        machines = machine_groups ? machine_groups.reduce([]) { |array, group| array + group.machines } : []
        ssh_mock = double('ssh-mock')
        allow(SSHConnection).to receive(:new).and_return(ssh_mock)
        log_file = '/tmp/cloudconductor-cloudinit.log'
        allow(ssh_mock).to receive(:exec!).with("[ -e #{log_file} ]; echo -n $?").and_return('1')
        machines.map do |machine|
          response = machine.to_h
          expect(response[:status]).to eq('PENDING')
          expect(Machine.find_by_id(response[:id]).state).to eq('PENDING')
        end
      end
      it 'machine to_h state is RUNNING' do
        machine_groups = @system1.machine_groups
        machines = machine_groups ? machine_groups.reduce([]) { |array, group| array + group.machines } : []
        ssh_mock = double('ssh-mock')
        allow(SSHConnection).to receive(:new).and_return(ssh_mock)
        log_file = '/tmp/cloudconductor-cloudinit.log'
        allow(ssh_mock).to receive(:exec!).with("[ -e #{log_file} ]; echo -n $?").and_return('0')
        allow(ssh_mock).to receive(:exec!).with("tail #{log_file} | grep -c -e '\\[.*\\] ERROR:'").and_return('0')
        allow(ssh_mock).to receive(:exec!).with("tail #{log_file} | grep -c -e '\\[.*\\] INFO: Success to setup instance'").and_return('0')
        machines.map do |machine|
          response = machine.to_h
          expect(response[:status]).to eq('RUNNING')
          expect(Machine.find_by_id(response[:id]).state).to eq('RUNNING')
        end
      end
      it 'machine to_h state is ERROR' do
        machine_groups = @system1.machine_groups
        machines = machine_groups ? machine_groups.reduce([]) { |array, group| array + group.machines } : []
        ssh_mock = double('ssh-mock')
        allow(SSHConnection).to receive(:new).and_return(ssh_mock)
        log_file = '/tmp/cloudconductor-cloudinit.log'
        allow(ssh_mock).to receive(:exec!).with("[ -e #{log_file} ]; echo -n $?").and_return('0')
        allow(ssh_mock).to receive(:exec!).with("tail #{log_file} | grep -c -e '\\[.*\\] ERROR:'").and_return('1')
        machines.map do |machine|
          response = machine.to_h
          expect(response[:status]).to eq('ERROR')
          expect(Machine.find_by_id(response[:id]).state).to eq('ERROR')
        end
      end
      it 'machine to_h state is DONE' do
        machine_groups = @system1.machine_groups
        machines = machine_groups ? machine_groups.reduce([]) { |array, group| array + group.machines } : []
        ssh_mock = double('ssh-mock')
        allow(SSHConnection).to receive(:new).and_return(ssh_mock)
        log_file = '/tmp/cloudconductor-cloudinit.log'
        allow(ssh_mock).to receive(:exec!).with("[ -e #{log_file} ]; echo -n $?").and_return('0')
        allow(ssh_mock).to receive(:exec!).with("tail #{log_file} | grep -c -e '\\[.*\\] ERROR:'").and_return('0')
        allow(ssh_mock).to receive(:exec!).with("tail #{log_file} | grep -c -e '\\[.*\\] INFO: Success to setup instance'").and_return('1')
        machines.map do |machine|
          response = machine.to_h
          expect(response[:status]).to eq('DONE')
          expect(Machine.find_by_id(response[:id]).state).to eq('DONE')
        end
      end
    end
  end
  describe 'on store_network_interfaces' do
    context 'When DeltaCloud Server returns 500' do
      before do
        WebMock.stub_request(:get, %r(#{@deltacloud_url}/network_interfaces/.*))
          .to_return(status: 500)
      end
      it 'should raise exception' do
        machine = FactoryGirl.build_stubbed(:machine)
        expect { machine.send(:store_network_interfaces) }.to raise_error
      end
    end
  end

  describe 'on build_server_parameters' do
    before do
      response_zabbix_template = <<-'EOS'
<zabbix_export>
    <version>2.0</version>
    <date>2014-02-21T05:35:39Z</date>
    <groups>
        <group>
            <name>Templates</name>
        </group>
    </groups>
    <templates>
        <template>
            <template>Conductor Monitoring for OS Linux</template>
            <name>Conductor Monitoring for OS Linux</name>
        </template>
    </templates>
</zabbix_export>
EOS
      allow(ProxyauthOpenUri).to receive(:new).and_return(double('mock', read_url: response_zabbix_template))
    end
    context 'When CloudEntryPoint.proxy_url no exist' do
      it 'should not exist squid params' do
        network_group = FactoryGirl.create(:network_group)
        machine_group = FactoryGirl.create(:machine_group, system: network_group.system)
        machine = FactoryGirl.create(:machine, machine_group: machine_group, cloud_entry_point: network_group.cloud_entry_point)
        template_xml = XmlParser.new(machine.machine_group.system.template_xml)
        server_param = machine.send(:build_server_parameters, template_xml, machine.name)
        expect(server_param[:zabbix][:hosts]).to be_instance_of(Array)
        expect(server_param[:zabbix][:hosts].first[:templates].size).to be > 0
        expect(server_param[:zabbix][:import_files].first[:current_template_name]).to eq('Conductor Monitoring for OS Linux')
        expect(server_param[:zabbix][:agent]).to be
        expect(server_param[:'cc-bind'][:network]).to eq(network_group.address_block)
        expect(server_param[:net]).to be
        expect(server_param[:squid]).to be_nil
      end
    end
    context 'When CloudEntryPoint.proxy_url exist' do
      it 'should exist squid params' do
        openstack = FactoryGirl.create(:openstack)
        network_group = FactoryGirl.create(:network_group, cloud_entry_point: openstack)
        machine_group = FactoryGirl.create(:machine_group, system: network_group.system)
        machine = FactoryGirl.create(:machine, machine_group: machine_group, cloud_entry_point: openstack, cloud_entry_point: network_group.cloud_entry_point)
        template_xml = XmlParser.new(machine.machine_group.system.template_xml)
        server_param = machine.send(:build_server_parameters, template_xml, machine.name)
        expect(server_param[:zabbix][:hosts]).to be_instance_of(Array)
        expect(server_param[:zabbix][:hosts].first[:templates].size).to be > 0
        expect(server_param[:zabbix][:import_files].first[:current_template_name]).to eq('Conductor Monitoring for OS Linux')
        expect(server_param[:zabbix][:agent]).to be
        expect(server_param[:net]).to be
        expect(server_param[:'cc-bind'][:network]).to eq(network_group.address_block)
        expect(server_param[:squid]).to be
      end
    end
  end

  describe 'on admin_server?' do
    context 'When this server is admin server' do
      before do
        @machine = FactoryGirl.build_stubbed(
          :machine,
          machine_group: FactoryGirl.build_stubbed(:machine_group, role: FactoryGirl.build_stubbed(:zabbix_role))
        )
      end
      it 'should return true' do
        expect(@machine.send(:admin_server?)).to be_true
      end
    end
    context 'When this server is NOT admin server' do
      it 'should return false' do
        expect(machine.send(:admin_server?)).to be_false
      end
    end
  end
end
