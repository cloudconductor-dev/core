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
describe Volume do
  before(:all) do
    system = FactoryGirl.create(:system)
    cloud = FactoryGirl.create(:aws)
    key = URI.encode_www_form_component(cloud.key)
    secret = URI.encode_www_form_component(cloud.secret)
    @deltacloud_url = "http://#{key}:#{secret}@#{ConductorConfig.deltacloud_host}:#{ConductorConfig.deltacloud_port}/api"
    @machine = FactoryGirl.create(:machine)
    @params = FactoryGirl.attributes_for(:volume).merge(system: system, cloud_entry_point: cloud)
    @params[:machine] = @machine
  end

  after(:all) do
    Volume.delete_all(@params)
  end

  let(:volume) do
    FactoryGirl.create(:volume)
  end

  describe 'on self.create' do
    context 'When specified valid parameters' do
      before do
        mock_response = '{"storage_volume": {"id": "testid"}}'
        WebMock.stub_request(:post, %r(#{@deltacloud_url}/storage_volumes)).to_return(status: 200, body: mock_response)
      end
      it 'should store record and return Volume object' do
        volume = Volume.create(@params)
        expect(volume).to be_instance_of(Volume)
        expect(volume.name).to eq(@params[:name])
        expect(volume.machine).to be
      end
    end

    context 'When Deltacloud server returns 500 Internal Server Error' do
      before do
        WebMock.stub_request(:post, %r(#{@deltacloud_url}/storage_volumes)).to_return(status: 500)
      end
      it 'should fail to create volume' do
        expect do
          Volume.create(@params)
        end.to raise_error(RuntimeError, '500 Internal Server Error')
      end
    end
  end

  describe 'on #attach_volume'do
    context 'When specified invalid machine_id' do
      it 'should raise error' do
        allow(volume).to receive(:latest_state).and_return('AVAILABLE')
        expect { volume.attach_volume(nil) }.to raise_error
      end
    end

    context 'When specified valid machine_id' do
      before do
        response1 = '{"storage_volume": {"state": "AVAILABLE"}}'
        response2 = '{"storage_volume": {"state": "IN-USE", "device": "/dev/test"}}'
        WebMock.stub_request(:post, %r(#{@deltacloud_url}/storage_volumes/.*/attach)).to_return(status: 201)
        WebMock.stub_request(:get, %r(#{@deltacloud_url}/storage_volumes/.*))
          .to_return(status: 200, body: response1).times(2).then
          .to_return(status: 200, body: response2)
      end
      it 'should success to attach volume, and update state column' do
        volume.attach_volume(@machine.id)
        volume.reload
        expect(volume.state).to eq('IN-USE')
      end
    end

    context 'When Deltacloud Server returns 400 Bad Request' do
      before do
        response = '{"storage_volume": {"state": "AVAILABLE"}}'
        WebMock.stub_request(:get, %r(#{@deltacloud_url}/storage_volumes/.*))
          .to_return(status: 200, body: response)
        WebMock.stub_request(:post, %r(#{@deltacloud_url}/storage_volumes/.*/attach)).to_return(status: 400)
      end
      it 'should fail to attach volume' do
        expect { volume.attach_volume(@machine.id) }.to raise_error(RestClient::Exception, '400 Bad Request')
      end
    end

    context 'When Deltacloud Server returns 404 Resource Not Found' do
      before do
        response = '{"storage_volume": {"state": "AVAILABLE"}}'
        WebMock.stub_request(:get, %r(#{@deltacloud_url}/storage_volumes/.*))
          .to_return(status: 200, body: response)
        WebMock.stub_request(:post, %r(#{@deltacloud_url}/storage_volumes/.*/attach)).to_return(status: 404)
      end
      it 'should fail to attach volume' do
        expect { volume.attach_volume(@machine.id) }.to raise_error(RestClient::Exception, '404 Resource Not Found')
      end
    end
  end

  describe 'on self.destroy' do
    context 'When volume is not attached' do
      before do
        response = '{"storage_volume": {"state": "AVAILABLE"}}'
        WebMock.stub_request(:get, %r(#{@deltacloud_url}/storage_volumes/.*))
          .to_return(status: 200, body: response)
        WebMock.stub_request(:delete, %r(#{@deltacloud_url}/storage_volumes/.*))
          .to_return(status: 204)
      end
      it 'should delete database record' do
        id = volume.id
        volume.destroy
        expect(Volume.find_by(id: id)).to be_nil
      end
    end

    context 'When volume is attached to machine' do
      before do
        response_in_use = '{"storage_volume": {"state": "IN-USE"}}'
        response_available = '{"storage_volume": {"state": "AVAILABLE"}}'
        WebMock.stub_request(:get, %r(#{@deltacloud_url}/storage_volumes/.*))
          .to_return(status: 200, body: response_in_use).times(2).then
          .to_return(status: 200, body: response_available)
        WebMock.stub_request(:post, %r(#{@deltacloud_url}/storage_volumes/.*/detach))
          .to_return(status: 204)
        WebMock.stub_request(:delete, %r(#{@deltacloud_url}/storage_volumes/.*))
          .to_return(status: 204)
      end
      it 'should detach volume and delete volume' do
        id = volume.id
        volume.destroy
        expect(Volume.find_by(id: id)).to be_nil
      end
    end

    context 'When Deltacloud server returns 500 Internal Server Error' do
      before do
        response = '{"storage_volume": {"state": "AVAILABLE"}}'
        WebMock.stub_request(:get, %r(#{@deltacloud_url}/storage_volumes/.*))
          .to_return(status: 200, body: response)
        WebMock.stub_request(:delete, %r(#{@deltacloud_url}/storage_volumes/.*)).to_return(status: 500)
      end
      it 'should fail to create volume' do
        expect { volume.destroy }.to raise_error(RestClient::Exception, '500 Internal Server Error')
      end
    end
  end

  describe 'on #detach_volume' do
    context 'When volume is not attached' do
      # if try to delete a volume that has not been attached, openstack return 404
      before do
        response = '{"storage_volume": {"state": "AVAILABLE"}}'
        WebMock.stub_request(:get, %r(#{@deltacloud_url}/storage_volumes/.*))
          .to_return(status: 200, body: response)
      end
      it 'should raise error' do
        expect { volume.detach_volume }.to raise_error(RuntimeError, 'volume is not attached')
      end
    end

    context 'When volume is attached to machine' do
      before do
        response1 = '{"storage_volume": {"state": "IN-USE"}}'
        response2 = '{"storage_volume": {"state": "ERROR"}}'
        response3 = '{"storage_volume": {"state": "AVAILABLE"}}'
        WebMock.stub_request(:get, %r(#{@deltacloud_url}/storage_volumes/.*))
          .to_return(status: 200, body: response1).then
          .to_return(status: 200, body: response2).times(2).then
          .to_return(status: 200, body: response3)
        WebMock.stub_request(:post, %r(#{@deltacloud_url}/storage_volumes/.*/detach))
          .to_return(status: 202)
      end
      it 'should success to detach volume, and update state column' do
        volume.detach_volume
        volume.reload
        expect(volume.state).to eq('AVAILABLE')
      end
    end

    context 'When Deltacloud server returns 500Internal Server Error' do
      before do
        response = '{"storage_volume": {"state": "IN-USE"}}'
        WebMock.stub_request(:get, %r(#{@deltacloud_url}/storage_volumes/.*))
          .to_return(status: 200, body: response)
        WebMock.stub_request(:post, %r(#{@deltacloud_url}/storage_volumes/.*/detach)).to_return(status: 500)
      end
      it 'should fail to attach volume' do
        expect { volume.detach_volume }.to raise_error(RestClient::Exception, '500 Internal Server Error')
      end
    end

    context 'When Status is not changed AVAILABLE' do
      before do
        response1 = '{"storage_volume": {"state": "IN-USE"}}'
        response2 = '{"storage_volume": {"state": "ERROR"}}'
        WebMock.stub_request(:get, %r(#{@deltacloud_url}/storage_volumes/.*))
          .to_return(status: 200, body: response1).then
          .to_return(status: 200, body: response2)
        WebMock.stub_request(:post, %r(#{@deltacloud_url}/storage_volumes/.*/detach))
          .to_return(status: 202)
      end
      it 'should raise error' do
        expect { volume.detach_volume }.to raise_error(RuntimeError, 'detach volume failed')
      end
    end
  end
end
