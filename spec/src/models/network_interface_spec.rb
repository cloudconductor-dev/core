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

describe NetworkInterface do
  before(:all) do
    cloud = FactoryGirl.create(:aws)
    key = URI.encode_www_form_component(cloud.key)
    secret = URI.encode_www_form_component(cloud.secret)
    @deltacloud_url = "http://#{key}:#{secret}@#{ConductorConfig.deltacloud_host}:#{ConductorConfig.deltacloud_port}/api"
    machine = FactoryGirl.create(:machine)
    network = FactoryGirl.create(:network)
    @params = FactoryGirl.attributes_for(:network_interface).merge(machine: machine, network: network)
  end

  after(:all) do
    NetworkInterface.delete_all
    Machine.delete_all
  end

  let(:network_interface) do
    NetworkInterface.create(@params)
  end

  describe 'on self.create' do
    context 'When DeltaCloud server returns 201 Created' do
      before do
        mock_response = '{"network_interface":{"id":"rspec_nic_id"}}'
        WebMock.stub_request(:post, "#{@deltacloud_url}/network_interfaces")
          .to_return(status: 201, body: mock_response)
      end
      it 'should store parameters and return NetworkInterface object' do
        nic = NetworkInterface.create(@params)
        expect(nic).to be
        expect(NetworkInterface.find_by(id: nic.id)).to be
      end
    end

    context 'When DeltaCloud server returns 500 Internal Server Error' do
      before do
        WebMock.stub_request(:post, "#{@deltacloud_url}/network_interfaces")
          .to_return(status: 500)
      end
      it 'should raise exception' do
        expect do
          NetworkInterface.create(@params.reject { |k, v| k == :ref_id })
        end.to raise_error(RestClient::Exception, '500 Internal Server Error')
      end
    end
  end

  describe 'on #destroy' do
    context 'When DeltaCloud server returns 404 Resource Not Found' do
      before do
        WebMock.stub_request(:delete, %r(#{@deltacloud_url}\/network_interfaces\/#{network_interface.ref_id}))
          .to_return(status: 404)
      end
      it 'should raise exception' do
        expect { network_interface.destroy }.to raise_error(RestClient::Exception, '404 Resource Not Found')
      end
    end

    context 'When DeltaCloud server returns 204 No Content' do
      before do
        WebMock.stub_request(:delete, %r(#{@deltacloud_url}\/network_interfaces\/.*))
          .to_return(status: 204)
      end
      it 'should delete record' do
        id = network_interface.id
        network_interface.destroy
        expect(NetworkInterface.find_by(id: id)).to be_nil
      end
    end
  end
end
