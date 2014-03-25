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
describe ConductorConfig do
  before do
    ConductorConfig.reset
  end
  after(:all) do
    ConductorConfig.from_file(File.expand_path('spec/fixtures/conductor_config.rb'))
  end

  describe 'Conductor settings' do
    context 'When success to get configrations' do
      before do
        ConductorConfig.from_file(File.expand_path('spec/fixtures/conductor_config.rb'))
      end
      it 'should return config settings String' do
        expect(ConductorConfig.cloudinit_log_file).to eq('/tmp/cloudconductor-cloudinit.log')
        expect(ConductorConfig.log_dir).to eq('log')
        expect(ConductorConfig.log_file).to eq('conductor.log')
        expect(ConductorConfig.log_level).to eq(:error)
        expect(ConductorConfig.address_block).to eq('10.0.0.0/24')
        expect(ConductorConfig.subnet_address_block).to eq('10.0.0.0/24')
        expect(ConductorConfig.target_os_type).to eq('centos')
        expect(ConductorConfig.cloudinit_path.split('/')[-4..-1].join('/')).to eq('src/userdata/rhel/cloud_init.erb')
        expect(ConductorConfig.machine.create_timeout).to eq(30)
        expect(ConductorConfig.machine.cloudinit.check_interval).to eq(60)
        expect(ConductorConfig.machine.cloudinit.max_check_number).to eq(120)
        expect(ConductorConfig.deltacloud_host).to eq('127.0.0.1')
        expect(ConductorConfig.deltacloud_port).to eq(9292)
      end
    end
    context 'When deltacloud settings are not set' do
      it 'should raise error' do
        expect do
          ConductorConfig.from_file(File.expand_path('spec/fixtures/conductor_config_invalid_deltacloud_host.rb'))
        end.to raise_error(RuntimeError)
      end
    end
    context 'When missing target os type' do
      it 'should raise error' do
        expect do
          ConductorConfig.from_file(File.expand_path('spec/fixtures/conductor_config_invalid_os_type.rb'))
        end.to raise_error(RuntimeError)
      end
    end
    context 'When subnet_address_block 3rd octet is 255' do
      it 'should raise error' do
        expect do
          ConductorConfig.from_file(File.expand_path('spec/fixtures/conductor_config_invalid_subnet_address_block.rb'))
        end.to raise_error(RuntimeError)
      end
    end
  end
end
