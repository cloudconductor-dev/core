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
describe MachineFilterGroup do
  before(:all) do
    @machine_filter_group = FactoryGirl.create(:machine_filter_group)
  end

  after(:all) do
    MachineFilterGroup.delete_all
  end

  describe 'on self.create' do
    it 'should have System object' do
      expect(@machine_filter_group.system).to be_instance_of(System)
    end
    it 'should have MachineFilterRuleGroup array' do
      expect(@machine_filter_group.machine_filter_rule_groups).to match_array([])
    end
    it 'should have MachineFilter array' do
      expect(@machine_filter_group.machine_filters).to match_array([])
    end
    it 'should have MachineGroup array' do
      expect(@machine_filter_group.machine_groups).to match_array([])
    end
  end
end
