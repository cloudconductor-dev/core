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

class Credential < ActiveRecord::Base
  belongs_to :cloud_entry_point
  belongs_to :system

  before_create :create_credential
  before_destroy :destroy_credential

  def client
    cloud_entry_point.client
  end

  def create_credential
    Log.debug(Log.format_method_start(self.class, __method__))
    payload = { name: name }
    response = client['keys'].post(payload)
    response_hash = JSON.parse(response)
    self.private_key = response_hash['key']['pem_rsa_key']
  rescue => e
    error_credential = attributes
    error_credential['private_key'] = '****' if private_key
    Log.error(Log.format_error_params(
      self.class,
      __method__,
      attributes: error_credential,
      payload: payload,
      response: response,
      response_hash: response_hash
    ))
    if e.respond_to?('http_body') && e.http_body =~ /The server returned status 409/
      Log.error("key pair #{name} already exists.")
    end
    raise e
  end

  def destroy_credential
    Log.debug(Log.format_method_start(self.class, __method__))
    response = client["keys/#{name}"].delete
  rescue
    error_credential = attributes
    error_credential['private_key'] = '****' if private_key
    Log.error(Log.format_error_params(self.class, __method__, attributes: error_credential))
    raise
  end
end
