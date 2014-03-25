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
describe CommonMachineConfig do
  before(:all) do
    @params = {
      name: 'xxxlarge',
      min_cpu: 88_128,
      min_memory: 1_429_892_880, # x 10^6
    }
  end
  after(:all) do
    CommonMachineConfig.destroy_all(@params)
  end

  describe 'on self.create' do
    context 'When receive correct parameters' do
      it 'should store parameters and return CommonMachineConfig object' do
        common_machine_config = CommonMachineConfig.create(@params)
        expect(CommonMachineConfig.find_by(@params)).to be
        expect(common_machine_config).to be_instance_of(CommonMachineConfig)
        expect(common_machine_config.name).to eq(@params[:name])
        expect(common_machine_config.min_cpu).to eq(@params[:min_cpu])
        expect(common_machine_config.min_memory).to eq(@params[:min_memory])
      end
    end
  end

  describe 'on #destroy' do
    context 'When called from existing object' do
      it 'should delete record and return true' do
        common_machine_config = CommonMachineConfig.where(@params).first_or_create
        id = common_machine_config.id
        result = common_machine_config.destroy
        expect(CommonMachineConfig.find_by(id: id)).to be_nil
        expect(result).to be_true
      end
    end
  end
end
