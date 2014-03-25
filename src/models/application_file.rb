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
require 'erb'

class ApplicationFile < ActiveRecord::Base
  belongs_to :application
  belongs_to :machine_group
  belongs_to :middleware

  REPOSITORY_PATH = Dir.pwd + '/tmp'

  before_create :create_application_file
  before_destroy :destroy_application_file

  def to_h
    {
      id: id,
      name: name,
      create_date: created_at,
      update_date: updated_at,
      version: version,
      application: {
        id: application.id,
        name: application.name,
        create_date: application.created_at,
        update_date: application.updated_at,
      },
      machine_group: {
        id: machine_group.id,
        name: machine_group.name,
        description: machine_group.description,
        create_date: machine_group.created_at,
        update_date: machine_group.updated_at,
        common_machine_image: machine_group.common_machine_image.attributes,
        common_machine_config: machine_group.common_machine_config.attributes,
      },
    }
  end

  def create_application_file
    Log.debug(Log.format_method_start(self.class, __method__))
    latest_file = ApplicationFile.where(
      name: name,
      application_id: application_id,
      machine_group_id: machine_group_id
    ).order(:version).last
    latest_file.nil? ? self.version = 1 : self.version = latest_file.version + 1
    src_path = path
    self.path = sprintf('%s/%s-%s-%s-%s-%04d',
                        REPOSITORY_PATH,
                        application.system.id.to_s,
                        application.id.to_s,
                        machine_group.id.to_s,
                        name,
                        version)
    FileUtils.move(src_path, path)
  rescue
    Log.error(Log.format_error_params(self.class, __method__, attributes: attributes, src_path: src_path))
    raise
  end

  def destroy_application_file
    Log.debug(Log.format_method_start(self.class, __method__))
    FileUtils.remove(path, force: true)
  rescue
    Log.error(Log.format_error_params(self.class, __method__, attributes: attributes))
    raise
  end
end
