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
describe ApplicationFile do
  before(:all) do
    @system = FactoryGirl.create(:system)
    application = FactoryGirl.create(:application)

    # ap server
    ap_role = FactoryGirl.create(:ap_role)
    @ap_group = FactoryGirl.create(:machine_group,
                                   name: 'AP Server',
                                   system: @system,
                                   role: ap_role)
    FactoryGirl.create(:machine, machine_group: @ap_group)
    FactoryGirl.create(:aws_key, system: @system)

    @params = {
      name: 'sample-application-file',
      application_id: application.id,
      machine_group_id: @ap_group.id,
    }
  end

  before(:each) do
    @tempfile = Tempfile.new('ApplicationFile')
  end

  after(:each) do
    ApplicationFile.destroy_all(name: @params[:name])
  end

  after(:all) do
  end

  describe 'creating application' do
    context 'received first version file' do
      it 'store db and file' do
        # create application
        application = ApplicationFile.create(
          name: @params[:name],
          application_id: @params[:application_id],
          machine_group_id: @params[:machine_group_id],
          path: @tempfile.path,
        )
        id = application.id
        application = ApplicationFile.find_by_id(id)
        expect(application).to be
        expect(application.version).to eq(1)

        expect(FileTest.exist?(application.path)).to be_true

      end
    end
    context 'received second version file' do
      it 'store db and file, version increment' do
        ApplicationFile.create(
          name: @params[:name],
          application_id: @params[:application_id],
          machine_group_id: @params[:machine_group_id],
          path: @tempfile.path,
        )

        tempfile2 = Tempfile.new('ApplicationFile')
        application2 = ApplicationFile.create(
          name: @params[:name],
          application_id: @params[:application_id],
          machine_group_id: @params[:machine_group_id],
          path: tempfile2.path,
        )

        expect(FileTest.exist?(application2.path)).to be_true
        expect(application2.version).to be(2)
      end
    end

    context 'When error occurred' do
      it 'should be occurred exception' do
        allow(ApplicationFile).to receive(:where).and_raise
        expect { ApplicationFile.create }.to raise_error(RuntimeError)
      end
    end
  end

  describe 'deleting application' do
    context 'case normal' do
      it 'delete from database using id' do
        application = ApplicationFile.create(
          name: @params[:name],
          application_id: @params[:application_id],
          machine_group_id: @params[:machine_group_id],
          path: @tempfile.path,
        )
        id = application.id
        path = application.path
        application.destroy
        # re-query
        application = ApplicationFile.find_by_id(id)
        expect(application).to be_nil
        expect(FileTest.exist?(path)).to be_false
      end
    end
  end
end
