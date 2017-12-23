require "rubygems"
require "sinatra/base"
require "redis"
require 'sunspot'
require 'elasticsearch'
require 'mongo'
require 'bunny'
require 'platform_sh'
require 'json'
require "influxdb"

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
      message ="#{RUBY_VERSION}"
      redis = Redis.new
      redis.set("mykey", "hello world")
      redis.get("mykey")
      message+= "Redis Succesful"
      begin
        redis.client :getname
        message+= "Redis Client Command successful"
      rescue Exception => e
        status = 0
        message+="#{e.message}"
        message+="#{e.backtrace.inspect}"
        # => Timed out connecting to Redis on 10.0.1.1:6380
      end
      session = Sunspot::Session.new
      session.config.solr.url=ENV['SOLR_URL'] #rsolr not taking in url
      session.commit
      message+= "Solr successful"

      name     = 'foobar'
      database = 'baz'

      username = 'foobar'
      password = 'pwd'
      begin

        influxdb = InfluxDB::Client.new url: ENV['INFLUXDB_URL']
        influxdb.create_cluster_admin(username, password)
        influxdb.config.username = username
        influxdb.config.password = password
        influxdb.create_database(database)
        influxdb.config.database = database
      
        # Enumerator that emits a sine wave
        Value = (0..10).to_a.map {|i| Math.send(:sin, i / 10.0) * 10 }.each

        loop do
          data = {
            values: { value: Value.next },
            tags:   { wave: 'sine' } # tags are optional
          }

          influxdb.write_point(name, data)

          sleep 1
        end
        message+= "InfluxDB successful"
      rescue
        message+= "InfluxDB Not implemented"
      end

      client = Elasticsearch::Client.new log: true
      client.cluster.health
      client.search q: 'test'
      message+= "Elasticsearch successful"
      
      client = Mongo::Client.new(ENV['MONGODB_URL']) #mongodb not taking in url
      db = client.database
      db.collection_names
      message+= "Mongo successful"
      
      conn = Bunny.new
      conn.start
      ch = conn.create_channel
      q  = ch.queue("test1")
      q.publish("Hello, everybody!")
      delivery_info, metadata, payload = q.pop

      message+=  "RabbitMQ successful"
      conn.stop
    rescue Exception => e
      status = 0
      message+="#{e.message}"
      message+= e.backtrace.inspect
    end
    {status: 1, message: message}.to_json
  end

end
