module Qmore
  class JobReserver
    include Qmore::Attributes
    attr_reader :queues

    def initialize(queues)
      @queues = queues
    end

    def description
      @description ||= @queues.map(&:name).join(', ') + " (qmore)"
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
      queue_names = @queues.collect(&:name)
      real_queues = Qmore.client.queues.counts.collect {|h| h['name'] }
      
      realized_queues = expand_queues(queue_names, real_queues)
      realized_queues = prioritize_queues(get_priority_buckets, realized_queues)
      realized_queues = realized_queues.collect {|q| Qmore.client.queues[q] }
      realized_queues
    end
          
  end

end