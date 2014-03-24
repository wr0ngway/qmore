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
      realize_queues.each do |q|
        job = q.pop
        return job if job
      end

      nil
    end

    private

    def realize_queues
      realized_queues = []

      self.clients.keys.shuffle.each do |client|
        regexes = self.clients[client]
        # Cache the queues so we don't make multiple calls.
        actual_queues = client.queues

        # Grab all the actual queue names from the client.
        queue_names = actual_queues.counts.collect {|h| h['name'] }

        # Match the queue names against the regexes provided.
        matched_names = expand_queues(regexes, queue_names)

        # Prioritize the queues.
        prioritized_names = prioritize_queues(Qmore.configuration.priority_buckets, matched_names)

        # add the matched queues to the resulting list.
        realized_queues.concat(prioritized_names.collect {|name| actual_queues[name] })
      end

      realized_queues
    end
  end
end
