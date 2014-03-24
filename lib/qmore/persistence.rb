module Qmore::Persistence
  class Monitor
    attr_reader :updating, :interval
    # @param [Qmore::persistence] persistence - responsible for reading the configuration
    # from some source (redis, file, db, etc)
    # @param [Integer] interval - the period, in seconds, to wait between updates to the configuration.
    # defaults to 1 minute
    def initialize(persistence, interval)
      @persistence = persistence
      @interval = interval
    end

    def start
      return if @updating
      @updating = true

      # Ensure we load the configuration once from persistence before
      # the background thread.
      Qmore.configuration = @persistence.load

      Thread.new do
        while(@updating) do
          sleep @interval
          Qmore.configuration = @persistence.load
        end
      end
    end

    def stop
      @updating = false
    end
  end

  class Redis
    DYNAMIC_QUEUE_KEY = "qmore:dynamic".freeze
    PRIORITY_KEY = "qmore:priority".freeze

    attr_reader :redis

    def initialize(redis)
      @redis = redis
    end

    def decode(data)
      MultiJson.load(data) if data
    end

    def encode(data)
      MultiJson.dump(data)
    end

    # Returns a Qmore::Configuration from the underlying data storage mechanism
    # @return [Qmore::Configuration]
    def load
      configuration = Qmore::Configuration.new
      configuration.dynamic_queues = self.read_dynamic_queues
      configuration.priority_buckets = self.read_priority_buckets
      configuration
    end

    # Writes out the configuration to the underlying data storage mechanism.
    # @param[Qmore::Configuration] configuration to be persisted
    def write(configuration)
      write_dynamic_queues(configuration.dynamic_queues)
      write_priority_buckets(configuration.priority_buckets)
    end

    def read_dynamic_queues
      result = {}
      queues = redis.hgetall(DYNAMIC_QUEUE_KEY)
      queues.each {|k, v| result[k] = decode(v) }
      return result
    end

    def read_priority_buckets
      priorities = Array(redis.lrange(PRIORITY_KEY, 0, -1))
      priorities = priorities.collect {|p| decode(p) }
      return priorities
    end

    def write_priority_buckets(data)
      redis.multi do
        redis.del(PRIORITY_KEY)
        Array(data).each do |v|
           redis.rpush(PRIORITY_KEY, encode(v))
        end
      end
    end

    def write_dynamic_queues(dynamic_queues)
      redis.multi do
        redis.del(DYNAMIC_QUEUE_KEY)
        dynamic_queues.each do |k, v|
          redis.hset(DYNAMIC_QUEUE_KEY, k, encode(v))
        end
      end
    end
  end
end
