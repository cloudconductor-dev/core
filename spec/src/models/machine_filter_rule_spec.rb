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

describe MachineFilterRule do
  before(:all) do
    cloud = FactoryGirl.create(:openstack)
    key = URI.encode_www_form_component(cloud.key)
    secret = URI.encode_www_form_component(cloud.secret)
    @deltacloud_url = "http://#{key}:#{secret}@#{ConductorConfig.deltacloud_host}:#{ConductorConfig.deltacloud_port}/api"
    @params = {
      machine_filter: FactoryGirl.create(:machine_filter),
      machine_filter_rule_group: FactoryGirl.create(:machine_filter_rule_group_address),
    }
    @mock_response = '{"firewall":{"id":"973821fd-523a-4ba0-998e-d9d8f958e350","rules":[{"id":"281df85c-82f4-411d-ad36-2a569fcad9e2","sources":[],"direction":"egress"},{"id":"3a0c7678-7a88-445d-b4b2-343f855a45cd","allow_protocol":"tcp","port_from":10225,"port_to":20225,"sources":[{"type":"address","family":"IPv4","address":"0.0.0.0","prefix":"0"}],"direction":"ingress"},{"id":"b4ae70ab-fd60-4ef6-a0f9-055d3c31846f","sources":[],"direction":"egress"}]}}'
    @mock_invalid_response = '{"firewall":{"description":"test","href":"http://localhost:9292/api/firewalls/test","id":"test","name":"test","owner_id":"200022781776","rules":[{"allow_protocol":"-1","direction":"egress","id":"200022781776~-1~~~@address,ipv4,0.0.0.0,0","sources":[{"address":"0.0.0.0","family":"ipv4","prefix":"0","type":"address"}]}]}}'
  end

  after(:all) do
    MachineFilter.delete_all
    MachineFilterGroup.delete_all
    MachineFilterRuleGroup.delete_all
  end

  let(:rule) do
    MachineFilterRule.create(@params)
  end

  describe 'on self.create' do
    context 'When DeltaCloud server returns 201 Created with valid response' do
      before do
        WebMock.stub_request(:get, %r(#{@deltacloud_url})).to_return(status: 201, body: @mock_response)
        WebMock.stub_request(:post, %r(#{@deltacloud_url})).to_return(status: 201, body: @mock_response)
      end

      it 'should store parameters and return NetworkInterface object' do
        rule = MachineFilterRule.create(@params)
        expect(MachineFilterRule.find_by(id: rule.id)).to be
        expect(rule.ref_id).to eq(JSON.parse(@mock_response)['firewall']['rules'].find { |r| r['allow_protocol'] == 'tcp' }['id'])
      end
    end

    context 'When DeltaCloud server returns 500 Internal Server Error' do
      before do
        WebMock.stub_request(:post, %r(#{@deltacloud_url})).to_return(status: 500)
      end
      it 'should raise exception' do
        expect { rule } .to raise_error(RestClient::Exception, '500 Internal Server Error')
      end
    end

    context 'When DeltaCloud server returns 201 Created with invalid response' do
      before do
        WebMock.stub_request(:get, %r(#{@deltacloud_url})).to_return(status: 201, body: @mock_invalid_response)
        WebMock.stub_request(:post, %r(#{@deltacloud_url})).to_return(status: 201, body: @mock_invalid_response)
      end
      it 'should fail with not found filter rule runtime error' do
        expect do
          MachineFilterRule.create(@params)
        end.to raise_error(RuntimeError, 'Not found filter rule in cloud matching with machine_filter_rule_group')
      end
    end
  end

  describe 'on #destroy' do
    context 'When DeltaCloud server returns 404 Resource Not Found' do
      before do
        WebMock.stub_request(:get, %r(#{@deltacloud_url})).to_return(status: 201, body: @mock_response)
        WebMock.stub_request(:post, %r(#{@deltacloud_url})).to_return(status: 201, body: @mock_response)
        WebMock.stub_request(:delete, %r(#{@deltacloud_url})).to_return(status: 404)
      end
      it 'should raise exception' do
        expect { rule.destroy }.to raise_error(RestClient::Exception, '404 Resource Not Found')
      end
    end
    context 'When DeltaCloud server returns 204 No Content' do
      before do
        WebMock.stub_request(:get, %r(#{@deltacloud_url})).to_return(status: 201, body: @mock_response)
        WebMock.stub_request(:post, %r(#{@deltacloud_url})).to_return(status: 201, body: @mock_response)
        WebMock.stub_request(:delete, %r(#{@deltacloud_url})).to_return(status: 204)
      end
      it 'should delete record' do
        id = rule.id
        rule.destroy
        expect(MachineFilterRule.find_by(id: id)).to be_nil
      end
    end
  end
end
