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
describe CloudEntryPoint do
  before(:all) do
    @infra = FactoryGirl.create(:openstack_infra)
    @params = FactoryGirl.attributes_for(:openstack).merge(infrastructure: @infra)
  end

  let(:external_network_ref_ids) do
    ['external_network_ref_id']
  end
  let(:external_net_addr_blocks) do
    ['192.168.166.0/24']
  end

  after(:all) do
    CloudEntryPoint.delete_all(name: @params[:name])
    @infra.delete
  end

  describe 'creating cloud entry point' do
    context 'case normal' do
      it 'store db and query by id' do
        # create cloud entry point
        cloud_entry_point = CloudEntryPoint.create(@params)
        id = cloud_entry_point.id

        cloud_entry_point = CloudEntryPoint.find_by_id(id)
        expect(cloud_entry_point).to be
        expect(cloud_entry_point.name).to eq(@params[:name])
        expect(cloud_entry_point.key).to eq(@params[:key])
        expect(cloud_entry_point.secret).to eq(@params[:secret])
        expect(cloud_entry_point.infrastructure.id).to eq(@params[:infrastructure].id)
      end
    end
  end

  describe 'deleting cloud entry point' do
    context 'case normal' do
      it 'delete from database using id' do
        cloud_entry_point = CloudEntryPoint.create(@params)
        id = cloud_entry_point.id
        cloud_entry_point.destroy
        # re-query
        cloud_entry_point = CloudEntryPoint.find_by_id(id)
        expect(cloud_entry_point).to be_nil
      end
    end
  end

  describe '#client' do
    context 'case normal' do
      before do
        @deltacloud_url = "http://#{ConductorConfig.deltacloud_host}:#{ConductorConfig.deltacloud_port}/api"
      end
      it 'instance is created, necessary attribute is set' do
        cloud_entry_point = CloudEntryPoint.create(@params)
        client = cloud_entry_point.client

        expect(client.url).to eq(@deltacloud_url)
        headers = client.headers
        expect(headers[:'X-Deltacloud-Driver']).to eq(@infra.driver)
        expect(headers[:'X-Deltacloud-Provider']).to eq(cloud_entry_point.entry_point)

        m = /Basic ([A-Za-z0-9+\/=]+)/.match(headers[:Authorization])
        auth =  Base64.decode64(m[1]).split(':')

        expect(auth[0]).to eq(@params[:key])
        expect(auth[1]).to eq(@params[:secret])

      end
    end
    # adding test case when adding validation
  end

  describe '#external_net_addrs' do
    before do
      @cloud = FactoryGirl.create(:openstack)
      Gateway.stub(external_network_ref_ids: external_network_ref_ids)
      NetworkGroup.stub(network_addresses: external_net_addr_blocks)
    end
    context 'When success to get external network addresses' do
      it 'should get external network address' do
        external_net_addrs = @cloud.external_net_addrs
        expect(external_net_addrs).to be_present
        expect(external_net_addrs).to match_array(external_net_addr_blocks)
      end
    end

    context 'When error occurred' do
      it 'should raise exception' do
        allow(Gateway).to receive(:external_network_ref_ids).and_raise
        expect { @cloud.external_net_addrs }.to raise_error(RuntimeError)
      end
    end
  end
end
