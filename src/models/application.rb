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

class Application < ActiveRecord::Base
  belongs_to :system
  has_many   :application_files, dependent: :destroy

  before_create proc { self.state = 'NOT YET' }

  def to_h
    {
      id: id,
      name: name,
      state: state,
      create_date: created_at,
      update_date: updated_at,
      application_files: application_files.map { |file| file.attributes },
    }
  end

  def deploy
    Log.debug(Log.format_method_start(self.class, __method__))
    if self.persisted?
      update_attribute(:state, 'DEPLOYING')
      operation = system.operations.create!(
        type: Operation::Type::DEPLOY_APPLICATION
      )
      operation.run
    else
      Log.error(Log.format_error_params(self.class, __method__, attributes: attributes))
      fail 'Application does not stored yet.'
    end
  end
end
