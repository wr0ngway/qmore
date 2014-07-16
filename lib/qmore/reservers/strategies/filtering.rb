module Qmore::Reservers::Strategies
  module Filtering
    extend Qmore::Attributes
    # @param [Enumerable] queues - a source of queues
    # @param [Array] regexes - a list of regexes to match against.
    # Return an enumerator of the filtered queues in
    # in prioritized order.
    def self.default(queues, regexes)
      Enumerator.new do |yielder|
        # Map queues to their names
        mapped_queues = queues.reduce({}) do |hash,queue|
          hash[queue.name] = queue
          hash
        end

        # Filter the queue names against the regexes provided.
        matches = Filtering.expand_queues(regexes, mapped_queues.keys)

        # Prioritize the queues.
        prioritized_names = Filtering.prioritize_queues(Qmore.configuration.priority_buckets, matches)

        prioritized_names.each do |name|
          queue = mapped_queues[name]
          if queue
            yielder << queue
          end
        end
      end
    end
  end
end
