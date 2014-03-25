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
describe Action do
  include Action

  before(:all) do
    @system = System.create(
      name: 'my-system ' + Date.today.strftime('%Y/%m/%d'),
      template_xml: '<root/>',
    )
  end

  after(:all) do
    @system.destroy
  end

  describe '#depley_application' do
    before do
      zabbix_machine_group = FactoryGirl.create(:machine_group, role: FactoryGirl.create(:zabbix_role))
      machine = FactoryGirl.create(:machine, machine_group: zabbix_machine_group)
      @application = FactoryGirl.create(:application, system: machine.machine_group.system)
      @ap_group = FactoryGirl.create(:machine_group, role: FactoryGirl.create(:ap_role))
      @db_group = FactoryGirl.create(:machine_group, role: FactoryGirl.create(:db_role))
      @ap_file = FactoryGirl.create(:application_file, application: @application, machine_group: @ap_group)
      @db_file = FactoryGirl.create(:application_file, application: @application, machine_group: @db_group)
      FactoryGirl.create(:openstack_key, system: machine.machine_group.system, cloud_entry_point: machine.cloud_entry_point)
    end
    it 'should execute scp when machine role type is ap' do
      ssh_mock = double('ssh_mock')
      allow(ssh_mock).to receive(:scp)
      allow(ssh_mock).to receive(:run_chef_solo)
      allow(SSHConnection).to receive(:new).and_return(ssh_mock)
      deploy_application(@application)
      expect(ssh_mock).to receive(:scp).with(@ap_file.path, "/tmp/#{@application.name}-#{@ap_file.name}").exactly(@ap_group.machines.size).times
      expect(ssh_mock).to receive(:scp).with(@db_file.path, "/tmp/#{@application.name}-#{@db_file.name}").exactly(@db_group.machines.size).times
    end

    it 'should raise Runtime exception when deploy is failed' do
      allow(Credential).to receive(:find_by).and_raise
      expect { deploy_application(@application) }.to raise_error(RuntimeError)
    end
  end

  describe '#deploy_attributes' do
    before do
      @application = FactoryGirl.create(:application)
      @ap_group = FactoryGirl.create(:machine_group, role: FactoryGirl.create(:ap_role))
      @db_group = FactoryGirl.create(:machine_group, role: FactoryGirl.create(:db_role))
      @ap_file = FactoryGirl.create(:application_file, application: @application, machine_group: @ap_group)
      @db_file = FactoryGirl.create(:application_file, application: @application, machine_group: @db_group)
      FactoryGirl.create(:machine, machine_group: @ap_group)
      FactoryGirl.create(:machine, machine_group: @db_group)
    end
    it 'should return Hash which include required keys with ap/db file' do
      result = send(:deploy_attributes, 'password111')
      expect(result).to be_key(:'cc-deploy')
      expect(result[:'cc-deploy']).to be_key(:applications)
      expect(result[:'cc-deploy']).to be_key(:database)
      expect(result[:'cc-deploy'][:applications]).to be_instance_of(Array)
      expect(result[:'cc-deploy'][:application_servers]).to be_instance_of(Array)
      expect(result[:'cc-deploy'][:database_servers]).to be_instance_of(Array)
      expect(result[:'cc-deploy'][:database][:password]).to eq('password111')
    end
    it 'should return Hash which include required keys with only ap file' do
      @ap_file = nil
      result = send(:deploy_attributes, 'password111')
      expect(result).to be_key(:'cc-deploy')
      expect(result[:'cc-deploy']).to be_key(:applications)
      expect(result[:'cc-deploy']).to be_key(:database)
      expect(result[:'cc-deploy'][:applications]).to be_instance_of(Array)
      expect(result[:'cc-deploy'][:application_servers]).to be_instance_of(Array)
      expect(result[:'cc-deploy'][:database_servers]).to be_instance_of(Array)
      expect(result[:'cc-deploy'][:database][:password]).to eq('password111')
    end
    it 'should return Hash which include required keys with only db file' do
      @db_file = nil
      result = send(:deploy_attributes, 'password111')
      expect(result).to be_key(:'cc-deploy')
      expect(result[:'cc-deploy']).to be_key(:applications)
      expect(result[:'cc-deploy']).to be_key(:database)
      expect(result[:'cc-deploy'][:applications]).to be_instance_of(Array)
      expect(result[:'cc-deploy'][:application_servers]).to be_instance_of(Array)
      expect(result[:'cc-deploy'][:database_servers]).to be_instance_of(Array)
      expect(result[:'cc-deploy'][:database][:password]).to eq('password111')
    end
  end
end
