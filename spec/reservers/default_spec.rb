require "spec_helper"

describe "Reservers::Default" do
  before(:each) do
    Qmore.client.redis.flushall
    Qmore.configuration = Qmore::Configuration.new
  end

  it "can reserve from multiple queues" do
    high_queue = Qmore.client.queues['high']
    critical_queue = Qmore.client.queues['critical']

    high_queue.put(SomeJob, {})
    critical_queue.put(SomeJob, {})

    reserver = Qmore::Reservers::Default.new([critical_queue, high_queue])

    expect(reserver.reserve.queue.name).to eq('critical')
    expect(reserver.reserve.queue.name).to eq('high')
  end
end
