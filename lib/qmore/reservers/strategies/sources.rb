# This module provides the different kinds of queue sources used by qmore
module Qmore::Reservers::Strategies::Sources
  # Direct source uses a client to generate the queues we should
  # pull work from. Ignores any queues that do not have tasks available.
  def self.direct(client)
    Enumerator.new do |yielder|
      queues = client.queues.counts.select do |queue|
        %w(waiting recurring depends stalled scheduled).any? {|state| queue[state].to_i > 0 }
      end

      queues.each do |queue|
        yielder << client.queues[queue['name']]
      end
    end
  end

  # Background Queue source runs in a background thread
  # to periodically update the queues available.
  class Background
    include Enumerable
    attr_reader :delegate, :delay
    # @param [Enumerator] delegate queue source to load the queues from.
    # @param [Integer] delay - how long between updates
    def initialize(delegate, delay)
      @delegate = delegate
      @delay = delay
    end

    # Spawns a thread to periodically update the
    # queues.
    # @return [Thread] returns the spawned thread.
    def start
      @stop   = false
      @queues = delegate.to_a
      Thread.new do
        begin
          loop do
            sleep delay
            break if @stop
            @queues = delegate.to_a
          end
        rescue => e
          retry
        end
      end
    end

    def stop
      @stop = true
    end

    def each(&block)
      @queues.each { |q| block.call(q) }
    end
  end
end
