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
require_relative '../app'
require 'time'

RSpec.configure do |conf|
  conf.include Rack::Test::Methods
end

describe 'Sinatra app.rb test' do
  def app
    Sinatra::Application.environment = 'test'
    Sinatra::Application
  end

  let(:template_file) { 'system_template.xml' }
  let(:template_path) { "#{File.dirname(__FILE__)}/fixtures/#{template_file}" }
  let(:error_message) { 'Error Occured!! Please contact your system administrator.' }

  before(:all) do
    ConductorConfig.from_file(File.expand_path('spec/fixtures/conductor_config.rb'))
    template_uri = 'http://example.com/template.xml'
    template_xml = File.read("#{File.dirname(__FILE__)}/fixtures/system_template.xml")
    meta_xml = '<meta></meta>'
    user_paramerters = { 'name' => 'test-system', 'description' => 'test system description', 'machine_groups' => { 'web_server_g.apache.hostname' => 'localhost' }, 'roles' => { 'web_role.apache.hostname' => '192.168.0.1' } }
    cloud_entry_points = { 'cloud1' => 1 }
    @payload = {
      template_xml: template_xml,
      template_xml_uri: template_uri,
      meta_xml: meta_xml,
      user_input_keys: user_paramerters,
      cloud_entry_points: cloud_entry_points
    }
  end

  describe 'POST /systems' do
    context 'When received valid template xml' do
      it 'should return 202 when request is Accepted' do
        system = FactoryGirl.build_stubbed(:system)
        allow(system).to receive(:deploy).and_return(true)
        allow(System).to receive(:create!).and_return(system)
        user_paramerters = {
          name: 'test-system',
          description: 'test system description',
          machine_groups: {
            :'web_server_g.apache.hostname' => 'localhost'
          },
          roles: {
            :'web_role.apache.hostname' => '192.168.0.1'
          }
        }
        cloud_entry_points = { cloud1: 1 }
        payload = {
          template_xml: system.template_xml,
          template_xml_uri: system.template_uri,
          meta_xml: system.meta_xml,
          user_input_keys: user_paramerters,
          cloud_entry_points: cloud_entry_points
        }
        post '/systems', payload
        expect(last_response).to be
        expect(last_response.status).to eq(202)
        response = JSON.parse(last_response.body)
        expect(response['id']).to eq(system.id)
        expect(response['name']).to eq(system.name)
        expect(response['status']['type']).to eq(system.state)
      end
    end

    context 'When fail to create system' do
      it 'should return status code 500 and message' do
        post '/systems'
        expect(last_response).to be
        expect(last_response.status).to eq(500)
        response = JSON.parse(last_response.body)
        expect(response['message']).to eq(error_message)
      end
    end
  end

  describe 'GET /systems' do
    context 'When systems have several numbers' do
      before do
        System.delete_all
        @systems = (0..7).map do |i|
          FactoryGirl.create(:system, name: "system#{i}")
        end
        @systems.sort! { |a, b| b.created_at <=> a.created_at }
      end
      after do
        System.destroy_all
      end

      it 'received request(page:1) and should return 7..5 systems data' do
        template_name = { 'System' => { 'Name' => 'rspec-test-template-name' } }
        allow(XmlParser).to receive(:parse).and_return(template_name)
        get '/systems', page: 1, per_page: 3
        expect(last_response).to be
        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        expect(response['data'].size).to eq(3)
        response['data'].each_with_index do |system, i|
          expect(system['name']).to eq(@systems[i].name)
        end
      end

      it 'received request(page:2) and should return 4..2 systems data' do
        template_name = { 'System' => { 'Name' => 'rspec-test-template-name' } }
        allow(XmlParser).to receive(:parse).and_return(template_name)
        get '/systems', page: 2, per_page: 3
        expect(last_response).to be
        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        expect(response['data'].size).to eq(3)
        response['data'].each_with_index do |system, i|
          expect(system['name']).to eq(@systems[i + 3].name)
        end
      end

      it 'received request(page:3) and should return 1..0 systems data' do
        template_name = { 'System' => { 'Name' => 'rspec-test-template-name' } }
        allow(XmlParser).to receive(:parse).and_return(template_name)
        get '/systems', page: 3, per_page: 3
        expect(last_response).to be
        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        expect(response['data'].size).to eq(2)
        response['data'].each_with_index do |system, i|
          expect(system['name']).to eq(@systems[i + 6].name)
        end
      end

      it 'received request(page:4) and should return empty data' do
        get '/systems', page: 4, per_page: 3
        expect(last_response).to be
        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        expect(response['total']).to eq(System.count)
        expect(response['data']).to eq([])
      end
    end

    context 'When fail to get systems' do
      it 'should return response code 500' do
        allow(System).to receive(:all).and_return(nil)
        get '/systems', page: 1, per_page: 3
        expect(last_response).to be
        expect(last_response.status).to eq(500)
        response = JSON.parse(last_response.body)
        expect(response['message']).to eq(error_message)
      end
    end
  end

  describe 'GET /systems/:id' do
    context 'When specified existing system' do
      before do
        @system = FactoryGirl.create(:system, state: 'AVAILABLE')
      end
      it 'should return 200 OK and system informations' do
        get "/systems/#{@system.id}"
        expect(last_response).to be
        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        expect(response.keys).to eq(@system.to_h.keys.map { |k| k.to_s })
      end
      after do
        @system.delete
      end
    end
    context 'When fail to get system' do
      it 'should return status code 500' do
        get '/systems/999999'
        expect(last_response).to be
        expect(last_response.status).to eq(500)
        response = JSON.parse(last_response.body)
        expect(response['message']).to eq(error_message)
      end
    end
  end

  describe 'GET /systems/:id/machine_groups' do
    before do
      @machine_group = FactoryGirl.create(:machine_group)
    end
    after do
      @machine_group.delete
    end
    context 'When specified existing system' do
      it 'should return 200 OK and system informations' do
        get "/systems/#{@machine_group.system.id}/machine_groups"
        expect(last_response).to be
        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        expect(response.first.keys).to eq(@machine_group.to_h.keys.map { |k| k.to_s })
      end
    end
    context 'When fail to get machine_groups' do
      it 'should return status code 500' do
        allow(System).to receive(:find_by).and_return(nil)
        get "/systems/#{@machine_group.system.id}/machine_groups"
        expect(last_response).to be
        expect(last_response.status).to eq(500)
        response = JSON.parse(last_response.body)
        expect(response['message']).to eq(error_message)
      end
    end
  end

  describe 'GET /systems/:id/machines' do
    context 'When specified existing system' do
      before do
        @system =  FactoryGirl.create(:system)
        @machinegroup = FactoryGirl.create(
          :machine_group,
          name: "Web_#{@system.id}",
          system: @system
        )
        @cloudentrypoint = FactoryGirl.create(:aws)
        @machine = FactoryGirl.create(
          :machine,
          name: "Server_#{@machinegroup.name}",
          machine_group: @machinegroup,
          cloud_entry_point: @cloudentrypoint,
          state: 'DONE',
        )
      end
      it 'should return response code 200' do
        get "/systems/#{@machine.machine_group.system.id}/machines"
        expect(last_response).to be
        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        expect(response['total']).to eq(1)
        response['data'].each do |m|
          expect(m.keys).to eq(@machine.to_h.keys.map { |k| k.to_s })
        end
      end
    end

    context 'When fail to get system in machines' do
      it 'should return status code 500' do
        get '/systems/999999/machines'
        expect(last_response).to be
        expect(last_response.status).to eq(500)
        response = JSON.parse(last_response.body)
        expect(response['message']).to eq(error_message)
      end
    end
  end

  describe 'GET /systems/:id/networks' do
    context 'When specified system exists' do
      before do
        @network = FactoryGirl.create(:network)
        @network_group = @network.network_group
      end
      it 'should return 200 OK and network group informations' do
        get "/systems/#{@network_group.system.id}/networks"
        expect(last_response).to be
        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        expect(response['total']).to eq(1)
        ng = response['data'].first
        net = ng['networks'].first
        expect(ng['id']).to eq(@network_group.id)
        expect(ng['name']).to eq(@network_group.name)
        expect(net['id']).to eq(@network.id)
        expect(net['name']).to eq(@network.name)
        expect(net['network_address']).to eq(@network.network_address)
        expect(net['prefix']).to eq(@network.prefix)
        expect(net['state']).to eq(@network.state)
        expect(net['createDate']).to eq(@network.created_at.iso8601)
        expect(net['updateDate']).to eq(@network.updated_at.iso8601)
      end
      after do
        @network.delete
        @network_group.delete
      end
    end
    context 'When Failed to get system' do
      it 'should return status code 500' do
        allow(System).to receive(:find_by).and_return(nil)
        get '/systems/999999/networks'
        expect(last_response).to be
        expect(last_response.status).to eq(500)
        response = JSON.parse(last_response.body)
        expect(response['message']).to eq(error_message)
      end
    end
  end

  describe 'POST /systems/:id/applications' do
    context 'When received correct parameters' do
      it 'should store parameters and return 201 Created' do
        post '/systems/999/applications'
        expect(last_response).to be
        expect(last_response.status).to eq(201)
        response = JSON.parse(last_response.body)
        expect(response['name']).to eq(ConductorConfig.application_name)
        # expect(response['state']).to eq('not yet')
        expect(response['create_date']).to be
        expect(response['update_date']).to be
      end
    end
    context 'When Failed to create Application' do
      it 'should return status code 500' do
        allow(Application).to receive(:create!).and_raise
        post '/systems/999/applications'
        expect(last_response).to be
        expect(last_response.status).to eq(500)
        response = JSON.parse(last_response.body)
        expect(response['message']).to eq(error_message)
      end
    end
  end

  describe 'GET /systems/:id/applications' do
    context 'When specified system exists' do
      before do
        @application = FactoryGirl.create(:application)
      end
      it 'should return response code 200' do
        get "/systems/#{@application.system.id}/applications"
        expect(last_response).to be
        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        expect(response['total']).to eq(1)
        data = response['data'].first
        expect(data['name']).to eq(@application.name)
      end
      after do
        @application.delete
      end
    end
    context 'When Failed to get Application' do
      it 'should return status code 500' do
        allow(System).to receive(:find_by).and_return(nil)
        get '/systems/999999/applications'
        expect(last_response).to be
        expect(last_response.status).to eq(500)
        response = JSON.parse(last_response.body)
        expect(response['message']).to eq(error_message)
      end
    end
  end

  describe 'GET /systems/:id/applications/:application_id' do
    context 'When specified system exists' do
      before do
        @application = FactoryGirl.create(:application)
      end
      it 'should return response code 200' do
        get "/systems/#{@application.system.id}/applications/#{@application.id}"
        expect(last_response).to be
        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        expect(response['id']).to eq(@application.id)
        expect(response['name']).to eq(@application.name)
      end
      after do
        @application.delete
      end
    end
    context 'When Failed to get Application' do
      it 'should return status code 500' do
        allow(System).to receive(:find_by).and_return(nil)
        get '/systems/999999/applications/999999'
        expect(last_response).to be
        expect(last_response.status).to eq(500)
        response = JSON.parse(last_response.body)
        expect(response['message']).to eq(error_message)
      end
    end
  end

  describe 'POST /systems/:id/applications/:application_id/application_files' do
    context 'When receive correct parameters' do
      before do
        @application_file = FactoryGirl.create(:application_file)
      end
      it 'should store parameters and return 201 Created' do
        upload_file = Rack::Test::UploadedFile.new(template_path)
        post "/systems/#{@application_file.application.system.id}/applications/#{@application_file.application.id}/application_files", machine_group_id: @application_file.machine_group.id, file: upload_file
        expect(last_response).to be
        expect(last_response.status).to eq(201)
        response = JSON.parse(last_response.body)
        expect(response['name']).to eq(template_file)
        expect(response['version']).to eq(1)
      end
      after do
        @application_file.delete
      end
    end
    context 'When Failed to create Application File' do
      before do
        @application_file = FactoryGirl.create(:application_file)
      end
      it 'should return status code 500' do
        allow(ApplicationFile).to receive(:create!).and_raise
        upload_file = Rack::Test::UploadedFile.new(template_path)
        post "/systems/#{@application_file.application.system.id}/applications/#{@application_file.application.id}/application_files", machine_group_id: @application_file.machine_group.id, file: upload_file
        expect(last_response).to be
        expect(last_response.status).to eq(500)
        response = JSON.parse(last_response.body)
        expect(response['message']).to eq(error_message)
      end
      after do
        @application_file.delete
      end
    end
    context 'When Application is not member of System' do
      it 'should return status code 500' do
        post '/systems/999999/applications/99999/application_files'
        expect(last_response).to be
        expect(last_response.status).to eq(500)
        response = JSON.parse(last_response.body)
        expect(response['message']).to eq(error_message)
      end
    end
  end

  describe 'GET /systems/:id/applications/:application_id/application_files' do
    before do
      @application = FactoryGirl.create(:application)
      @machine_group = FactoryGirl.create(:machine_group)
      @file = FactoryGirl.create(:application_file,
                                 application: @application,
                                 machine_group: @machine_group)
    end
    context 'When specified system exists' do
      it 'should return response code 200' do
        get "/systems/#{@application.system.id}/applications/#{@application.id}/application_files"
        expect(last_response).to be
        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        expect(response['total']).to eq(1)
        data = response['data'].first
        expect(data['name']).to eq(@file.name)
        expect(data['version']).to eq(@file.version)
      end
    end
    context 'When specified system exists and 2 files associated with the system' do
      before do
        @file2 = FactoryGirl.create(:application_file,
                                    application: @application,
                                    machine_group: @machine_group)
      end
      it 'should return response code 200' do
        get "/systems/#{@application.system.id}/applications/#{@application.id}/application_files"
        expect(last_response).to be
        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        expect(response['total']).to eq(2)
        data1 = response['data'][0]
        expect(data1['name']).to eq(@file.name)
        expect(data1['version']).to eq(@file.version)
        data2 = response['data'][1]
        expect(data2['name']).to eq(@file2.name)
        expect(data2['version']).to eq(@file2.version)
      end
      after do
        @file2.delete
      end
    end
    context 'When specified system does not exist' do
      it 'should return status code 500' do
        allow(System).to receive(:find_by).and_return(nil)
        get "/systems/-1/applications/#{@application.id}/application_files"
        expect(last_response).to be
        expect(last_response.status).to eq(500)
        response = JSON.parse(last_response.body)
        expect(response['message']).to eq(error_message)
      end
    end
    context 'When specified application does not exist' do
      it 'should return status code 500' do
        allow(Application).to receive(:find_by).and_return(nil)
        get "/systems/#{@application.system.id}/applications/999999/application_files"
        expect(last_response).to be
        expect(last_response.status).to eq(500)
        response = JSON.parse(last_response.body)
        expect(response['message']).to eq(error_message)
      end
    end
    after do
      @file.delete
      @machine_group.delete
      @application.delete
    end
  end

  describe 'POST /systems/:id/applications/:application_id/deploy' do
    before do
      @application = FactoryGirl.create(:application)
    end
    context 'When receive correct parameters' do
      it 'should store parameters and return 200 OK' do
        file1 = FactoryGirl.create(:application_file,
                                   name: 'file1',
                                   application: @application)
        file2 = FactoryGirl.create(:application_file,
                                   name: 'file2',
                                   application: @application)
        allow(Application).to receive(:find_by).and_return(@application)
        allow(@application).to receive(:deploy)
        post "/systems/#{@application.system.id}/applications/#{@application.id}/deploy"
        expect(last_response).to be
        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)

        application_files = response['application_files']
        expect(application_files.size).to eq(2)
        data1 = application_files[0]
        expect(data1['name']).to eq(file1.name)
        expect(data1['version']).to eq(file1.version)
        data2 = application_files[1]
        expect(data2['name']).to eq(file2.name)
        expect(data2['version']).to eq(file2.version)
      end
    end
    context 'When Failed to deploy application' do
      it 'should return status code 500' do
        allow(Application).to receive(:find_by).and_return(@application)
        allow(@application).to receive(:deploy).and_raise
        post "/systems/#{@application.system.id}/applications/#{@application.id}/deploy"
        expect(last_response).to be
        expect(last_response.status).to eq(500)
        response = JSON.parse(last_response.body)
        expect(response['message']).to eq(error_message)
      end
    end
    after do
      @application.delete
    end
  end

  describe 'delete /systems/:id/applications/:application_id/application_files' do
    before do
      @application = FactoryGirl.create(:application)
      @machine_group = FactoryGirl.create(:machine_group)
      @file = FactoryGirl.create(:application_file,
                                 application: @application,
                                 machine_group: @machine_group,
                                 path: '/not/exist/file/path')
    end
    context 'When receive correct parameters' do
      it 'should be return response code 204' do
        delete "/systems/#{@application.system.id}/applications/" +
          "#{@application.id}/application_files/#{@file.id}"
        expect(last_response).to be
        expect(last_response.status).to eq(204)
      end
    end

    context 'When Failed to delete application' do
      it 'should return status code 500 with invalid application_file id' do
        delete "/systems/#{@application.system.id}/applications/" +
          "#{@application.id}/application_files/-1"
        expect(last_response).to be
        expect(last_response.status).to eq(500)
        response = JSON.parse(last_response.body)
        expect(response['message']).to eq(error_message)
      end

      it 'should return response code 500 with failed to destroy application_file' do
        mock_file = double('mock_application_file')
        allow(ApplicationFile).to receive(:find_by).and_return(mock_file)
        allow(mock_file).to receive(:destroy).and_raise

        delete "/systems/#{@application.system.id}/applications/" +
          "#{@application.id}/application_files/-1"
        expect(last_response).to be
        expect(last_response.status).to eq(500)
        response = JSON.parse(last_response.body)
        expect(response['message']).to eq(error_message)
      end
    end
    after do
      @file.delete
      @machine_group.delete
      @application.delete
    end
  end

  describe 'POST /cloud_entry_points' do
    context 'When receive correct parameters' do
      it 'should store parameters and return 201 Created' do
        payload = FactoryGirl.build(:openstack).attributes
        post '/cloud_entry_points', payload
        expect(last_response).to be
        expect(last_response.status).to eq(201)
        response = JSON.parse(last_response.body)
        expect(response.keys).to eq(FactoryGirl.build_stubbed(:openstack).to_h.keys.map { |k| k.to_s })
      end
    end

    context 'When receive invalid parameters' do
      it 'should return status code 500' do
        allow(CloudEntryPoint).to receive(:create!).and_raise
        post '/cloud_entry_points', {}
        expect(last_response).to be
        expect(last_response.status).to eq(500)
        response = JSON.parse(last_response.body)
        expect(response['message']).to eq(error_message)
      end
    end
  end

  describe 'GET /cloud_entry_points' do
    context 'case normal' do
      before do
        infra = FactoryGirl.create(:openstack_infra)
        CloudEntryPoint.delete_all
        @clouds = (0..7).map do |i|
          CloudEntryPoint.create(
            name: "cloud#{i}",
            infrastructure: infra,
            created_at: "2013-11-28 18:00:0#{i}",
            updated_at: "2013-11-28 18:00:0#{i}",
          )
        end
        @clouds.sort! { |a, b| b.created_at <=> a.created_at }
      end
      after do
        CloudEntryPoint.destroy_all
      end

      it 'received request(page:1) and should be return 7..5 cloud_entry_points data' do
        get '/cloud_entry_points', page: 1, per_page: 3
        expect(last_response).to be
        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        expect(response['data'].size).to eq(3)
        response['data'].each_with_index do |cloud, i|
          expect(cloud['name']).to eq(@clouds[i].name)
        end
      end

      it 'received request(page:2) and should be return 4..2 cloud_entry_points data' do
        get '/cloud_entry_points', page: 2, per_page: 3
        expect(last_response).to be
        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        expect(response['data'].size).to eq(3)
        response['data'].each_with_index do |cloud, i|
          expect(cloud['name']).to eq(@clouds[i + 3].name)
        end
      end

      it 'received request(page:3) and should be return 1..0 cloud_entry_points data' do
        get '/cloud_entry_points', page: 3, per_page: 3
        expect(last_response).to be
        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        expect(response['data'].size).to eq(2)
        response['data'].each_with_index do |cloud, i|
          expect(cloud['name']).to eq(@clouds[i + 6].name)
        end
      end

      it 'received request(page:4) and should be return empty data' do
        get '/cloud_entry_points', page: 4, per_page: 3
        expect(last_response).to be
        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        expect(response['total']).to eq(CloudEntryPoint.count)
        expect(response['data']).to eq([])
      end
    end

    context 'When failed to get all cloud_entry_points' do
      it 'should be return response code 500' do
        allow(CloudEntryPoint).to receive(:all).and_return(nil)
        get '/cloud_entry_points', page: 1, per_page: 3
        expect(last_response).to be
        expect(last_response.status).to eq(500)
        response = JSON.parse(last_response.body)
        expect(response['message']).to eq(error_message)
      end
    end
  end

  describe 'GET /cloud_entry_points/:id' do
    context 'When specified existing cloud entry point' do
      before do
        @cloud = FactoryGirl.create(:openstack)
      end
      it 'should return 200 OK and cloud_entry_point informations' do
        get "/cloud_entry_points/#{@cloud.id}"
        expect(last_response).to be
        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        expect(response.keys).to eq(@cloud.to_h.keys.map { |k| k.to_s })
      end
    end

    context 'When does not found specified cloud entry point' do
      it 'should return status code 500' do
        get '/cloud_entry_points/-1'
        expect(last_response).to be
        expect(last_response.status).to eq(500)
        response = JSON.parse(last_response.body)
        expect(response['message']).to eq(error_message)
      end
    end
  end

  describe 'PUT /cloud_entry_points/:id' do
    context 'When modified existing cloud entry point' do
      before do
        @cloud = FactoryGirl.create(:openstack)
      end
      it 'should return 200 OK and cloud_entry_point(after modify) informations' do
        payload = FactoryGirl.build(:aws).attributes
        put "/cloud_entry_points/#{@cloud.id}", payload
        expect(last_response).to be
        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        expect(response['name']).to eq(payload['name'])
      end
      after do
        @cloud.destroy
      end
    end
    context 'When does not found specified cloud entry point' do
      it 'should return status code 500' do
        put '/cloud_entry_points/-1'
        expect(last_response).to be
        expect(last_response.status).to eq(500)
        response = JSON.parse(last_response.body)
        expect(response['message']).to eq(error_message)
      end
    end
  end

  describe 'DELETE /cloud_entry_pointss' do
    context 'When modified existing cloud entry point' do
      before do
        @cloud = FactoryGirl.create(:openstack)
      end
      it 'should be return response code 204' do
        delete "/cloud_entry_points/#{@cloud.id}"
        expect(last_response).to be
        expect(last_response.status).to eq(204)
      end
    end

    context 'When does not found specified cloud entry point' do
      it 'should return response code 500' do
        delete '/cloud_entry_points/-1'
        expect(last_response).to be
        expect(last_response.status).to eq(500)
        response = JSON.parse(last_response.body)
        expect(response['message']).to eq(error_message)
      end
    end
  end

  describe 'POST /infrastructures' do
    context 'When receive correct parameters' do
      it 'should store parameters and return 201 Created' do
        payload = FactoryGirl.build(:openstack_infra).attributes
        post '/infrastructures', payload
        expect(last_response).to be
        expect(last_response.status).to eq(201)
        response = JSON.parse(last_response.body)
        expect(response.keys).to eq(FactoryGirl.build_stubbed(:openstack_infra).to_h.keys.map { |k| k.to_s })
      end
    end

    context 'When receive invalid parameters' do
      it 'should return response code 500' do
        allow(Infrastructure).to receive(:create!).and_raise
        post '/infrastructures'
        expect(last_response.status).to eq(500)
        response = JSON.parse(last_response.body)
        expect(response['message']).to eq(error_message)
      end
    end
  end

  describe 'GET /infrastructures/:id' do
    context 'When specified existing infrastructure' do
      before do
        @infra = FactoryGirl.create(:openstack_infra)
      end
      it 'should return 200 OK and infrastructure informations' do
        get "/infrastructures/#{@infra.id}"
        expect(last_response).to be
        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        expect(response.keys).to eq(@infra.to_h.keys.map { |k| k.to_s })
      end
    end

    context 'When does not found specified infrastructure' do
      it 'should return 404 Not Found' do
        get '/infrastructures/-1'
        expect(last_response).to be
        expect(last_response.status).to eq(500)
        response = JSON.parse(last_response.body)
        expect(response['message']).to eq(error_message)
      end
    end
  end

  describe 'GET /infrastructures' do
    context 'When success to get all infrastructures' do
      before do
        Infrastructure.destroy_all
        @infrastructures = (0..7).map do |i|
          # TODO: reconsider test parameters
          Infrastructure.create(
            name: "infra#{i}",
            driver: 'infra#{i}-driver',
            created_at: "2013-11-28 18:00:0#{i}",
            updated_at: "2013-11-28 18:00:0#{i}",
          )
        end
        @infrastructures.sort! { |a, b| b.created_at <=> a.created_at }
      end
      after do
        Infrastructure.destroy_all
      end

      it 'received request(page:1) and should be return 7..5 infrastructures data' do
        get '/infrastructures', page: 1, per_page: 3
        expect(last_response).to be
        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        expect(response['data'].size).to eq(3)
        response['data'].each_with_index do |infra, i|
          expect(infra['name']).to eq(@infrastructures[i].name)
        end
      end

      it 'received request(page:2) and should be return 4..2 infrastructures data' do
        get '/infrastructures', page: 2, per_page: 3
        expect(last_response).to be
        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        expect(response['data'].size).to eq(3)
        response['data'].each_with_index do |infra, i|
          expect(infra['name']).to eq(@infrastructures[i + 3].name)
        end
      end

      it 'received request(page:3) and should be return 1..0 infrastructures data' do
        get '/infrastructures', page: 3, per_page: 3
        expect(last_response).to be
        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        expect(response['data'].size).to eq(2)
        response['data'].each_with_index do |infra, i|
          expect(infra['name']).to eq(@infrastructures[i + 6].name)
        end
      end

      it 'received request(page:4) and should be return empty data' do
        get '/infrastructures', page: 4, per_page: 3
        expect(last_response).to be
        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        expect(response['total']).to eq(Infrastructure.count)
        expect(response['data']).to eq([])
      end
    end

    context 'When fail to get all infrastructures' do
      it 'should be return response code 500' do
        allow(Infrastructure).to receive(:all).and_return(nil)
        get '/infrastructures', page: 1, per_page: 3
        expect(last_response).to be
        expect(last_response.status).to eq(500)
        response = JSON.parse(last_response.body)
        expect(response['message']).to eq(error_message)
      end
    end
  end

  describe 'DELETE /infrastructures/:id' do
    context 'When success to delete specified infrastructure' do
      before do
        @infra = FactoryGirl.create(:openstack_infra)
      end
      it 'should be return response code 204' do
        delete "/infrastructures/#{@infra.id}"
        expect(last_response).to be
        expect(last_response.status).to eq(204)
      end
    end

    context 'When fail to get all infrastructures' do
      it 'should be return response code 500' do
        allow(Infrastructure).to receive(:find_by).and_raise
        delete '/infrastructures/-1'
        expect(last_response).to be
        expect(last_response.status).to eq(500)
        response = JSON.parse(last_response.body)
        expect(response['message']).to eq(error_message)
      end

      it 'is return response code 500' do
        infra = Infrastructure.new(
          id: '99',
          name: 'infrastructure name',
          driver: 'infrastructure driver'
        )
        allow(Infrastructure).to receive(:find_by).and_return(infra)
        allow(infra).to receive(:destroy!).and_raise('throw exeption.')
        delete '/infrastructures/99'
        expect(last_response).to be
        expect(last_response.status).to eq(500)
        response = JSON.parse(last_response.body)
        expect(response['message']).to eq(error_message)
      end
    end
  end

  describe 'POST /common_machine_configs' do
    context 'When receive correct parameters' do
      it 'should store parameters and return 201 Created' do
        payload = FactoryGirl.build(:small).attributes
        post '/common_machine_configs', payload
        expect(last_response).to be
        expect(last_response.status).to eq(201)
        response = JSON.parse(last_response.body)
        expect(response.keys).to eq(FactoryGirl.build_stubbed(:small).to_h.keys.map { |k| k.to_s })
      end
    end

    context 'When receive invalid parameters' do
      it 'should be return response code 500' do
        allow(CommonMachineConfig).to receive(:create!).and_raise
        post '/common_machine_configs'
        expect(last_response).to be
        expect(last_response.status).to eq(500)
        response = JSON.parse(last_response.body)
        expect(response['message']).to eq(error_message)
      end
    end
  end

  describe 'GET /common_machine_configs/:id' do
    context 'When specified existing common_machine_config' do
      before do
        @config = FactoryGirl.create(:small)
      end
      it 'should return 200 OK and common_machine_config informations' do
        get "/common_machine_configs/#{@config.id}"
        expect(last_response).to be
        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        expect(response.keys).to eq(@config.to_h.keys.map { |k| k.to_s })
      end
    end

    context 'When does not found specified common_machine_config' do
      it 'should be return response code 500' do
        get '/common_machine_configs/-1'
        expect(last_response).to be
        expect(last_response.status).to eq(500)
        response = JSON.parse(last_response.body)
        expect(response['message']).to eq(error_message)
      end
    end
  end

  describe 'GET /common_machine_configs' do
    context 'When success to get all common_machine_configs' do
      before do
        CommonMachineConfig.delete_all
        @configs = (0..7).map do |i|
          # TODO: reconsider test parameters
          CommonMachineConfig.create(
            name: "config#{i}",
            min_cpu: i + 1,
            min_memory: (i + 1) * 256,
            created_at: "2013-11-28 18:00:0#{i}",
            updated_at: "2013-11-28 18:00:0#{i}",
          )
        end
        @configs.sort! { |a, b| b.created_at <=> a.created_at }
      end
      after do
        CommonMachineConfig.destroy_all
      end

      it 'received request(page:1) and should be return 7..5 common_machine_configs data' do
        get '/common_machine_configs', page: 1, per_page: 3
        expect(last_response).to be
        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        expect(response['data'].size).to eq(3)
        response['data'].each_with_index do |config, i|
          expect(config['name']).to eq(@configs[i].name)
        end
      end

      it 'received request(page:2) and should be return 4..2 common_machine_configs data' do
        get '/common_machine_configs', page: 2, per_page: 3
        expect(last_response).to be
        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        expect(response['data'].size).to eq(3)
        response['data'].each_with_index do |config, i|
          expect(config['name']).to eq(@configs[i + 3].name)
        end
      end

      it 'received request(page:3) and should be return 1..0 common_machine_configs data' do
        get '/common_machine_configs', page: 3, per_page: 3
        expect(last_response).to be
        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        expect(response['data'].size).to eq(2)
        response['data'].each_with_index do |config, i|
          expect(config['name']).to eq(@configs[i + 6].name)
        end
      end

      it 'received request(page:4) and should be return empty data' do
        get '/common_machine_configs', page: 4, per_page: 3
        expect(last_response).to be
        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        expect(response['total']).to eq(CommonMachineConfig.count)
        expect(response['data']).to eq([])
      end
    end

    context 'When does not found specified common_machine_config' do
      it 'should be return response code 500' do
        allow(CommonMachineConfig).to receive(:all).and_return(nil)
        get '/common_machine_configs'
        expect(last_response).to be
        expect(last_response.status).to eq(500)
        response = JSON.parse(last_response.body)
        expect(response['message']).to eq(error_message)
      end
    end
  end

  describe 'DELETE /common_machine_configs' do
    context 'When success to delete specify common_machine_config' do
      before do
        @config = FactoryGirl.create(:small)
      end
      it 'should be return response code 204' do
        delete "/common_machine_configs/#{@config.id}"
        expect(last_response).to be
        expect(last_response.status).to eq(204)
      end
    end

    context 'When does not delete specified common_machine_config' do
      it 'should return response code 500' do
        delete '/common_machine_configs/-1'
        expect(last_response).to be
        expect(last_response.status).to eq(500)
        response = JSON.parse(last_response.body)
        expect(response['message']).to eq(error_message)
      end
    end
  end

  describe 'POST /common_machine_images' do
    context 'When receive correct parameters' do
      it 'should store parameters and return 201 Created' do
        payload = FactoryGirl.build(:centos).attributes
        post '/common_machine_images', payload
        expect(last_response).to be
        expect(last_response.status).to eq(201)
        response = JSON.parse(last_response.body)
        expect(response.keys).to eq(FactoryGirl.build_stubbed(:centos).to_h.keys.map { |k| k.to_s })
      end
    end

    context 'When receive invalid parameters' do
      it 'should return response code 500' do
        allow(CommonMachineImage).to receive(:create!).and_raise
        post '/common_machine_images'
        expect(last_response).to be
        expect(last_response.status).to eq(500)
        response = JSON.parse(last_response.body)
        expect(response['message']).to eq(error_message)
      end
    end
  end

  describe 'GET /common_machine_images/:id' do
    context 'When specified existing common_machine_image' do
      before do
        @image = FactoryGirl.create(:centos)
      end
      it 'should return 200 OK and common_machine_image informations' do
        get "/common_machine_images/#{@image.id}"
        expect(last_response).to be
        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        expect(response.keys).to eq(@image.to_h.keys.map { |k| k.to_s })
      end
    end

    context 'When receive invalid parameters' do
      it 'should return response code 500' do
        get '/common_machine_images/-1'
        expect(last_response).to be
        expect(last_response.status).to eq(500)
        response = JSON.parse(last_response.body)
        expect(response['message']).to eq(error_message)
      end
    end
  end

  describe 'GET /common_machine_images' do
    context 'When success to get all common_machine_images' do
      before do
        CommonMachineImage.delete_all
        @images = (0..7).map do |i|
          # TODO: reconsider test parameters
          CommonMachineImage.create(
            name: "image#{i}",
            os: "OS name#{i}",
            version: "10.#{i}",
            cpu_arch: 'x86_64',
            created_at: "2013-11-28 18:00:0#{i}",
            updated_at: "2013-11-28 18:00:0#{i}",
          )
        end
        @images.sort! { |a, b| b.created_at <=> a.created_at }
      end
      after do
        CommonMachineImage.destroy_all
      end

      it 'received request(page:1) and should be return 7..5 common_machine_images data' do
        get '/common_machine_images', page: 1, per_page: 3
        expect(last_response).to be
        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        expect(response['data'].size).to eq(3)
        response['data'].each_with_index do |image, i|
          expect(image['name']).to eq(@images[i].name)
        end
      end

      it 'received request(page:2) and should be return 4..2 common_machine_images data' do
        get '/common_machine_images', page: 2, per_page: 3
        expect(last_response).to be
        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        expect(response['data'].size).to eq(3)
        response['data'].each_with_index do |image, i|
          expect(image['name']).to eq(@images[i + 3].name)
        end
      end

      it 'received request(page:3) and should be return 1..0 common_machine_images data' do
        get '/common_machine_images', page: 3, per_page: 3
        expect(last_response).to be
        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        expect(response['data'].size).to eq(2)
        response['data'].each_with_index do |image, i|
          expect(image['name']).to eq(@images[i + 6].name)
        end
      end

      it 'received request(page:4) and should be return empty data' do
        get '/common_machine_images', page: 4, per_page: 3
        expect(last_response).to be
        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        expect(response['total']).to eq(CommonMachineImage.count)
        expect(response['data']).to eq([])
      end
    end

    context 'When receive invalid parameters' do
      it 'should return response code 500' do
        allow(CommonMachineImage).to receive(:all).and_return(nil)
        get '/common_machine_images'
        expect(last_response).to be
        expect(last_response.status).to eq(500)
        response = JSON.parse(last_response.body)
        expect(response['message']).to eq(error_message)
      end
    end
  end

  describe 'DELETE /common_machine_images' do
    context 'When success to delete all common_machine_images' do
      before do
        @image = FactoryGirl.create(:centos)
      end
      it 'should be return response code 204' do
        delete "/common_machine_images/#{@image.id}"
        expect(last_response).to be
        expect(last_response.status).to eq(204)
      end
    end

    context 'When receive invalid parameters' do
      it 'should return response code 500' do
        allow(CommonMachineImage).to receive(:find_by).and_return(nil)
        delete '/common_machine_images/-1'
        expect(last_response).to be
        expect(last_response.status).to eq(500)
        response = JSON.parse(last_response.body)
        expect(response['message']).to eq(error_message)
      end
    end
  end

  describe 'GET /system/:id/machine_filters' do
    context 'When specified machine_filter exists' do
      it 'should return 200 OK and machine_filter informations in no remote_machine_filter' do
        @machine_filter_group = FactoryGirl.create(:machine_filter_group_address)
        get "/systems/#{@machine_filter_group.system.id}/machine_filters"
        expect(last_response).to be
        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        expect(response['total']).to eq(@machine_filter_group.system.machine_filter_groups.count)
        filter = response['data'].first
        expect(filter['id']).to eq(@machine_filter_group.id)
        expect(filter['name']).to eq(@machine_filter_group.name)
        expect(filter['description']).to eq(@machine_filter_group.description)
        expect(filter['create_date']).to eq(@machine_filter_group.created_at.iso8601)
        expect(filter['update_date']).to eq(@machine_filter_group.updated_at.iso8601)
        rule = filter['machine_filter_rules'].first
        expect(rule['id']).to eq(@machine_filter_group.machine_filter_rule_groups.first.id)
        expect(rule['direction']).to eq(@machine_filter_group.machine_filter_rule_groups.first.direction)
        expect(rule['port_range_min']).to eq(@machine_filter_group
                                             .machine_filter_rule_groups.first.port_range_min)
        expect(rule['port_range_max']).to eq(@machine_filter_group
                                             .machine_filter_rule_groups.first.port_range_max)
        expect(rule['protocol']).to eq(@machine_filter_group.machine_filter_rule_groups.first.protocol)
        expect(rule['action']).to eq(@machine_filter_group.machine_filter_rule_groups.first.action)
        expect(rule['remote_machine_filter_group']).to be_nil
        expect(rule['remote_ip_address']).to eq(@machine_filter_group
                                                .machine_filter_rule_groups.first.remote_ip_address)
        expect(rule['create_date']).to eq(@machine_filter_group
                                         .machine_filter_rule_groups.first.created_at.iso8601)
        expect(rule['update_date']).to eq(@machine_filter_group
                                         .machine_filter_rule_groups.first.updated_at.iso8601)
      end
      it 'should return 200 OK and machine_filter informations in no remote_address' do
        @machine_filter_group = FactoryGirl.create(:machine_filter_group_filter)
        get "/systems/#{@machine_filter_group.system.id}/machine_filters"
        expect(last_response).to be
        expect(last_response.status).to eq(200)
        response = JSON.parse(last_response.body)
        expect(response['total']).to eq(@machine_filter_group.system.machine_filter_groups.count)
        filter = response['data'].first
        expect(filter['id']).to eq(@machine_filter_group.id)
        expect(filter['name']).to eq(@machine_filter_group.name)
        expect(filter['description']).to eq(@machine_filter_group.description)
        expect(filter['create_date']).to eq(@machine_filter_group.created_at.iso8601)
        expect(filter['update_date']).to eq(@machine_filter_group.updated_at.iso8601)
        rule = filter['machine_filter_rules'].first
        expect(rule['id']).to eq(@machine_filter_group.machine_filter_rule_groups.first.id)
        expect(rule['direction']).to eq(@machine_filter_group.machine_filter_rule_groups.first.direction)
        expect(rule['port_range_min']).to eq(@machine_filter_group
                                             .machine_filter_rule_groups.first.port_range_min)
        expect(rule['port_range_max']).to eq(@machine_filter_group
                                             .machine_filter_rule_groups.first.port_range_max)
        expect(rule['protocol']).to eq(@machine_filter_group.machine_filter_rule_groups.first.protocol)
        expect(rule['action']).to eq(@machine_filter_group.machine_filter_rule_groups.first.action)
        expect(rule['remote_machine_filter_group']).to eq(
          @machine_filter_group.machine_filter_rule_groups.first.remote_machine_filter_group_id)
        expect(rule['remote_ip_address']).to be_nil
        expect(rule['create_date']).to eq(@machine_filter_group
                                         .machine_filter_rule_groups.first.created_at.iso8601)
        expect(rule['update_date']).to eq(@machine_filter_group
                                         .machine_filter_rule_groups.first.updated_at.iso8601)
      end
    end

    context 'When receive invalid parameters' do
      it 'should return response code 500' do
        allow(System).to receive(:find_by).and_return(nil)
        get '/systems/-1/machine_filters'
        expect(last_response).to be
        expect(last_response.status).to eq(500)
        response = JSON.parse(last_response.body)
        expect(response['message']).to eq(error_message)
      end
    end
  end
end
