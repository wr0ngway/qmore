require "spec_helper"

describe "Reservers::Strategies::Ordering" do
  before(:each) do
    Qmore.client.redis.flushall
    Qmore.configuration = Qmore::Configuration.new
  end

  context 'shuffled order' do
    it 'should return all items in a shuffled order' do
      input = [1,2,3,4,5,6,7,8]
      ordering = Qmore::Reservers::Strategies::Ordering.shuffled(input)

      round1 = ordering.to_a
      round2 = ordering.to_a

      expect(round1).not_to eq(input)
      expect(round2).not_to eq(input)
      expect(round1).not_to eq(round2)

      input.each do |element|
        expect(round1).to include(element)
        expect(round2).to include(element)
      end
    end
  end

  context 'sampled subset' do
    it 'should return the specified number of elements' do
      input = [1,2,3,4,5,6,7,8]
      ordering = Qmore::Reservers::Strategies::Ordering.sampled(input, 4)

      round1 = ordering.to_a
      round2 = ordering.to_a

      expect(round1.length).to be(4)
      expect(round2.length).to be(4)

      expect(round1).not_to eq(round2)
    end
  end
end
