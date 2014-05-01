require "spec_helper"

describe "Qmore::Persistence::Monitor" do
  before(:each) do
    Qmore.client.redis.flushall
  end

  it "updates periodically based on the interval" do
    persistance = double("Qmore::Persistence::Redis")
    persistance.should_receive(:load).at_least(3)
    monitor = Qmore::Persistence::Monitor.new(persistance, 1)
    monitor.start
    sleep 4
    monitor.stop
  end
end

describe "Qmore::Persistence::Redis" do
  before(:each) do
    Qmore.client.redis.flushall
  end


  context "dynamic queues" do
    it "can read/write dynamic queues to redis" do
      queues = {
        "key_a" => ["foo"],
        "key_b" => ["bar"],
        "key_c" => ["foo", "bar"]
      }

      configuration = Qmore::Configuration.new
      configuration.dynamic_queues = queues
      persistance = Qmore::Persistence::Redis.new(Qmore.client.redis)
      persistance.write(configuration)

      actual_configuration = persistance.load

      configuration.dynamic_queues.should == actual_configuration.dynamic_queues
    end
  end

  context "priorities" do
    it "can read/write priorities to redis" do
      priorities = [{'pattern' => 'foo*', 'fairly' => false},{'pattern' => 'default', 'fairly' => false}]
      configuration = Qmore::Configuration.new
      configuration.priority_buckets = priorities

      persistance = Qmore::Persistence::Redis.new(Qmore.client.redis)
      persistance.write(configuration)

      actual_configuration = persistance.load
      configuration.priority_buckets.should == actual_configuration.priority_buckets
    end
  end
end

