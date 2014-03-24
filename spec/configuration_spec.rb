require "spec_helper"

describe "Qmore::Configuration" do
  before(:each) do
    Qmore.client.redis.flushall
  end

  context "dynamic queues" do
    it "should always have a fallback pattern" do
      configuration = Qmore::Configuration.new

      configuration.dynamic_queues['default'].should == ['*']
    end

    it "should default any unspecified keys to default pattern" do
      configuration = Qmore::Configuration.new
      configuration.dynamic_queues['foo'].should == ['*']

      configuration.dynamic_queues[Qmore::Configuration::DYNAMIC_FALLBACK_KEY] = ["foo", "bar"]
      configuration.dynamic_queues['foo'].should == ["foo", "bar"]
    end

    it "should allow setting single patterns" do
      configuration = Qmore::Configuration.new

      configuration.dynamic_queues['foo'].should == ['*']
      configuration.dynamic_queues['foo'] = ['bar']
      configuration.dynamic_queues['foo'].should == ['bar']
    end

    it "should allow changing the pattern of the fallback key" do
      configuration = Qmore::Configuration.new
      configuration.dynamic_queues[Qmore::Configuration::DYNAMIC_FALLBACK_KEY].should == ['*']
      configuration.dynamic_queues[Qmore::Configuration::DYNAMIC_FALLBACK_KEY] = ['foo', 'bar']
      configuration.dynamic_queues[Qmore::Configuration::DYNAMIC_FALLBACK_KEY].should == ['foo', 'bar']
    end

    it "should ignore mappings when setting empty value" do
      configuration = Qmore::Configuration.new
      configuration.dynamic_queues = {'foo' => ['bar'], 'baz' => ['boo']}
      configuration.dynamic_queues.should == {'default' => ['*'], 'foo' => ['bar'], 'baz' => ['boo']}

      configuration.dynamic_queues = {'foo' => [], 'baz' => ['boo']}
      configuration.dynamic_queues.should == {'default' => ['*'], 'baz' => ['boo']}
      configuration.dynamic_queues = {'baz' => nil}
      configuration.dynamic_queues.should == {'default' => ['*']}

      configuration.dynamic_queues = {'foo' => ['bar'], 'baz' => ['boo']}
      configuration.dynamic_queues['foo'] = []
      configuration.dynamic_queues.should == {'default' => ["*"], 'baz' => ['boo']}
      configuration.dynamic_queues['baz'] = nil
      configuration.dynamic_queues.should == {'default' => ['*']}
    end
  end

  context "priority attributes" do
    it "should have a default priority" do
      configuration = Qmore::Configuration.new
      configuration.priority_buckets.should == [{'pattern' => 'default'}]
    end

    it "can set priorities" do
      expected_priority_buckets = [{'pattern' => 'foo', 'fairly' => 'false'},{'pattern' => 'default'}]
      configuration = Qmore::Configuration.new
      configuration.priority_buckets = [{'pattern' => 'foo', 'fairly' => 'false'}]
      configuration.priority_buckets.should == expected_priority_buckets
    end

    it "can set priorities including default" do
      expected_priority_buckets = [{'pattern' => 'foo', 'fairly' => false},
                                   {'pattern' => 'default', 'fairly' => false},
                                   {'pattern' => 'bar', 'fairly' => true}]
      configuration = Qmore::Configuration.new
      configuration.priority_buckets = expected_priority_buckets
      configuration.priority_buckets.should == expected_priority_buckets
    end
  end
end
