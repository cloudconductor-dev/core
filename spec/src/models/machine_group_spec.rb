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
describe MachineGroup do
  before(:all) do
    credential = FactoryGirl.build_stubbed(:aws_key)
    common_machine_image = FactoryGirl.build_stubbed(:centos)
    common_machine_config = FactoryGirl.build_stubbed(:small)
    system = FactoryGirl.build_stubbed(:system)
    @params = {
       name: 'test machine group',
       system: system,
       common_machine_config: common_machine_config,
       common_machine_image: common_machine_image,
    }
  end

  after(:all) do
    MachineGroup.delete_all(@params)
  end

  describe 'on self.create' do
    context 'When receive correct parameters' do
      it 'should store parameters and return MachineGroup object' do
        machine_group = MachineGroup.create(@params)
        expect(MachineGroup.find_by(@params)).to be_instance_of(MachineGroup)
        expect(machine_group.name).to eq(@params[:name])
      end
    end
  end

  describe 'on #destroy' do
    context 'When called from existing object' do
      it 'should delete record and return true' do
        machine_group = MachineGroup.create(@params)
        id = machine_group.id
        result = machine_group.destroy
        expect(MachineGroup.find_by(id: id)).to be_nil
        expect(result).to be_true
      end
    end
  end
end
