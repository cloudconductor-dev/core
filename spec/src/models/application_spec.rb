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
describe Application do
  before(:all) do
    @system = System.create(
      name: 'my-system ' + Date.today.strftime('%Y/%m/%d'),
      template_xml: '<root/>',
    )
  end

  after(:all) do
    @system.destroy
  end

  describe 'creating application' do
    context 'When success to create application' do
      it 'store db and query by id' do
        # create application
        application = FactoryGirl.create(:application)
        id = application.id
        find_application = Application.find_by(id: id)
        expect(find_application).to be
        expect(find_application.name).to eq(application.name)
      end
    end
  end

  describe 'deleting application' do
    context 'When success to delete application' do
      it 'delete from database using id' do
        application = FactoryGirl.create(:application)
        id = application.id
        application.destroy
        # re-query
        application = Application.find_by(id: id)
        expect(application).to be_nil
      end
    end
  end

  describe '#deploy' do
    context 'When success to run operation' do
      it 'should Application state is changed to DEPLOYING' do
        application = FactoryGirl.create(:application)
        expect(application.state).to eq('NOT YET')
        allow(application.system.operations).to receive(:create!).and_return(double('op', run: nil))
        result = application.deploy
        expect(application.state).to eq('DEPLOYING')
      end
    end
    context 'When application does not persisted' do
      it 'should raise error' do
        application = FactoryGirl.create(:application)
        allow(application).to receive(:persisted?).and_raise
        expect { application.deploy }.to raise_error
      end
    end
  end
end
