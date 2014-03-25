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
describe Network do
  before(:all) do
    @deltacloud_url = 'http://.*:.*@.*/api'
    network_group = FactoryGirl.create(:network_group)
    @params = FactoryGirl.attributes_for(:network).merge(network_group: network_group)
  end

  let(:network) do
    FactoryGirl.create(:network)
  end

  after(:all) do
    Network.delete_all(@params)
  end

  describe '#create_network' do
    context 'When DeltaCloud server returns 201 Created' do
      before do
        mock_response = '{"subnet":{"id":"mock_target_network_id"}}'
        WebMock.stub_request(:post, %r{#{@deltacloud_url}/subnets})
          .to_return(status: 201, body: mock_response)
      end
      it 'should stored in database correctly' do
        network = Network.create(@params)
        expect(network).to be
        expect(network.name).to eq(@params[:name])
        expect(network.network_address).to eq(@params[:network_address])
        expect(network.prefix).to eq(@params[:prefix])
        expect(Network.find_by(id: network.id)).to be
      end
    end

    context 'When DeltaCloud server returns 500 Internal Server Error' do
      before do
        WebMock.stub_request(:post, %r{#{@deltacloud_url}/subnets}).to_return(status: 500)
      end
      it 'should be failed creating network' do
        expect do
          Network.create(@params)
        end.to raise_error(Exception, '500 Internal Server Error')
      end
    end
  end

  describe '#destroy_network' do
    context 'When DeltaCloud server returns 404 Resource Not Found' do
      before do
        WebMock.stub_request(:delete, %r{#{@deltacloud_url}/subnets/.*}).to_return(status: 404)
      end
      it 'should be failed destroying network' do
        id = network.id
        expect { network.destroy }.to raise_error(Exception, '404 Resource Not Found')
        expect(Network.find_by(id: id)).to be
      end
    end

    context 'When DeltaCloud server returns 204 No Content' do
      before do
        WebMock.stub_request(:delete, %r{#{@deltacloud_url}/subnets/.*}).to_return(status: 204)
      end
      it 'should be success to query and destroy' do
        id = network.id
        network.destroy
        expect(Network.find_by(id: id)).to be_nil
      end
    end
  end
end
