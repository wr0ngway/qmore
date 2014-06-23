require "spec_helper"

describe "JobReserver" do
  include Qmore::Attributes

  before(:each) do
    Qmore.client.redis.flushall
    Qmore.configuration = Qmore::Configuration.new
  end

  context "multiple qless server environment" do
    it "can reserve jobs from regex queue names on multiple clients" do
      qless1 = Qless::Client.new(:redis => Redis.connect(:port => 6379))
      qless2 = Qless::Client.new(:redis => Redis.connect(:port => 6380))
      queue_a = qless1.queues["a"]
      queue_b = qless2.queues["b"]
      queue_a.put(SomeJob, {})
      queue_b.put(SomeJob, {})

      queue_a.length.should == 1
      queue_b.length.should == 1

      reserver = Qmore::JobReserver.new([qless1.queues["*"], qless2.queues["*"]])
      worker = Qless::Worker.new(reserver, :run_as_single_process => true)
      worker.work(0)

      queue_a.length.should == 0
      queue_b.length.should == 0
    end

    it "shuffles the order of the clients" do
      queue = Qmore.client.queues['queue']

      reserver = Qmore::JobReserver.new([queue])
      k = reserver.clients.keys
      k.should_receive(:shuffle).once.and_return(reserver.clients.keys)
      reserver.clients.should_receive(:keys).and_return(k)
      reserver.reserve
    end
  end

  context "basic qless behavior still works" do
    it "ignores queues that have no work available" do
      no_work_queue = Qmore.client.queues['no-work']
      has_work_queue = Qmore.client.queues['has-work']

      no_work_queue.put(SomeJob, {})
      has_work_queue.put(SomeJob, {})

      # drain the no work queue
      no_work_queue.pop

      reserver = Qmore::JobReserver.new([no_work_queue, has_work_queue])

      queues = reserver.extract_queues(Qmore.client, ["*"]).collect(&:name)
      queues.should include("has-work")
      queues.should_not include("no-work")
    end

    it "should not ignore queues that have work in scheduled state" do
      work_queue = Qmore.client.queues['work']
      work_queue.put(SomeJob, {}, {:delay => 1600})

      %w(waiting recurring depends stalled).each do |state|
        work_queue.counts[state].should equal(0)
      end
      work_queue.counts["scheduled"].should equal(1)

      reserver = Qmore::JobReserver.new([work_queue])
      queues = reserver.extract_queues(Qmore.client, ["*"]).collect(&:name)
      queues.should include("work")
    end

    it "should not ignore queues that have work in the depends state" do
      work_queue = Qmore.client.queues['work']
      jid = work_queue.put(SomeJob, {})
      work_queue.put(SomeJob, {}, {:depends => [jid]})

      work_queue.pop

      %w(waiting recurring stalled scheduled).each do |state|
        work_queue.counts[state].should equal(0)
      end
      work_queue.counts["depends"].should equal(1)

      reserver = Qmore::JobReserver.new([work_queue])
      queues = reserver.extract_queues(Qmore.client, ["*"]).collect(&:name)
      queues.should include("work")
    end

    it "should not ignore queues that have work in the recurring state" do
      work_queue = Qmore.client.queues['work']
      work_queue.recur(SomeJob, {}, 1000)

      %w(waiting depends stalled scheduled).each do |state|
        work_queue.counts[state].should equal(0)
      end
      work_queue.counts["recurring"].should equal(1)

      reserver = Qmore::JobReserver.new([work_queue])
      queues = reserver.extract_queues(Qmore.client, ["*"]).collect(&:name)
      queues.should include("work")
    end

    it "should not ignore queues that have work in the waiting state" do
      work_queue = Qmore.client.queues['work']
      work_queue.put(SomeJob, {})

      %w(recurring depends stalled scheduled).each do |state|
        work_queue.counts[state].should equal(0)
      end
      work_queue.counts["waiting"].should equal(1)

      reserver = Qmore::JobReserver.new([work_queue])
      queues = reserver.extract_queues(Qmore.client, ["*"]).collect(&:name)
      queues.should include("work")
    end

    it "can reserve from multiple queues" do
      high_queue = Qmore.client.queues['high']
      critical_queue = Qmore.client.queues['critical']

      high_queue.put(SomeJob, {})
      critical_queue.put(SomeJob, {})

      reserver = Qmore::JobReserver.new([critical_queue, high_queue])

      reserver.reserve.queue.name.should == 'critical'
      reserver.reserve.queue.name.should == 'high'
    end

    it "can work on multiple queues" do
      high_queue = Qmore.client.queues['high']
      critical_queue = Qmore.client.queues['critical']
      high_queue.put(SomeJob, {})
      critical_queue.put(SomeJob, {})

      high_queue.length.should == 1
      critical_queue.length.should == 1

      reserver = Qmore::JobReserver.new([critical_queue, high_queue])

      worker = Qless::Worker.new(reserver,
                                 :run_as_single_process => true)
      worker.work(0)

      high_queue.length.should == 0
      critical_queue.length.should == 0
    end

    it "can work on all queues" do
      queues = []
      ['high', 'critical', 'blahblah'].each do |q|
        queue = Qmore.client.queues[q]
        queue.put(SomeJob, {})
        queue.length.should == 1
        queues << queue
      end

      reserver = Qmore::JobReserver.new([Qmore.client.queues['*']])
      worker = Qless::Worker.new(reserver,
                                 :run_as_single_process => true)
      worker.work(0)

      queues.each do |q|
        q.length.should == 0
      end
    end

    it "handles priorities" do
      Qmore.configuration.priority_buckets = [{'pattern' => 'foo*', 'fairly' => false},
                            {'pattern' => 'default', 'fairly' => false},
                            {'pattern' => 'bar', 'fairly' => true}]


      queues = []
      ['other', 'blah', 'foobie', 'bar', 'foo'].each do |q|
        queue = Qmore.client.queues[q]
        queue.put(SomeJob, {})
        queue.length.should == 1
        queues << queue
      end

      reserver = Qmore::JobReserver.new([Qmore.client.queues['*'], Qmore.client.queues['!blah']])

      reserver.reserve.queue.name.should == 'foo'
      reserver.reserve.queue.name.should == 'foobie'
      reserver.reserve.queue.name.should == 'other'
      reserver.reserve.queue.name.should == 'bar'
      reserver.reserve.should be_nil
    end

  end

end
