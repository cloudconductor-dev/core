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
describe System do
  after(:all) do
    System.delete_all
  end

  let(:system) { FactoryGirl.create(:system) }
  let(:cloud) { FactoryGirl.create(:aws) }

  describe 'on creating system' do
    context 'When success to create system' do
      it 'should store db and query by id' do
        find_system = System.find_by(id: system.id)
        expect(find_system).to be_valid
        expect(find_system).to eq(system)
      end
    end
  end

  describe 'on deploy system' do
    context 'When system have not persisted yet' do
      it 'should be occurrea raise error' do
        allow(system).to receive(:persisted?).and_return(false)
        expect { system.deploy }.to raise_error
      end
    end
  end

  describe 'on deleting machine config' do
    context 'When success to delete system' do
      it 'should delete from database using id' do
        id = system.id
        system.destroy
        system = System.find_by(id: id)
        expect(system).to be_nil
      end
    end
  end

  describe 'on get gateway_server_ip' do
    context 'When success to get gateway server ip' do
      it 'should get gateway server ip' do
        zabbix_machine_group = FactoryGirl.create(:machine_group, role: FactoryGirl.create(:zabbix_role))
        machine = FactoryGirl.create(:machine, machine_group: zabbix_machine_group)
        ip = machine.machine_group.system.gateway_server_ip
        expect(ip).to be
        expect(IPAddr.new(ip)).to be
      end
    end
    context 'When failed to get gateway server ip' do
      it 'should raise error' do
        expect { system.gateway_server_ip }.to raise_error
      end
    end
  end

  describe 'on get dns_server' do
    context 'When success to get dns server object' do
      it 'should get dns server object' do
        zabbix_machine_group = FactoryGirl.create(:machine_group, role: FactoryGirl.create(:zabbix_role))
        machine = FactoryGirl.create(:machine, machine_group: zabbix_machine_group)
        dns = machine.machine_group.system.dns_server
        expect(dns).to be
        expect(dns.class).to eq(Machine)
      end
    end
    context 'When failed to get dns server object' do
      it 'should raise error' do
        expect { system.dns_server }.to raise_error
      end
    end
  end
end
