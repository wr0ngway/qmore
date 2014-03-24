module Qmore
  class Configuration
    DYNAMIC_FALLBACK_KEY = "default".freeze

    attr_accessor :dynamic_queues, :priority_buckets

    def initialize
      # Initialize the dynamic queues
      self.dynamic_queues = {}
      self.priority_buckets = []
    end

    def dynamic_queues=(hash)
      queues = DynamicQueueHash.new
      queues[DYNAMIC_FALLBACK_KEY] = ['*']
      hash.each do |key, values|
        queues[key] = values
      end
      @dynamic_queues = queues
    end

    # @param [Array] priorities
    def priority_buckets=(priorities)
      priorities << {'pattern' => 'default'} unless priorities.find {|b| b['pattern'] == 'default' }
      @priority_buckets = priorities
    end

    private

    class DynamicQueueHash < Hash
      # @param key [String]
      # @param values [Array]
      def []=(key,values)
        # remove any keys that have been set to empty hash or nil.
        if values.nil? || values.size == 0
          self.delete(key)
          return
        end

        super
      end

      def [](key)
        super(key) || super(DYNAMIC_FALLBACK_KEY)
      end
    end
  end
end
