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
describe Operation do
  after(:all) do
    Operation.delete_all
  end

  describe 'on DEPLOY_SYSTEM operation' do
    context 'When success to create and run' do
      before do
        @operation = FactoryGirl.create(:operation)
      end
      after do
        @operation.destroy
      end
      it 'should success to store db' do
        expect(@operation).to be
        find_op = Operation.find_by(id: @operation.id)
        expect(find_op.type).to eq(@operation.type)
      end
    end

    context 'When fail to run and success to errback' do
      before do
        @now = Time.now
        @operation = FactoryGirl.create(:operation, started_at: @now)
      end
      after do
        @operation.destroy
      end
      it 'should catch exception and start rollback' do
        allow(@operation).to receive(:update_attributes).and_raise
        @operation.run
        # wait for completing Async process
        system = System.find_by(id: @operation.system.id)
        3.times do
          break unless system
          sleep 1
          system = System.find_by(id: @operation.system.id)
        end
        expect(system).to be_nil
        error_system = System.find_by(id: @operation.system.id + 1)
        expect(error_system.response_message).not_to be_blank
        expect(error_system.state).to eq('ERROR')
      end
    end

    context 'When fail to run and fail to errback' do
      before do
        @now = Time.now
        @operation = FactoryGirl.create(:operation, started_at: @now)
      end
      after do
        @operation.destroy
      end
      it 'should catch exception and start rollback' do
        allow(@operation).to receive(:update_attributes).and_raise
        allow(@operation.system).to receive(:destroy).and_raise
        system_id = @operation.system.id
        @operation.run
        # wait for completing Async process
        system = System.find_by(id: system_id)
        3.times do
          break unless system
          sleep 1
          system = System.find_by(id: system_id)
        end
        expect(system).to be_nil
        error_system = System.find_by(id: system_id + 1)
        expect(error_system.response_message).not_to be_blank
        expect(error_system.state).to eq('ERROR')
      end
    end
  end

  describe 'on DEPLOY_APPLICATION operation' do
    context 'When success to create and run' do
      it 'should be SUCCESS in application state' do
        op = FactoryGirl.create(:operation_application,
                                system: FactoryGirl.create(:application).system
                               )
        allow(op).to receive(:deploy_application)
        op.run
        # wait for completing Async process
        3.times do
          break if op.state == 'finished'
          sleep 1
        end
        expect(op.system.applications.first.state).to eq('SUCCESS')
        expect(op.state).to eq('finished')
      end
    end
    context 'When fail to create and run' do
      it 'should be ERROR in application state' do
        op = FactoryGirl.create(:operation_application,
                                system: FactoryGirl.create(:application).system
                               )
        allow(op).to receive(:deploy_application).and_raise
        op.run
        # wait for completing Async process
        3.times do
          break if op.state == 'error'
          sleep 1
        end
        expect(op.system.applications.first.state).to eq('ERROR')
        expect(op.state).to eq('error')
      end
    end
  end
end
