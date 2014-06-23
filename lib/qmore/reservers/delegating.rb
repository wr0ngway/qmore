module Qmore::Reservers
  # @param [Enumerable] reservers - a set of reservers
  # to check for work.
  class Delegating < Struct.new(:reservers)
    def description
      "Delegating Reserver"
    end

    def prep_for_work!
      # nothing here on purpose
    end

    def queues
      Enumerator.new do |yielder|
        reservers.each do |reserver|
          reserver.queues.each {|queue| yielder << queue}
        end
      end
    end

    def reserve
      reservers.each do |reserver|
        if (job = reserver.reserve)
          return job
        end
      end
      nil
    end
  end
end
