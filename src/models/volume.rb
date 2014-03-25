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
require 'json'

class Volume < ActiveRecord::Base
  belongs_to :system
  belongs_to :cloud_entry_point
  belongs_to :machine

  before_create :create_volume
  before_destroy :destroy_volume

  module STATE
    # Define DeltaCloud storage volume states
    AVAILABLE = 'AVAILABLE'
    IN_USE = 'IN-USE'
  end

  DEFAULT_TIMEOUT = 5

  def attach_volume(machine_id)
    Log.debug(Log.format_method_start(self.class, __method__))
    fail 'volume already attached' if latest_state == STATE::IN_USE
    target_machine = Machine.find_by(id: machine_id)
    payload = {
      instance_id: target_machine.ref_id,
      device: nil,
    }
    retry_count = 0
    begin
      response = client["storage_volumes/#{ref_id}/attach"].post(payload)
    rescue RestClient::Exception => e
      if e.message =~ /4\d\d/ && retry_count < 5
        retry_count += 1
        sleep 1
        retry
      end
      Log.error(Log.format_error_params(
        self.class,
        __method__,
        attributes: attributes,
        payload: payload,
        response: response,
        target_machine: target_machine
      ))
      raise
    end
    fail 'attach volume failed' unless wait(STATE::IN_USE)
    response = client["storage_volumes/#{ref_id}"].get
    response_hash = JSON.parse(response)
    update_attributes(
      machine: target_machine,
      mount_point: response_hash['storage_volume']['device'],
      state: STATE::IN_USE
    )
  rescue
    Log.error(Log.format_error_params(
      self.class,
      __method__,
      attributes: attributes,
      payload: payload,
      response: response,
      response_hash: response_hash,
      target_machine: target_machine
    ))
    raise
  end

  def detach_volume
    Log.debug(Log.format_method_start(self.class, __method__))
    fail 'volume is not attached' unless latest_state == STATE::IN_USE
    client["storage_volumes/#{ref_id}/detach"].post({})
    fail 'detach volume failed' unless wait(STATE::AVAILABLE)
    update_attributes(state: STATE::AVAILABLE)
  rescue
    Log.error(Log.format_error_params(self.class, __method__, attributes: attributes))
    raise
  end

  private

  def client
    cloud_entry_point.client
  end

  def create_volume
    Log.debug(Log.format_method_start(self.class, __method__))
    payload = {
      name: name,
      capacity: capacity,
      instance_id: machine.ref_id,
    }
    response = client['storage_volumes'].post(payload)
    response_hash = JSON.parse(response)
    self.ref_id = response_hash['storage_volume']['id']
    self.state = response_hash['storage_volume']['state']
  rescue
    Log.error(Log.format_error_params(
      self.class,
      __method__,
      attributes: attributes,
      response: response,
      response_hash: response_hash
    ))
    raise
  end

  def destroy_volume
    Log.debug(Log.format_method_start(self.class, __method__))
    detach_volume if latest_state == STATE::IN_USE
    client["storage_volumes/#{ref_id}"].delete
  rescue
    Log.error(Log.format_error_params(self.class, __method__, attributes: attributes))
    raise
  end

  def latest_state
    Log.debug(Log.format_method_start(self.class, __method__))
    response = client["storage_volumes/#{ref_id}"].get
    response_hash = JSON.parse(response)
    response_hash['storage_volume']['state']
  rescue
    Log.error(Log.format_error_params(
      self.class,
      __method__,
      attributes: attributes,
      response: response,
      response_hash: response_hash
    ))
    raise
  end

  def wait(state, timeout = DEFAULT_TIMEOUT)
    Log.debug(Log.format_method_start(self.class, __method__))
    timeout.times do
      return true if latest_state == state
      sleep 1
    end
    false
  end
end
