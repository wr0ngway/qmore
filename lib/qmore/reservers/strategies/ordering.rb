module Qmore::Reservers::Strategies::Ordering
  # Shuffles the underlying enumerable
  # for each iteration.
  # @param [Enumerable] enumerable - underlying enumerator to iterate over
  def self.shuffled(enumerable)
    Enumerator.new do |yielder|
      enumerable.to_a.shuffle.each do |e|
        yielder << e
      end
    end
  end

  # Samples a subset of the underlying enumerable
  # for each iteration.
  # @param [Enumerable] enumerable - underlying enumerator to iterate over
  # @param [Integer] sample_size   - number of items to take per iteration
  def self.sampled(enumerable, sample_size = 5)
    Enumerator.new do |yielder|
      enumerable.to_a.sample(sample_size).each do |e|
        yielder << e
      end
    end
  end
end
