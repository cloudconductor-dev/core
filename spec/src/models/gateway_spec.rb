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
describe Gateway do
  before(:all) do
    @deltacloud_url = 'http://.*:.*@.*/api'
    network_group = FactoryGirl.create(:network_group)
    @network = FactoryGirl.create(:network, network_group: network_group)
    @cloud = network_group.cloud_entry_point
    @params = FactoryGirl.attributes_for(:gateway).merge(cloud_entry_point: @cloud)
  end
  let(:gateway) do
    FactoryGirl.create(:gateway)
  end
  after(:all) do
    Gateway.delete_all(name: @params[:name])
  end

  describe '#create_gateway' do
    context 'When DeltaCloud server return 201 and success to create gateway' do
      before do
        mock_response = '{"gateway": {"id": "rspec_test_id"}}'
        WebMock.stub_request(:post, %r{#{@deltacloud_url}/gateways}).to_return(status: 201, body: mock_response)
      end
      it 'should be stored in database correctly' do
        gateway = Gateway.create(@params)
        expect(gateway).to be
        expect(gateway.name).to eq(@params[:name])
        expect(Gateway.find_by(id: gateway.id)).to be
      end
    end

    context 'When DeltaCloud server return 500 and failed to create gateway' do
      before do
        WebMock.stub_request(:post, %r{#{@deltacloud_url}/gateways}).to_return(status: 500)
      end
      it 'should return status code 500' do
        expect do
          Gateway.create(@params)
        end.to raise_error(Exception, '500 Internal Server Error')
      end
    end
  end

  describe '#add_interface' do
    context 'When DeltaCloud server return 201 and success to add interface' do
      before do
        WebMock.stub_request(:put, %r{#{@deltacloud_url}/gateways/#{gateway.ref_id}/add_interface})
          .to_return(status: 201)
      end
      it 'should be added network to gateway' do
        res = gateway.add_interface(@network.id)
        expect(res).to be_true
      end
    end
  end

  describe '#remove_interface' do
    context 'When DeltaCloud server return 201 and success to remove interface' do
      before do
        WebMock.stub_request(:put, %r{#{@deltacloud_url}/gateways/#{gateway.ref_id}/remove_interface}).to_return(status: 201)
      end
      it 'should be removed network from gateway' do
        res = gateway.remove_interface(@network.id)
        expect(res).to be_true
      end
    end
  end

  describe '#destroy_gateway' do
    context 'When DeltaCloud server return status 500' do
      before do
        WebMock.stub_request(:put, %r{#{@deltacloud_url}/gateways/.*/remove_interface}).to_return(status: 404)
        WebMock.stub_request(:put, %r{#{@deltacloud_url}/gateways/.*/detach}).to_return(status: 404)
        WebMock.stub_request(:delete, %r{#{@deltacloud_url}/gateways/.*}).to_return(status: 404)
      end
      it 'should be failed destroying gateway' do
        id = gateway.id
        expect do
          gateway.destroy
        end.to raise_error(Exception, '404 Resource Not Found')
        expect(Gateway.find_by(id: id)).to be
      end
    end

    context 'When DeltaCloud server return status 204' do
      before do
        WebMock.stub_request(:put, %r{#{@deltacloud_url}/gateways/.*/remove_interface}).to_return(status: 204)
        WebMock.stub_request(:put, %r{#{@deltacloud_url}/gateways/.*/detach}).to_return(status: 204)
        WebMock.stub_request(:delete, %r{#{@deltacloud_url}/gateways/.*}).to_return(status: 204)
      end
      it 'should be query and destroy' do
        id = gateway.id
        gateway.destroy
        expect(Gateway.find_by(id: id)).to be_nil
      end
    end
  end

  describe '#external_network_ref_ids' do
    context 'When find external network' do
      before do
        mock_response = <<-'EOS'
          {"gateways":[
            {
              "id":"test_gateway_id",
              "network":{"id":"test_external_network_id"}
            }
          ]}
        EOS
        WebMock.stub_request(:get, %r{#{@deltacloud_url}/gateways}).to_return(status: 200, body: mock_response)
      end
      it 'should be get external network_ref_id' do
        external_network_ref_ids = Gateway.external_network_ref_ids(@cloud)
        expect(external_network_ref_ids).to be_present
        external_network_ref_ids.each do |ref_id|
          expect(ref_id).to eq('test_external_network_id')
        end
      end
    end

    context 'When does not found external network' do
      before do
        mock_response = '{"gateways":[{"id":"test_gateway_id"}]}'
        WebMock.stub_request(:get, %r{#{@deltacloud_url}/gateways}).to_return(status: 200, body: mock_response)
      end
      it 'should not be get external network_ref_id' do
        expect(Gateway.external_network_ref_ids(@cloud)).to be_empty
      end
    end
  end
end
