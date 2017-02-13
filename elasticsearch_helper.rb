require 'elasticsearch'

class ElasticsearchService
  attr_reader :client

  def initialize(host, port)
    @client = Elasticsearch::Client.new(host: host, port: port)
  end

  def index_exists?(name)
    client.indices.exists?(index: name)
  end

  def create_index!(name)
    client.indices.create(index: name)
  end

  def delete_index!(name)
    client.indices.delete(index: name)
  end
end
