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
require 'bundler/setup'
require_relative 'src/helpers/log'
Bundler.require
require 'sinatra/reloader' if development?

use Rack::Parser, parsers: { 'application/json' => proc { |data| JSON.parse(data) } }

before do
  content_type 'application/json'
end

error do
  status = env['sinatra.error'].respond_to?('code') ? env['sinatra.error'].code : 500
  Log.error(Log.format_exception(env['sinatra.error']))
  status status
  json message: 'Error Occured!! Please contact your system administrator.'
end

post '/systems' do
  begin
    system = System.create!(
      name: params[:user_input_keys][:name],
      description: params[:user_input_keys][:description],
      template_uri: params[:template_xml_uri],
      template_xml: params[:template_xml],
      meta_xml: params[:meta_xml],
      user_parameters: JSON.generate(params[:user_input_keys]),
      cloud_relation_parameters: JSON.generate(params[:cloud_entry_points])
    )
    system.deploy
    status 202
    json system.to_h
  rescue
    Log.error("[post /systems] Failed to create system with #{params}")
    raise
  end
end

get '/systems' do
  begin
    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 10).to_i
    systems = System.order('created_at DESC').page(page).per(per_page)
    status 200
    json(
      total: System.count,
      data: systems.map { |system| system.to_h }
    )
  rescue
    Log.error('[get /systems] Failed to get system list.')
    raise
  end
end

get '/systems/:id' do
  begin
    system = System.find_by(id: params[:id])
    fail unless system
    status 200
    json system.to_h
  rescue
    Log.error("[get /systems/:id] Failed to get System #{params}")
    raise
  end
end

get '/systems/:id/machine_groups' do
  begin
    system = System.find_by(id: params[:id])
    status 200
    json system.machine_groups.map { |machine_group| machine_group.to_h }
  rescue
    Log.error("[get /systems/:id/machine_groups] Failed to get machine_groups in System #{params}")
    raise
  end
end

get '/systems/:id/machines' do
  begin
    system = System.find_by(id: params[:id])
    machine_groups = system.machine_groups
    machines = machine_groups ? machine_groups.reduce([]) { |array, group| array + group.machines } : []
    status 200
    json(
      total: machines.size,
      data: machines.map { |machine| machine.to_h }
    )
  rescue
    Log.error("[get /systems/:id/machines] Failed to get machines in System #{params}")
    raise
  end
end

get '/systems/:id/networks' do
  begin
    system = System.find_by(id: params[:id])
    network_groups = system.network_groups
    status 200
    json(
      total: network_groups.size,
      data: network_groups.map { |network_group| network_group.to_h }
    )
  rescue
    Log.error("[get /systems/:id/networks] Failed to get networks in System #{params}")
    raise
  end
end

post '/systems/:id/applications' do
  begin
    application = Application.create!(
      system_id: params[:id],
      name: ConductorConfig.application_name
    )
    status 201
    json application.to_h
  rescue
    Log.error("[get /systems/:id/applications] Failed to create Application in System #{params}")
    raise
  end
end

get '/systems/:id/applications' do
  begin
    system = System.find_by(id: params[:id])
    applications = system.applications
    status 200
    json(
      total: applications.size,
      data: applications.map { |app| app.to_h }
    )
  rescue
    Log.error("[get /systems/:id/applications] Failed to get Applications in System #{params}")
    raise
  end
end

get '/systems/:id/applications/:application_id' do
  begin
    system = System.find_by(id: params[:id])
    application = system.applications.find { |app| app.id == params[:application_id].to_i }
    status 200
    json application.to_h
  rescue
    Log.error("[get /systems/:id/applications/:application_id] Failed to get Application with id in System #{params}")
    raise
  end
end

post '/systems/:id/applications/:application_id/application_files' do
  begin
    application = Application.find_by(
      id: params[:application_id],
      system: System.find_by(id: params[:id])
    )
    fail unless application
    file = ApplicationFile.create!(
      name: params[:file][:filename],
      application_id: application.id,
      machine_group_id: params[:machine_group_id],
      path: params[:file][:tempfile].path,
    )
    status 201
    json(
      id: file.id,
      name: file.name,
      version: file.version,
    )
  rescue
    Log.error("[post /systems/:id/applications/:application_id/application_files] Failed to create ApplicationFile with #{params}")
    raise
  end
end

get '/systems/:id/applications/:application_id/application_files' do
  begin
    application = Application.find_by(
      id: params[:application_id],
      system_id: params[:id]
    )
    files = application.application_files
    status 200
    json(
      total: files.size,
      data: files.map { |file| file.to_h }
    )
  rescue
    Log.error("[get /systems/:id/applications/:application_id/application_files] Failed to get ApplicationFile with #{params}")
    raise
  end
end

post '/systems/:id/applications/:application_id/deploy' do
  begin
    app = Application.find_by(
      id: params[:application_id],
      system_id: params[:id]
    )
    app.deploy
    status 200
    json(app.to_h)
  rescue
    Log.error("[post /systems/:id/applications/:application_id/application_files] Failed to Application deploy with #{params}")
    raise
  end
end

delete '/systems/:id/applications/:application_id/application_files/:application_file_id' do
  begin
    application = Application.find_by(
      id: params[:application_id],
      system_id: params[:id]
    )
    file = ApplicationFile.find_by(
      id: params[:application_file_id],
      application_id: application.id
    )
    file.destroy
    status 204
  rescue
    Log.error("[delete /systems/:id/applications/:application_id/application_files] Failed to delete ApplicationFile with #{params}")
    raise
  end
end

post '/cloud_entry_points' do
  begin
    cloud = CloudEntryPoint.create!(params)
    status 201
    json cloud.to_h
  rescue
    Log.error("[post /cloud_entry_points] Failed to create cloud_entry_point with #{params}")
    raise
  end
end

get '/cloud_entry_points' do
  begin
    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 10).to_i
    clouds = CloudEntryPoint.order('created_at DESC').page(page).per(per_page)
    status 200
    json(
      total: CloudEntryPoint.count,
      data: clouds.map { |cloud| cloud.to_h },
    )
  rescue
    Log.error("[get /cloud_entry_points] Failed to get cloud_entry_points with #{params}")
    raise
  end
end

get '/cloud_entry_points/:id' do
  begin
    cloud = CloudEntryPoint.find_by(id: params[:id])
    fail unless cloud
    status 200
    json cloud.to_h
  rescue
    Log.error("[get /cloud_entry_points/:id] Failed to get cloud_entry_point#{params}")
    raise
  end
end

put '/cloud_entry_points/:id' do
  begin
    cloud = CloudEntryPoint.find_by(id: params[:id])
    attributes = params.select { |key, value| CloudEntryPoint.attribute_names.include?(key) && key != :id }
    cloud.update_attributes!(attributes)
    status 200
    json cloud.to_h
  rescue
    Log.error("[put /cloud_entry_points/:id] Failed to put cloud_entry_point with #{params}")
    raise
  end
end

delete '/cloud_entry_points/:id' do
  begin
    cloud = CloudEntryPoint.find_by(id: params[:id])
    cloud.destroy!
    status 204
  rescue
    Log.error("[delete /cloud_entry_points/:id] Failed to delete cloud_entry_point with #{params}")
    raise
  end
end

post '/infrastructures' do
  begin
    infra = Infrastructure.create!(params)
    status 201
    json infra.to_h
  rescue
    Log.error("[post /infrastructures] Failed to create infrastructure with #{params}")
    raise
  end
end

get '/infrastructures/:id' do
  begin
    infra = Infrastructure.find_by(id: params[:id])
    fail unless infra
    status 200
    json infra.to_h
  rescue
    Log.error("[get /infrastructures/:id] Failed to get infrastructure with #{params}")
    raise
  end
end

get '/infrastructures' do
  begin
    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 10).to_i
    infrastructures = Infrastructure.order('created_at DESC').page(page).per(per_page)
    status 200
    json(
      total: Infrastructure.count,
      data: infrastructures.map { |infra| infra.to_h },
    )
  rescue
    Log.error("[get /infrastructures] Failed to get infrastructures with #{params}")
    raise
  end
end

delete '/infrastructures/:id' do
  begin
    infra = Infrastructure.find_by(id: params[:id])
    infra.destroy!
    status 204
  rescue
    Log.error("[delete /infrastructures] Failed to delete infrastructure with #{params}")
    raise
  end
end

post '/common_machine_configs' do
  begin
    config = CommonMachineConfig.create!(params)
    status 201
    json config.to_h
  rescue
    Log.error("[post /common_machine_configs] Failed to create common_machine_config with #{params}")
    raise
  end
end

get '/common_machine_configs/:id' do
  begin
    config = CommonMachineConfig.find_by(id: params[:id])
    fail unless config
    status 200
    json config.to_h
  rescue
    Log.error("[get /common_machine_configs/:id] Failed to get common_machine_config with #{params}")
    raise
  end
end

get '/common_machine_configs' do
  begin
    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 10).to_i
    configs = CommonMachineConfig.order('created_at DESC').page(page).per(per_page)
    status 200
    json(
      total: CommonMachineConfig.count,
      data: configs.map { |config| config.to_h },
    )
  rescue
    Log.error("[get /common_machine_configs] Failed to get common_machine_configs with #{params}")
    raise
  end
end

delete '/common_machine_configs/:id' do
  begin
    config = CommonMachineConfig.find_by(id: params[:id])
    config.destroy!
    status 204
  rescue
    Log.error("[delete /common_machine_configs/:id] Failed to delete common_machine_config with #{params}")
    raise
  end
end

post '/common_machine_images' do
  begin
    image = CommonMachineImage.create!(params)
    status 201
    json image.to_h
  rescue
    Log.error("[post /common_machine_images] Failed to post common_machine_image with #{params}")
    raise
  end
end

get '/common_machine_images/:id' do
  begin
    image = CommonMachineImage.find_by(id: params[:id])
    fail unless image
    status 200
    json image.to_h
  rescue
    Log.error("[get /common_machine_images/:id] Failed to get common_machine_image with #{params}")
    raise
  end
end

get '/common_machine_images' do
  begin
    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 10).to_i
    images = CommonMachineImage.order('created_at DESC').page(page).per(per_page)
    status 200
    json(
      total: CommonMachineImage.count,
      data: images.map { |image| image.to_h },
    )
  rescue
    Log.error("[get /common_machine_images] Failed to get all common_machine_images with #{params}")
    raise
  end
end

delete '/common_machine_images/:id' do
  begin
    image = CommonMachineImage.find_by(id: params[:id])
    image.destroy!
    status 204
  rescue
    Log.error("[delete /common_machine_images/:id] Failed to delete common_machine_image with #{params}")
    raise
  end
end

get '/systems/:id/machine_filters' do
  begin
    system = System.find_by(id: params[:id])
    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 10).to_i
    system = System.find_by(id: params[:id])
    machine_filter_groups = system.machine_filter_groups.order('created_at DESC').page(page).per(per_page)
    status 200
    json(
      total: machine_filter_groups.size,
      data: machine_filter_groups.map { |filter| filter.to_h }
    )
  rescue
    Log.error("[get /common_machine_images] Failed to get all common_machine_images with #{params}")
    raise
  end
end
