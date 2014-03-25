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
require 'uri'

describe FloatingIp do
  before(:all) do
    @cloud = FactoryGirl.create(:aws)
    key = URI.encode_www_form_component(@cloud.key)
    secret = URI.encode_www_form_component(@cloud.secret)
    @deltacloud_url = "http://#{key}:#{secret}@#{ConductorConfig.deltacloud_host}:#{ConductorConfig.deltacloud_port}/api"
    @machine = FactoryGirl.create(:machine)
    @params = {
      cloud_entry_point: @cloud
    }
    @mock_address = {
      id: '127.0.0.1',
      ip_address: '127.0.0.1'
    }
  end
  after(:all) do
    @cloud.delete
  end

  let(:floating_ip) do
    mock_response = JSON.generate(address: @mock_address)
    WebMock.stub_request(:post, "#{@deltacloud_url}/addresses")
      .to_return(status: 201, body: mock_response)
    FloatingIp.create(@params)
  end

  describe 'on self.create' do
    context 'When DeltaCloud server returns 201 Created' do
      it 'should store parameters and return FloatingIP object' do
        expect(floating_ip).to be_instance_of(FloatingIp)
        expect(floating_ip.ref_id).to eq(@mock_address[:id])
        expect(floating_ip.ip_address).to eq(@mock_address[:ip_address])
        expect(FloatingIp.find_by(id: floating_ip.id)).to be
      end
    end
    context 'When DeltaCloud server returns 500 Internal Server Error' do
      before do
        WebMock.stub_request(:post, "#{@deltacloud_url}/addresses")
          .to_return(status: 500)
      end
      it 'should raise RuntimeError' do
        expect do
          FloatingIp.create(@params)
        end.to raise_error(RuntimeError)
      end
    end
  end

  describe 'on #destroy' do
    context 'When DeltaCloud server returns 404 Not Found' do
      before do
        WebMock.stub_request(:delete, %r(#{@deltacloud_url}\/addresses\/.*))
          .to_return(status: 404)
      end
      it 'should raise RuntimeError' do
        id = floating_ip.id
        expect { floating_ip.destroy }.to raise_error(RuntimeError)
        expect(FloatingIp.find_by(id: id)).to be
      end
    end

    context 'When DeltaCloud server returns 204 No Content' do
      before do
        WebMock.stub_request(:delete, %r(#{@deltacloud_url}\/addresses\/.*))
          .to_return(status: 204)
      end
      it 'should delete record and return true' do
        id = floating_ip.id
        floating_ip.destroy
        expect(FloatingIp.find_by(id: id)).to be_nil
      end
    end
  end

  describe 'on #associate' do
    context 'When DeltaCloud server returns 204 No Content' do
      before do
        WebMock.stub_request(:post, %r(#{@deltacloud_url}\/addresses\/.*\/associate))
          .to_return(status: 204)
      end
      it 'should update record and return true' do
        result = floating_ip.associate(@machine.id)
        expect(floating_ip.machine.id).to eq(@machine.id)
        expect(result).to be_true
      end
    end
    context 'When DeltaCloud server returns status code 500' do
      before do
        WebMock.stub_request(:post, %r(#{@deltacloud_url}\/addresses\/.*\/associate))
          .to_return(status: 500)
      end
      it 'should raise exception' do
        expect do
          floating_ip.associate(@machine.id)
        end.to raise_error(RuntimeError)
      end
    end
  end

  describe 'on #disassociate' do
    context 'When DeltaCloud server returns 204 No Content' do
      before do
        WebMock.stub_request(:post, %r(#{@deltacloud_url}\/addresses\/.*))
          .to_return(status: 204)
      end
      it 'should update record and return true' do
        result = floating_ip.disassociate
        expect(floating_ip.machine).to be_nil
        expect(result).to be_true
      end
    end
    context 'When DeltaCloud server returns 404 Not Found' do
      before do
        WebMock.stub_request(:post, %r(#{@deltacloud_url}\/addresses\/.*))
          .to_return(status: 500)
      end
      it 'should raise RuntimeError' do
        expect { floating_ip.disassociate }.to raise_error(RuntimeError)
      end
    end
  end
end
