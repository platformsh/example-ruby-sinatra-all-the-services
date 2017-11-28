require "rubygems"
require "sinatra/base"
require "redis"
require 'sunspot'
require 'elasticsearch'
require 'mongo'
require 'bunny'
require 'platform_sh'
require 'json'

class Main < Sinatra::Base
  configure do
    if PlatformSH::on_platform?
      PlatformSH::export_services_urls
    end
  end

  get '/' do
    content_type :json
    begin
      status = 1
      message ="#{RUBY_VERSION}<br>"
      redis = Redis.new
      redis.set("mykey", "hello world")
      redis.get("mykey")
      message+= "Redis Succesful<br>"
      begin
        redis.client :getname
        message+= "Redis Client Command successful<br>"
      rescue Exception => e
        status = 0
        message+="#{e.message}<br>"
        message+="#{e.backtrace.inspect}<br>"
        # => Timed out connecting to Redis on 10.0.1.1:6380
      end
      session = Sunspot::Session.new
      session.config.solr.url=ENV['SOLR_URL'] #rsolr not taking in url
      session.commit
      message+= "Solr successful<br>"

      client = Elasticsearch::Client.new log: true
      client.cluster.health
      client.search q: 'test'
      message+= "Elasticsearch successful<br>"
      
      client = Mongo::Client.new(ENV['MONGODB_URL']) #mongodb not taking in url
      db = client.database
      db.collection_names
      message+= "Mongo successful<br>"
      
      conn = Bunny.new
      conn.start
      ch = conn.create_channel
      q  = ch.queue("test1")
      q.publish("Hello, everybody!")
      delivery_info, metadata, payload = q.pop

      message+=  "RabbitMQ successful<br>"
      conn.stop
    rescue Exception => e
      status = 0
      message+="#{e.message}<br>"
      message+= e.backtrace.inspect
    end
    {status: 1, message: message}.to_json
  end

end
