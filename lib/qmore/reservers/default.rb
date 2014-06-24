module Qmore::Reservers
  # @param [Enumerable] queues - qless queues to check for work
  class Default < Struct.new(:queues)
    def description
      @description ||= queues.collect(&:name).uniq.join(', ') + " (qmore)"
    end

    def prep_for_work!
      # nothing here on purpose
    end

    def reserve
      queues.each do |queue|
        if (job = queue.pop)
          return job
        end
      end
      nil
    end
  end
end
