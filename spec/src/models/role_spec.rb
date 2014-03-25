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
describe Role do
  let(:role) { FactoryGirl.build_stubbed(:web_role) }

  describe 'on type' do
    context 'When Role.attribute_id begin web/ap/db' do
      it 'should return web/ap/db' do
        role.attribute_id = 'Web_role'
        expect(role.type).to eq('web')
        role.attribute_id = 'Ap_role'
        expect(role.type).to eq('ap')
        role.attribute_id = 'Db_role'
        expect(role.type).to eq('db')
      end
    end
    context 'When Role.attribute_id end web/ap/db' do
      it 'should return web/ap/db' do
        role.attribute_id = 'role_Web'
        expect(role.type).to eq('web')
        role.attribute_id = 'role_Ap'
        expect(role.type).to eq('ap')
        role.attribute_id = 'role_Db'
        expect(role.type).to eq('db')
      end
    end
    context 'When Role.attribute_id include web/ap/db' do
      it 'should return web/ap/db' do
        role.attribute_id = 'role_Web_apache'
        expect(role.type).to eq('web')
        role.attribute_id = 'role_Ap_tomcat'
        expect(role.type).to eq('ap')
        role.attribute_id = 'role_Db_postgresql'
        expect(role.type).to eq('db')
      end
    end
    context 'When Role.attribute_id does not include web or ap or db' do
      it 'should return unknoen' do
        role.attribute_id = 'Role'
        expect(role.type).to eq('unknown')
      end
    end
  end
end
