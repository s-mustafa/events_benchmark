require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"
  gem "activerecord", "~> 7.0"
  gem "logger", "~> 1.5"
  gem "pg", "~> 1.4"
  gem "rdkafka", "~> 0.12.0"
  gem "redis", "~> 5.0"
end

require "active_record"
require "logger"
require "redis"
require "benchmark"

LOGGER = Logger.new(STDOUT)
LOGGER.level = Logger::WARN
REDIS = Redis.new
config = { "bootstrap.servers": "localhost:9092" }
PRODUCER = Rdkafka::Config.new(config).producer

ActiveRecord::Base.establish_connection(
  adapter: "postgresql",
  database: "testdb",
  host: "localhost",
  port: 5432,
  username: "postgres",
  password: "password"
)

class Event < ActiveRecord::Base
end

def write_redis
  100.times do |i|
    REDIS.set("test_event_#{i}", "{#{i}: 'This is a test payload'}")
  end
end

def write_db
  100.times do |i|
    Event.create(
      name: "test_event #{i}",
      payload: "{#{i}: 'This is a test payload'}"
    )
  end
end

def write_kafka
  delivery_handles = []
  100.times do |i|
    delivery_handles << PRODUCER.produce(
      topic: "events",
      payload: "This is a test payload #{i}",
      key: "test_event_#{i}"
    )
  end
  delivery_handles.each(&:wait)
end

def write_logs
  100.times { |i| LOGGER.debug("event #{i} data='This is a test payload'") }
end

Benchmark.bm do |x|
  x.report { write_db }
  x.report { write_redis }
  x.report { write_kafka }
  x.report { write_logs }
end
