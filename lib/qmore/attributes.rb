require 'multi_json'

module Qmore
  module Attributes
    extend self

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
        negated = false

        if q =~ /^(!)?@(.*)/
          key = $2.strip
          key = Socket.gethostname if key.size == 0

          add_queues = Qmore.configuration.dynamic_queues[key]
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
