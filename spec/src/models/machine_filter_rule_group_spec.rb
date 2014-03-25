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
describe MachineFilterRuleGroup do
  before(:all) do
    @params = {
      machine_filter_group: FactoryGirl.create(:machine_filter_group)
    }
  end
  after(:all) do
    MachineFilterRuleGroup.delete_all(@params)
  end

  describe 'on self.create' do
    let(:machine_filter_rule_group) do
      machine_filter_rule_group = MachineFilterRuleGroup.create(@params)
    end
    it 'should have MachineFilterGroup object' do
      expect(machine_filter_rule_group.machine_filter_group).to be_instance_of(MachineFilterGroup)
    end
    it 'should have MachineFilterRule Array' do
      expect(machine_filter_rule_group.machine_filter_rules).to match_array([])
    end
  end
end
