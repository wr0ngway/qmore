require 'multi_json'

module Qmore
  DYNAMIC_QUEUE_KEY = "qmore:dynamic"
  PRIORITY_KEY = "qmore:priority"
  DYNAMIC_FALLBACK_KEY = "default"

  module Attributes
    extend self

    def redis
      Qmore.client.redis
    end
    
    def decode(data)
      MultiJson.load(data) if data
    end
    
    def encode(data)
      MultiJson.dump(data)
    end
    
    def get_dynamic_queue(key, fallback=['*'])
      data = redis.hget(DYNAMIC_QUEUE_KEY, key)
      queue_names = decode(data)

      if queue_names.nil? || queue_names.size == 0
        data = redis.hget(DYNAMIC_QUEUE_KEY, DYNAMIC_FALLBACK_KEY)
        queue_names = decode(data)
      end
      
      if queue_names.nil? || queue_names.size == 0
        queue_names = fallback
      end

      return queue_names
    end

    def set_dynamic_queue(key, values)
      if values.nil? or values.size == 0
        redis.hdel(DYNAMIC_QUEUE_KEY, key)
      else
        redis.hset(DYNAMIC_QUEUE_KEY, key, encode(values))
      end
    end
    
    def set_dynamic_queues(dynamic_queues)
      redis.multi do
        redis.del(DYNAMIC_QUEUE_KEY)
        dynamic_queues.each do |k, v|
          set_dynamic_queue(k, v)
        end
      end
    end

    def get_dynamic_queues
      result = {}
      queues = redis.hgetall(DYNAMIC_QUEUE_KEY)
      queues.each {|k, v| result[k] = decode(v) }
      result[DYNAMIC_FALLBACK_KEY] ||= ['*']
      return result
    end
    
    def get_priority_buckets
      priorities = Array(redis.lrange(PRIORITY_KEY, 0, -1))
      priorities = priorities.collect {|p| decode(p) }
      priorities << {'pattern' => 'default'} unless priorities.find {|b| b['pattern'] == 'default' }
      return priorities
    end

    def set_priority_buckets(data)
      redis.multi do
        redis.del(PRIORITY_KEY)
        Array(data).each do |v|
           redis.rpush(PRIORITY_KEY, encode(v))
        end
      end
    end

    # Returns a list of queues to use when searching for a job.
    #
    # A splat ("*") means you want every queue (in alpha order) - this
    # can be useful for dynamically adding new queues.
    #
    # The splat can also be used as a wildcard within a queue name,
    # e.g. "*high*", and negation can be indicated with a prefix of "!"
    #
    # An @key can be used to dynamically look up the queue list for key from redis.
    # If no key is supplied, it defaults to the worker's hostname, and wildcards
    # and negations can be used inside this dynamic queue list.   Set the queue
    # list for a key with set_dynamic_queue(key, ["q1", "q2"]
    #
    def expand_queues(queue_patterns, real_queues)
      queue_patterns = queue_patterns.dup
      real_queues = real_queues.dup
      
      matched_queues = []

      while q = queue_patterns.shift
        q = q.to_s

        if q =~ /^(!)?@(.*)/
          key = $2.strip
          key = Socket.gethostname if key.size == 0

          add_queues = get_dynamic_queue(key)
          add_queues.map! { |q| q.gsub!(/^!/, '') || q.gsub!(/^/, '!') } if $1

          queue_patterns.concat(add_queues)
          next
        end

        if q =~ /^!/
          negated = true
          q = q[1..-1]
        end

        patstr = q.gsub(/\*/, ".*")
        pattern = /^#{patstr}$/
        if negated
          matched_queues -= matched_queues.grep(pattern)
        else
          matches = real_queues.grep(/^#{pattern}$/)
          matches = [q] if matches.size == 0 && q == patstr
          matched_queues.concat(matches)
        end
      end

      return matched_queues.uniq.sort
    end

    def prioritize_queues(priority_buckets, real_queues)
      real_queues = real_queues.dup
      priority_buckets = priority_buckets.dup

      result = []
      default_idx = -1, default_fairly = false;

      # Walk the priority patterns, extract each into its own bucket
      priority_buckets.each do |bucket|
        bucket_pattern = bucket['pattern']
        fairly = bucket['fairly']

        # note the position of the default bucket for inserting the remaining queues at that location
        if bucket_pattern == 'default'
          default_idx = result.size
          default_fairly = fairly
          next
        end

        bucket_queues, remaining = [], []
        
        patterns = bucket_pattern.split(',')
        patterns.each do |pattern|
          pattern = pattern.strip
          
          if pattern =~ /^!/
            negated = true
            pattern = pattern[1..-1]
          end
          
          patstr = pattern.gsub(/\*/, ".*")
          pattern = /^#{patstr}$/
        
        
          if negated
            bucket_queues -= bucket_queues.grep(pattern)
          else
            bucket_queues.concat(real_queues.grep(pattern))
          end
        
        end
        
        bucket_queues.uniq!
        bucket_queues.shuffle! if fairly
        real_queues = real_queues - bucket_queues
        
        result << bucket_queues
        
      end

      # insert the remaining queues at the position the default item was at (or last)
      real_queues.shuffle! if default_fairly
      result.insert(default_idx, real_queues)
      result.flatten!

      return result
    end
    
  end
end
