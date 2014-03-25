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
describe CommonMachineImage do
  before(:all) do
    @params = {
      name: 'CentOS 6.5',
      os: 'CentOS',
      version: '6.5'
    }
  end
  after(:all) do
    CommonMachineImage.destroy_all(@params)
  end

  describe 'on self.create' do
    context 'When receive correct parameters,' do
      it 'should store parameters and return CommonMachineImage object' do
        common_machine_image = CommonMachineImage.create(@params)
        expect(CommonMachineImage.find_by(@params)).to be
        expect(common_machine_image).to be_instance_of(CommonMachineImage)
        expect(common_machine_image.name).to eq(@params[:name])
        expect(common_machine_image.os).to eq(@params[:os])
        expect(common_machine_image.version).to eq(@params[:version])
      end
    end
  end

  describe 'on #destroy' do
    context 'When called from existing object' do
      it 'should delete record and return true' do
        common_machine_image = CommonMachineImage.where(@params).first_or_create
        id = common_machine_image.id
        result = common_machine_image.destroy
        expect(CommonMachineImage.find_by(id: id)).to be_nil
        expect(result).to be_true
      end
    end
  end
end
