require 'rspec'
RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = [:should, :expect]
  end
  config.mock_with :rspec do |c|
    c.syntax = [:should, :expect]
  end
end

require 'coveralls'
Coveralls.wear!

require 'qmore'

redis_configs_directory = File.join(File.dirname(File.expand_path(__FILE__)), "redis")
redis_configs = Dir.entries(redis_configs_directory).select{|f| !File.directory?(f) && f.end_with?(".conf")}

redis_configs.each do |config|
  redis_cmd = "redis-server #{redis_configs_directory}/#{config}"
  puts "Starting redis for testing at localhost..."
  puts `cd #{redis_configs_directory}; #{redis_cmd}`

  # Schedule the redis server for shutdown when tests are all finished.
  at_exit do
    redis_instance_name = config.chomp(".conf")
    puts 'Stopping redis'
    pid = File.read("#{redis_configs_directory}/#{redis_instance_name}.pid").to_i rescue nil
    system ("kill -9 #{pid}") if pid.to_i != 0
    File.delete("#{redis_configs_directory}/#{redis_instance_name}.pid") rescue nil
    File.delete("#{redis_configs_directory}/#{redis_instance_name}-server.log") rescue nil
    File.delete("#{redis_configs_directory}/#{redis_instance_name}-dump.rdb") rescue nil
  end
end

def dump_redis
  result = {}
  redis = Qmore.client.redis
  redis.keys("*").each do |key|
    type = redis.type(key)
    result["#{key} (#{type})"] = case type
      when 'string' then redis.get(key)
      when 'list' then redis.lrange(key, 0, -1)
      when 'zset' then redis.zrange(key, 0, -1, :with_scores => true)
      when 'set' then redis.smembers(key)
      when 'hash' then redis.hgetall(key)
      else type
    end
  end
  return result
end

class SomeJob
  def self.perform(*args)
  end
end
