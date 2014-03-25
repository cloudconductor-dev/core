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
require 'json'

describe MachineFilter do
  before(:all) do
    cloud = FactoryGirl.create(:openstack)
    key = URI.encode_www_form_component(cloud.key)
    secret = URI.encode_www_form_component(cloud.secret)
    network_group = FactoryGirl.create(
      :network_group,
      cloud_entry_point: cloud
    )
    machine_filter_group = FactoryGirl.create(
      :machine_filter_group,
      system: network_group.system
    )
    @deltacloud_url = "http://#{key}:#{secret}@#{ConductorConfig.deltacloud_host}:#{ConductorConfig.deltacloud_port}/api"
    @params = {
      cloud_entry_point: cloud,
      machine_filter_group: machine_filter_group,
    }
    @mock_response = '{"firewall":{"id":"9da83896-1f46-482e-931c-a9222ca09c99"}}'
    @mock_firewalls_response = '{"firewalls":[{"id":"b2130b70-d68c-4967-9560-7469a60984be", "name":"default"}]}'
    @mock_firewalls_duplicate_response = '{"firewalls":[{"id":"b2130b70-d68c-4967-9560-7469a60984be", "name":"MyFilter"}]}'
    @network_group = FactoryGirl.create(:network_group, cloud_entry_point_id: cloud.id)
  end

  after(:all) do
    MachineFilter.delete_all
    MachineFilterGroup.delete_all
  end

  let(:machine_filter) do
    MachineFilter.create(@params)
  end

  describe 'on self.create' do
    context 'When DeltaCloud server returns 201 Created' do
      before do
        WebMock.stub_request(:get, %r(#{@deltacloud_url})).to_return(status: 200, body: @mock_firewalls_response)
        WebMock.stub_request(:post, %r(#{@deltacloud_url})).to_return(status: 201, body: @mock_response)
      end
      it 'should store parameters and return NetworkInterface object' do
        expect(machine_filter).to be
        expect(MachineFilter.find_by(id: machine_filter.id)).to be
        expect(machine_filter.ref_id).to eq(JSON.parse(@mock_response)['firewall']['id'])
      end
    end
    context 'When DeltaCloud server returns 500 Internal Server Error' do
      before do
        WebMock.stub_request(:get, %r(#{@deltacloud_url})).to_return(status: 200, body: @mock_firewalls_response)
        WebMock.stub_request(:post, %r(#{@deltacloud_url})).to_return(status: 500)
      end
      it 'should raise exception' do
        expect { machine_filter } .to raise_error(RestClient::Exception, '500 Internal Server Error')
      end
    end
  end
  describe 'on #destroy' do
    context 'When DeltaCloud server returns 404 Resource Not Found' do
      before do
        WebMock.stub_request(:get, %r(#{@deltacloud_url})).to_return(status: 200, body: @mock_firewalls_response)

        WebMock.stub_request(:post, %r(#{@deltacloud_url})).to_return(status: 201, body: @mock_response)
        WebMock.stub_request(:delete, %r(#{@deltacloud_url})).to_return(status: 404)
      end
      it 'should raise exception' do
        expect { machine_filter.destroy }.to raise_error(RestClient::Exception, '404 Resource Not Found')
      end
    end
    context 'When DeltaCloud server returns 204 No Content' do
      before do
        WebMock.stub_request(:get, %r(#{@deltacloud_url})).to_return(status: 200, body: @mock_firewalls_response)
        WebMock.stub_request(:post, %r(#{@deltacloud_url})).to_return(status: 201, body: @mock_response)
        WebMock.stub_request(:delete, %r(#{@deltacloud_url})).to_return(status: 204)
      end
      it 'should delete record' do
        id = machine_filter.id
        machine_filter.destroy
        expect(MachineFilter.find_by(id: id)).to be_nil
      end
    end
  end
end
