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
describe MachineImage do

  before(:all) do
    @drivers = [:ec2, :openstack]
    @clouds = {
      ec2: FactoryGirl.create(:aws),
      openstack: FactoryGirl.create(:openstack),
    }
    @deltacloud_url = "http://.*@#{ConductorConfig.deltacloud_host}:#{ConductorConfig.deltacloud_port}/api"
    credential = FactoryGirl.build_stubbed(:aws_key)
    common_machine_image = FactoryGirl.create(:centos)
    @params = @drivers.reduce({}) do |result, driver|
      result[driver] = {
        name: common_machine_image.name,
        common_machine_image_id: common_machine_image.id,
        cloud_entry_point_id: @clouds[driver].id,
      }
      result
    end
  end

  let(:openstack_images) do
    [
      {
        id: '0222031f-7797-49be-9ab3-8b80ab64fb20',
        href: 'http://localhost:9292/api/images/0222031f-7797-49be-9ab3-8b80ab64fb20',
        name: 'vyatta6.6R1',
        description: 'vyatta6.6R1',
        owner: 'demo',
        architecture: 'x86_64',
        state: 'ACTIVE',
        root_type: 'transient',
        creation_time: '2013-11-19T04:00:10Z',
        hardware_profiles: []
      },
      {
        id: '08738cd3-2a4a-4c75-9b0f-99bb86800328',
        href: 'http://localhost:3001/api/images/08738cd3-2a4a-4c75-9b0f-99bb86800328',
        name: 'CentOS 6.5',
        description: 'CentOS 6.5',
        owner: 'demo',
        architecture: 'x86_64',
        state: 'ACTIVE',
        root_type: 'transient',
        creation_time: '2013-11-15T05:14:14Z',
        hardware_profiles: []
      },
      {
        id: 'ec4eff4b-06e1-4e04-8cbb-b68450cd9289',
        href: 'http://localhost:9292/api/images/ec4eff4b-06e1-4e04-8cbb-b68450cd9289',
        name: 'Fedora19',
        description: 'Fedora19',
        owner: 'demo',
        architecture: 'x86_64',
        state: 'ACTIVE',
        root_type: 'transient',
        creation_time: '2013-10-16T17:06:35Z',
        hardware_profiles: []
      }
    ]
  end

  describe 'on self.create' do
    before do
      mock_response = JSON.generate(images: openstack_images)
      WebMock.stub_request(:get, /#{@deltacloud_url}\/images/)
        .to_return(status: 200, body: mock_response)
    end

    context 'When required machine image found on clound' do
      it 'should store parameters and return MachineImage object (AWS)' do
        machine_image = MachineImage.create(@params[:ec2])
        expect(MachineImage.find_by(@params[:ec2])).to be_instance_of(MachineImage)
        expect(machine_image.ref_id).to be_include('ami-')
      end
      it 'should store parameters and return MachineImage object (OpenStack)' do
        image = openstack_images.find { |i| i[:name] == 'CentOS 6.5' }
        machine_image = MachineImage.create(@params[:openstack])
        expect(MachineImage.find_by(@params[:openstack])).to be_instance_of(MachineImage)
        expect(machine_image.ref_id).to eq(image[:id])
      end
    end

    context 'When required machine image alread exist in database' do
      it 'should return stored MachineImage object' do
        @drivers.each do |driver|
          @stored_image = MachineImage.where(@params[driver]).first_or_create
          machine_image = MachineImage.where(@params[driver]).first_or_create
          expect(machine_image.id).to eq(@stored_image.id)
        end
      end
    end

    context 'When there is no image which satisfy requested os version' do
      before do
        @not_existed_image = CommonMachineImage.create(
          name: 'BeOS 5.0',
          os: 'BeOS',
          version: '5.0',
        )
      end
      it 'should raise RuntimeError' do
        @drivers.each do |driver|
          expect do
            MachineImage.create(
              common_machine_image_id: @not_existed_image.id,
              cloud_entry_point_id: @params[driver][:cloud_entry_point_id],
            )
          end.to raise_error(RuntimeError, "Not fount requested MachineImage on '#{@clouds[driver].name}'")
        end
      end
      after do
        @not_existed_image.destroy
      end
    end

    context 'When there is no available image on cloud' do
      before do
        mock_response = JSON.generate(images: [])
        WebMock.stub_request(:get, /#{@deltacloud_url}\/images/)
          .to_return(status: 200, body: mock_response)
      end
      it 'should raise RuntimeError' do
        [:openstack].each do |driver|
          expect do
            MachineImage.create(@params[driver])
          end.to raise_error(RuntimeError)
        end
      end
    end

    context 'Deltacloud server returns Internal Server Error' do
      before do
        WebMock.stub_request(:get, /#{@deltacloud_url}\/images/)
          .to_return(status: 500, body: 'error message')
      end
      it 'should raise RuntimeError' do
        [:openstack].each do |driver|
          expect do
            MachineImage.create(@params[driver])
          end.to raise_error(RuntimeError, '500 Internal Server Error')
        end
      end
    end
  end

  describe 'on #destroy' do
    before do
      mock_response = JSON.generate(images: openstack_images)
      WebMock.stub_request(:get, /#{@deltacloud_url}\/images/)
        .to_return(status: 200, body: mock_response)
    end
    context 'When called from existing object' do
      it 'should delete record and return true' do
        @drivers.each do |driver|
          machine_image = MachineImage.where(@params[driver]).first_or_create
          id = machine_image.id
          result = machine_image.destroy
          expect(MachineImage.find_by(id: id)).to be_nil
          expect(result).to be_true
        end
      end
    end
  end
end
