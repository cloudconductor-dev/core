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
class CreateMachineFilterRuleGroups < ActiveRecord::Migration
  def up
    create_table :machine_filter_rule_groups do |t|
      t.integer :machine_filter_group_id
      t.string :direction
      t.integer :port_range_min
      t.integer :port_range_max
      t.string :protocol
      t.string :action
      t.string :ethertype
      t.integer :remote_machine_filter_group_id
      t.string :remote_ip_address
      t.timestamps
    end
  end

  def down
    drop_table :machine_filter_rule_groups
  end
end
