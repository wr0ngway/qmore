require "spec_helper"

describe 'Reservers::Delegating' do
  before(:each) do
    Redis.connect(:port => 6380).flushall
    Qmore.client.redis.flushall
    Qmore.configuration = Qmore::Configuration.new
  end

  it 'should implement #queues' do
    qless1 = Qless::Client.new(:redis => Redis.connect(:port => 6379))
    qless2 = Qless::Client.new(:redis => Redis.connect(:port => 6380))
    queue_a = qless1.queues["a"]
    queue_b = qless2.queues["b"]

    job1 = queue_a.put(SomeJob, {})
    job2 = queue_b.put(SomeJob, {})

    expect(queue_a.length).to eq(1)
    expect(queue_b.length).to eq(1)

    reservers = []
    reservers << Qmore::Reservers::Default.new([queue_a])
    reservers << Qmore::Reservers::Default.new([queue_b])

    reserver = Qmore::Reservers::Delegating.new(reservers)

    queues = reserver.queues.to_a
    expect(queues).to include(queue_a)
    expect(queues).to include(queue_b)
  end

  it 'can delegate to multiple reservers' do
    qless1 = Qless::Client.new(:redis => Redis.connect(:port => 6379))
    qless2 = Qless::Client.new(:redis => Redis.connect(:port => 6380))
    queue_a = qless1.queues["a"]
    queue_b = qless2.queues["b"]

    job1 = queue_a.put(SomeJob, {})
    job2 = queue_b.put(SomeJob, {})

    expect(queue_a.length).to eq(1)
    expect(queue_b.length).to eq(1)

    reserver1 = Qmore::Reservers::Default.new([queue_a])
    reserver2 = Qmore::Reservers::Default.new([queue_b])

    reserver = Qmore::Reservers::Delegating.new([reserver1, reserver2])
    expect(reserver.reserve.queue.name).to eq('a')
    expect(reserver.reserve.queue.name).to eq('b')
  end

  context 'with ordering' do
    it 'should work with ordering strategy' do
      qless1 = Qless::Client.new(:redis => Redis.connect(:port => 6379))
      qless2 = Qless::Client.new(:redis => Redis.connect(:port => 6380))
      queue_a = qless1.queues["a"]
      queue_b = qless2.queues["b"]

      job1 = queue_a.put(SomeJob, {})
      job2 = queue_b.put(SomeJob, {})

      expect(queue_a.length).to eq(1)
      expect(queue_b.length).to eq(1)

      reservers = []
      reservers << Qmore::Reservers::Default.new([queue_a])
      reservers << Qmore::Reservers::Default.new([queue_b])

      reservers = Qmore::Reservers::Strategies::Ordering.shuffled(reservers)
      reserver = Qmore::Reservers::Delegating.new(reservers)

      expected = ['a', 'b']
      expected.delete(reserver.reserve.queue.name)
      expected.delete(reserver.reserve.queue.name)
      expect(expected).to be_empty
    end
  end
end
