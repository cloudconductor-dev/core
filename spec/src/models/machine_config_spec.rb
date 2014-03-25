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
describe MachineConfig do
  before(:all) do
    @cloud = FactoryGirl.create(:openstack)
    key = URI.encode_www_form_component(@cloud.key)
    secret = URI.encode_www_form_component(@cloud.secret)
    @deltacloud_url = "http://#{key}:#{secret}@#{ConductorConfig.deltacloud_host}:#{ConductorConfig.deltacloud_port}/api"
    @common_machine_config = FactoryGirl.create(:small)
    @params = {
      cloud_entry_point_id: @cloud.id,
      common_machine_config_id: @common_machine_config.id,
    }
    @hardware_profiles = [
      {
        id: 't1.micro',
        href: 'http://localhost:9292/api/hardware_profiles/t1.micro',
        name: 't1.micro',
        properties: { cpu: '1', memory: '613', storage: '160', architecture: 'i386', root_type: 'persistent' }
      },
      {
        id: 'm1.small',
        href: 'http://localhost:9292/api/hardware_profiles/m1.small',
        name: 'm1.small',
        properties: { cpu: '1', memory: '1740.8', storage: '160', architecture: 'i386' }
      },
      {
        id: 'm1.medium',
        href: 'http://localhost:9292/api/hardware_profiles/m1.medium',
        name: 'm1.medium',
        properties: { cpu: '2', memory: '3840.0', storage: '410', architecture: 'i386' }
      },
    ]
  end
  after(:all) do
    @common_machine_config.destroy
    @cloud.destroy
  end

  describe 'on self.create' do
    before do
      mock_response = JSON.generate(hardware_profiles: @hardware_profiles)
      WebMock.stub_request(:get, /#{@deltacloud_url}\/hardware_profiles/)
        .to_return(status: 200, body: mock_response)
    end

    context 'When required machine config found on cloud' do
      it 'should store parameters and return MachineConfig object' do
        hardware_profile = @hardware_profiles.find { |profile| profile[:name] == 'm1.small' }
        config = MachineConfig.create(@params)
        expect(MachineConfig.find_by(@params)).to be_instance_of(MachineConfig)
        expect(config.ref_id).to eq(hardware_profile[:id])
        expect(config.cpu).to eq(hardware_profile[:properties][:cpu].to_i)
        expect(config.memory).to eq(hardware_profile[:properties][:memory].to_i)
      end
    end

    context 'When required machine config already exists in database' do
      before do
        @stored_config =  MachineConfig.where(@params).first_or_create
      end
      it 'should return stored MachineConfig object' do
        config = MachineConfig.where(@params).first_or_create
        expect(config.id).to eq(@stored_config.id)
      end
    end

    context 'When there is not hardware profile which satisfy required resources' do
      before do
        @over_spec_config = CommonMachineConfig.create(
          name: 'TSUBAME 2.5',
          min_cpu: 2_816,
          min_memory: 80_000_000,
        )
      end
      it 'should raise RuntimeError' do
        expect do
          MachineConfig.create(
            cloud_entry_point_id: @params[:cloud_entry_point_id],
            common_machine_config_id: @over_spec_config.id,
          )
        end.to raise_error(RuntimeError, 'Not found machine config to satisfy requirements.')
      end
      after do
        @over_spec_config.destroy
      end
    end

    context 'When there is not available hardware profile' do
      before do
        mock_response = JSON.generate(hardware_profiles: [])
        WebMock.stub_request(:get, /#{@deltacloud_url}\/hardware_profiles/)
          .to_return(status: 200, body: mock_response)
      end
      it 'should raise RuntimeError' do
        expect do
          MachineConfig.create(@params)
        end.to raise_error(RuntimeError, 'Not found machine config to satisfy requirements.')
      end
    end

    context 'When DeltaCloud server returns 500 Internal Server Error' do
      before do
        mock_response = 'Error: Unexpected message'
        WebMock.stub_request(:get, /#{@deltacloud_url}\/hardware_profiles/)
          .to_return(status: 500, body: mock_response)
      end
      it 'should raise RuntimeError' do
        expect do
          MachineConfig.create(@params)
        end.to raise_error(RuntimeError, '500 Internal Server Error')
      end
    end
  end

  describe 'on #destroy' do
    before do
      mock_response = JSON.generate(hardware_profiles: @hardware_profiles)
      WebMock.stub_request(:get, /#{@deltacloud_url}\/hardware_profiles/)
        .to_return(status: 200, body: mock_response)
    end
    context 'When it called from existing object' do
      it 'should delete record and return true' do
        machine_config = MachineConfig.where(@params).first_or_create
        id = machine_config.id
        result = machine_config.destroy
        expect(MachineConfig.find_by(id: id)).to be_nil
        expect(result).to be_true
      end
    end
  end
end
