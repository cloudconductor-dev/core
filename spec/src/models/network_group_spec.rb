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
describe NetworkGroup do
  before(:all) do
    @cloud = FactoryGirl.create(:openstack)
    @deltacloud_url = 'http:.*:.*@.*/api'
    @ref_network = {
      id: 'ref_network_id',
      name: 'ref_network',
      subnets: ['ref_subnet_id'],
      state: 'UP',
      address_blocks: ['10.0.0.0/24']
    }
    @params = FactoryGirl.attributes_for(:network_group).merge(cloud_entry_point: @cloud)
  end

  let(:network_group) do
    FactoryGirl.create(:network_group)
  end

  after(:all) do
    NetworkGroup.delete_all(@params)
  end

  describe '#create_network_group' do
    context 'case normal' do
      before do
        mock_response = '{"network":{"id":"mock_network_group_id"}}'
        WebMock.stub_request(:post, %r{#{@deltacloud_url}/networks})
          .to_return(status: 201, body: mock_response)
      end
      it 'is store network_group and query by id' do
        network_group = NetworkGroup.create(@params)
        expect(network_group).to be
        expect(network_group.name).to eq(@params[:name])
        expect(NetworkGroup.find_by(id: network_group.id)).to be
      end
    end

    context 'case error' do
      before do
        WebMock.stub_request(:post, %r{#{@deltacloud_url}/networks})
          .to_return(status: 500)
      end
      it 'is failed creating network_group' do
        expect do
          NetworkGroup.create(@params)
        end.to raise_error(Exception, '500 Internal Server Error')
      end
    end
  end

  describe '#destroy_network_group' do
    context 'case error' do
      before do
        WebMock.stub_request(:delete, %r{#{@deltacloud_url}/networks})
          .to_return(status: 404)
      end
      it 'is failed destroying network_group' do
        id = network_group.id
        expect { network_group.destroy }.to raise_error(Exception, '404 Resource Not Found')
        expect(NetworkGroup.find_by(id: id)).to be
      end
    end
    context 'case normal' do
      before do
        WebMock.stub_request(:delete, %r{#{@deltacloud_url}/networks})
          .to_return(status: 204)
      end
      it 'is queried by name and destroy' do
        id = network_group.id
        network_group.destroy
        # re-query
        expect(NetworkGroup.find_by(id: id)).to be_nil
      end
    end
  end

  describe 'network_addresses' do
    context 'When receive correct network' do
      before do
        mock_response = JSON.generate(network: @ref_network)
        WebMock.stub_request(:get, %r{#{@deltacloud_url}/networks/#{@ref_network[:id]}}).to_return(status: 200, body: mock_response)
      end
      it 'is get network addresses' do
        network_addresses = NetworkGroup.network_addresses(@cloud, @ref_network[:id])
        expect(network_addresses).to be_present
        expect(network_addresses).to match_array(@ref_network[:address_blocks])
      end
    end
    context 'When network does not found' do
      before do
        WebMock.stub_request(:get, %r{#{@deltacloud_url}/networks/#{@ref_network[:id]}}).to_return(status: 404)
      end
      it 'should raise Resource Not Found'do
        expect do
          network_addresses = NetworkGroup.network_addresses(@cloud, @ref_network[:id])
        end.to raise_error(Exception, '404 Resource Not Found')
      end
    end
    context 'When DeltaCloud server returns 500 Internal Server Error' do
      before do
        WebMock.stub_request(:get, %r{#{@deltacloud_url}/networks/#{@ref_network[:id]}}).to_return(status: 500)
      end
      it 'should raise Internal Server Error'do
        expect do
          network_addresses = NetworkGroup.network_addresses(@cloud, @ref_network[:id])
        end.to raise_error(Exception, '500 Internal Server Error')
      end
    end
  end
end
