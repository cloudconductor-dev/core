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
describe Infrastructure do
  before(:all) do
    @params = FactoryGirl.attributes_for(:openstack_infra)
  end

  after(:all) do
    Infrastructure.destroy_all(name: @params[:name])
  end

  describe 'creating infrastructure' do
    context 'case normal' do
      it 'store db and query by id' do
        infrastructure = Infrastructure.create(@params)
        expect(infrastructure).to be
        expect(infrastructure.name).to eq(@params[:name])
        expect(infrastructure.driver).to eq(@params[:driver])
        expect(Infrastructure.find_by(id: infrastructure.id)).to be
      end
    end
  end

  describe 'deleting infrastructure' do
    context 'case normal' do
      it 'delete from database using id' do
        infrastructure = Infrastructure.create(@params)
        id = infrastructure.id
        infrastructure.destroy
        expect(Infrastructure.find_by(id: id)).to be_nil
      end
    end
  end
end
