require 'sinatra'
require 'yaml'
require 'json'
require_relative './elasticsearch_helper'

class ElasticsearchBroker < Sinatra::Base
  def initialize
    super

    settings_filename = defined?(SETTINGS_FILENAME) ? SETTINGS_FILENAME : 'config/settings.yml'
    @settings = YAML.load_file(settings_filename)
    @elasticsearch_settings = @settings.fetch('elasticsearch')
    @credentials = @settings.fetch('basic_auth')
  end

  def protected!
    return if authorized?
    headers['WWW-Authenticate'] = 'Basic realm="Restricted Area"'
    halt 401, "Not authorized\n"
  end

  def authorized?
    @auth = Rack::Auth::Basic::Request.new(request.env)
    @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == [@credentials.fetch('username'), @credentials.fetch('password')]
  end

  get '/v2/catalog' do
    protected!
    @settings.fetch('catalog').to_json
  end

  put '/v2/service_instances/:id' do |id|
    if elasticsearch_service.index_exists?(index_name(id))
      status 409
      { 'description' => 'Index already exists' }.to_json
    else
      elasticsearch_service.create_index!(index_name(id))
      status 201
      { 'dashboard_url' => "http://#{@elasticsearch_settings.fetch('host')}:#{@elasticsearch_settings.fetch('port')}/#{index_name(id)}" }.to_json
    end
  end

  put '/v2/service_instances/:instance_id/service_bindings/:id' do
    instance_id = params[:instance_id] # index name

    uri = "http://#{@elasticsearch_settings.fetch('host')}:#{@elasticsearch_settings.fetch('port')}/#{index_name(instance_id)}"
    credentials = {
      uri: uri, hostname: @elasticsearch_settings.fetch('host').to_s,
      port: @elasticsearch_settings.fetch('port').to_s, index: index_name(instance_id)
    }

    status 201
    { 'credentials' => credentials }.to_json
  end

  delete '/v2/service_instances/:instance_id/service_bindings/:id' do
    instance_id = params[:instance_id] # index name
    binding_id = params[:id]

    if elasticsearch_service.index_exists?(index_name(instance_id))

      status 200
      {}.to_json
    else
      status 410
      { description: "The binding #{binding_id} doesn't exist" }.to_json
    end
  end

  delete '/v2/service_instances/:id' do |id|
    if elasticsearch_service.index_exists?(index_name(id))
      elasticsearch_service.delete_index!(index_name(id))

      status 200
      {}.to_json
    else
      status 410
      { description: "The index #{index_name(id)} doesn't exist" }.to_json
    end
  end

  private

  def elasticsearch_service
    ElasticsearchService.new(@elasticsearch_settings.fetch('host'),
                             @elasticsearch_settings.fetch('port'))
  end

  def index_name(id)
    "cf-#{id}"
  end
end
