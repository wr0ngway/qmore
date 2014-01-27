require "spec_helper"

describe "JobReserver" do
  include Qmore::Attributes

  before(:each) do
    Qmore.client.redis.flushall
  end

  context "basic qless behavior still works" do

    it "can reserve from multiple queues" do
      high_queue = Qmore.client.queues['high']
      critical_queue = Qmore.client.queues['critical']

      high_queue.put(SomeJob, [])
      critical_queue.put(SomeJob, [])

      reserver = Qmore::JobReserver.new([critical_queue, high_queue])
      reserver.reserve.queue.name.should == 'critical'
      reserver.reserve.queue.name.should == 'high'
    end

    it "can work on multiple queues" do
      high_queue = Qmore.client.queues['high']
      critical_queue = Qmore.client.queues['critical']
      high_queue.put(SomeJob, [])
      critical_queue.put(SomeJob, [])

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
        queue.put(SomeJob, [])
        queue.length.should == 1
        queues << queue
      end

      reserver = Qmore::JobReserver.new([Qmore.client.queues['*']])
      reserver = Qmore::JobReserver.new([Qmore.client.queues['*']])
      worker = Qless::Worker.new(reserver,
                                 :run_as_single_process => true)
      worker.work(0)

      queues.each do |q|
        q.length.should == 0
      end
    end

    it "handles priorities" do
      set_priority_buckets [{'pattern' => 'foo*', 'fairly' => false},
                            {'pattern' => 'default', 'fairly' => false},
                            {'pattern' => 'bar', 'fairly' => true}]


      queues = []
      ['other', 'blah', 'foobie', 'bar', 'foo'].each do |q|
        queue = Qmore.client.queues[q]
        queue.put(SomeJob, [])
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


    context 'describing the job' do

      class MockReserver < Qmore::JobReserver
        attr_accessor :procline_value
        def procline(val)
          self.procline_value ||= []
          self.procline_value << val
        end
      end

      it "expands the queues in the job description" do
        ['high', 'critical', 'blahblah'].each do |q|
          queue = Qmore.client.queues[q]
          queue.put(SomeJob, [])
        end

        reserver = Qmore::JobReserver.new([Qmore.client.queues['*']])
        reserver.description.should == 'blahblah, critical, high (qmore)'
      end

      it "sets the description to show it is no longer working when finished" do
        ['high', 'critical', 'blahblah'].each do |q|
          queue = Qmore.client.queues[q]
          queue.put(SomeJob, [])
        end

        reserver = MockReserver.new([Qmore.client.queues['*']])
        worker = Qless::Worker.new(reserver,
          :run_as_single_process => true)
        worker.work(0)

        reserver.description.should == 'blahblah, critical, high (qmore)'
      end

      it "sets the procline to show the queue of the working job" do
        queues = []
        ['high', 'critical', 'blahblah'].each do |q|
          queue = Qmore.client.queues[q]
          queue.put(SomeJob, [])
          queues << queue
        end

        reserver = MockReserver.new([Qmore.client.queues['*']])
        worker = Qless::Worker.new(reserver,
          :run_as_single_process => true)
        worker.work(0)

        reserver.procline_value.first.should == 'Running blahblah (qmore)'
      end
    end
  end
end
