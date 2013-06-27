require 'rspec'
require 'qmore'

# No need to start redis when running in Travis
unless ENV['CI']

  begin
    Qmore.client.queues.counts
  rescue Errno::ECONNREFUSED
    spec_dir = File.dirname(File.expand_path(__FILE__))
    REDIS_CMD = "redis-server #{spec_dir}/redis-test.conf"
    
    puts "Starting redis for testing at localhost..."
    puts `cd #{spec_dir}; #{REDIS_CMD}`
    
    # Schedule the redis server for shutdown when tests are all finished.
    at_exit do
      puts 'Stopping redis'
      pid = File.read("#{spec_dir}/redis.pid").to_i rescue nil
      system ("kill -9 #{pid}") if pid.to_i != 0
      File.delete("#{spec_dir}/redis.pid") rescue nil
      File.delete("#{spec_dir}/redis-server.log") rescue nil
      File.delete("#{spec_dir}/dump.rdb") rescue nil
    end
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
