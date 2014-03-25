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

class Operation < ActiveRecord::Base
  include Action
  module Type
    DEPLOY_SYSTEM = 'deploy_system'
    DEPLOY_APPLICATION = 'deploy_application'
  end
  module State
    ACCEPTED = 'acceppted'
    IN_PROGRESS = 'in progress'
    FINISHED = 'finished'
    ERROR = 'error'
  end

  belongs_to :system
  before_create proc { self.state = State::ACCEPTED }
  self.inheritance_column = nil

  def run
    Log.debug(Log.format_method_start(self.class, __method__))
    Log.debug(Log.format_debug_param(attributes: attributes))
    case type
    when Type::DEPLOY_SYSTEM then
      #  If it is original, if it fails to deploy the system, and run the record registered in the db of conductor
      #  We must perform the removal of the system, which is a roll-back process while leaving.
      #  That after carrying out the removal of the system, to change to the "error" the state of the system of record is also run or at the same time
      #  It is necessary to change upon confirmation that was performed successfully Removal System is a rollback process was terminated.
      #  Current situation, the process to remove all records of the system, including the record run, to re-register as an error record
      #  Because it becomes, it is necessary to fix in the future.
      errback = proc do
        Log.debug(Log.format_debug_param('starting errback in DEPLOY_SYSTEM operation'))
        begin
          system.response_message = 'Error Occured!! Please contact your system administrator.'
          err_rec = System.create(system.dup.attributes)
          system.state = 'ERROR'
          err_rec.state = system.state
          system.destroy
        rescue => e
          System.delete(system.id)
          Log.error(Log.format_error_params(self.class, __method__, attributes: attributes, location: 'deploy_system errback'))
          Log.error(Log.format_exception(e))
        ensure
          System.find_by(id: system.id + 1).update_attribute(:state, err_rec.state)
        end
      end
      op = operation(errback) do
        Log.debug('starting DEPLOY_SYSTEM operation')
        deploy_system(system_id)
        system.update_attribute(:state, 'RUNNING')
      end
    when Type::DEPLOY_APPLICATION then
      # System and Application related one to one in release 0.2.0
      errback = proc do
        Log.debug(Log.format_debug_param('starting errback in DEPLOY_SYSTEM operation'))
        system.applications.first.update_attribute(:state, 'ERROR')
      end
      op = operation(errback) do
        Log.debug('starting DEPLOY_APPLICATION operation')
        deploy_application(system.applications.first)
        system.applications.first.update_attribute(:state, 'SUCCESS')
      end
    else
      error = NotImplementedError, "Failed to run #{type}. This operation type does not implemented yet."
      Log.error(Log.format_exception(error))
    end
    EM.defer(op)
  end

  private

  def operation(errback = nil)
    Log.debug(Log.format_method_start(self.class, __method__))
    proc do
      begin
        update_attributes(attributes.merge(state: State::IN_PROGRESS, started_at: Time.now))
        if block_given?
          ActiveRecord::Base.connection_pool.with_connection do
            yield
          end
        end
        default_callback
      rescue => e
        Log.error(Log.format_exception(e))
        default_errback
        errback.call if errback
      end
    end
  end

  def default_callback
    Log.debug(Log.format_method_start(self.class, __method__))
    unless error?
      begin
        update_attributes(attributes.merge(
          state: State::FINISHED,
          finished_at: Time.now
        ))
      rescue => e
        Log.error(Log.format_exception(e))
        raise e
      end
    end
  end

  def default_errback
    Log.debug(Log.format_method_start(self.class, __method__))
    update_attributes(attributes.merge(
      state: State::ERROR,
      finished_at: Time.now
    ))
    rescue => e
      Log.error(Log.format_exception(e))
  end

  def error?
    state == State::ERROR ? true : false
  end
end
