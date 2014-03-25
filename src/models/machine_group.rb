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

class MachineGroup < ActiveRecord::Base
  belongs_to :system
  belongs_to :common_machine_image
  belongs_to :common_machine_config
  belongs_to :role
  belongs_to :machine_filter_group
  has_many :machines

  def to_h
    {
      id: id,
      name: name,
      node_type: node_type,
      create_date: created_at,
      update_date: updated_at
    }
  end
end
