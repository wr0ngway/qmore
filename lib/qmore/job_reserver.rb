module Qmore
  class JobReserver
    include Qmore::Attributes
    # define queues for Qless worker to invoke.
    attr_reader :queues
    attr_reader :clients

    def initialize(queues)
      @queues = queues
      # Pull the regex off of the Qless::Queue#name, we want to keep the same interface
      # that Qless reservers use.
      @regexes = queues.collect(&:name).uniq
      @clients = {}
      queues.each do |q|
        @clients[q.client] ||= []
        @clients[q.client] << q.name
      end
    end

    def description
      @description ||= @regexes.join(', ') + " (qmore)"
    end

    def prep_for_work!
      # nothing here on purpose
    end

    def reserve
      self.clients.keys.shuffle.each do |client|
        self.extract_queues(client, self.clients[client]).each do |q|
          job = q.pop
          return job if job
        end
      end

      nil
    end

    # @param [Qless::Client] client - client to pull queues from.
    # @param [Array] regexes - array of regular expressions to match
    # queues against.
    def extract_queues(client, regexes)
      # Cache the queues so we don't make multiple calls.
      # and remove any queues that don't have work.
      actual_queues = client.queues.counts.reject do |queue|
        total = %w(waiting recurring depends throttled stalled scheduled).inject(0) { |sum, state| sum += queue[state].to_i }
        total == 0
      end

      # Grab all the actual queue names from the client.
      queue_names = actual_queues.collect {|h| h['name'] }

      # Match the queue names against the regexes provided.
      matched_names = expand_queues(regexes, queue_names)

      # Prioritize the queues.
      prioritized_names = prioritize_queues(Qmore.configuration.priority_buckets, matched_names)

      # collect the matched queues names in prioritized order.
      prioritized_names.collect {|name| client.queues[name] }
    end
  end
end
