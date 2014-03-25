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
require 'sinatra/activerecord'

class MachineFilterGroup < ActiveRecord::Base
  belongs_to :system
  has_many :machine_filter_rule_groups, dependent: :destroy
  has_many :machine_filters, dependent: :destroy
  has_many :machine_groups
  def to_h
    {
      id: id,
      name: name,
      description: description,
      create_date: created_at,
      update_date: updated_at,
      machine_filter_rules: machine_filter_rule_groups.map { |rule| rule.to_h }
    }
  end
end
