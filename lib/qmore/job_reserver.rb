module Qmore
  class JobReserver
    include Qmore::Attributes
    include Qmore::Util
    attr_reader :queues

    def initialize(queues)
      @queues = queues
    end

    def description
      set_description(realize_queues) unless @description
      @description
    end

    def prep_for_work!
      # nothing here on purpose
    end

    def reserve
      realize_queues.each do |q|
        job = q.pop
        if job
          set_description([job.queue])
          procline "Running #{description}"
          return job
        else
          set_description(realize_queues)
        end
      end

      nil
    end

    private

    def set_description(queue_names)
      @description = queue_names.map(&:name).join(', ')  + ' (qmore)'
    end

    def realize_queues
      queue_names = @queues.collect(&:name)
      real_queues = Qmore.client.queues.counts.collect {|h| h['name'] }

      realized_queues = expand_queues(queue_names, real_queues)
      realized_queues = prioritize_queues(get_priority_buckets, realized_queues)
      realized_queues = realized_queues.collect {|q| Qmore.client.queues[q] }
      realized_queues
    end
  end
end
