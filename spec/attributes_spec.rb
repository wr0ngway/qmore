require "spec_helper"

describe "Attributes" do
  include Qmore::Attributes

  before(:each) do
    Qmore.client.redis.flushall
    @real_queues = ["high_x", "foo", "high_y", "superhigh_z"]
  end

  context "dynamic attributes" do

    it "should always have a fallback pattern" do
      get_dynamic_queues.should == {'default' => ['*']}
    end

    it "should allow setting single patterns" do
      get_dynamic_queue('foo').should == ['*']
      set_dynamic_queue('foo', ['bar'])
      get_dynamic_queue('foo').should == ['bar']
    end

    it "should allow setting multiple patterns" do
      set_dynamic_queues({'foo' => ['bar'], 'baz' => ['boo']})
      get_dynamic_queues.should == {'foo' => ['bar'], 'baz' => ['boo'], 'default' => ['*']}
    end

    it "should remove mapping when setting empty value" do
      get_dynamic_queues
      set_dynamic_queues({'foo' => ['bar'], 'baz' => ['boo']})
      get_dynamic_queues.should == {'foo' => ['bar'], 'baz' => ['boo'], 'default' => ['*']}

      set_dynamic_queues({'foo' => [], 'baz' => ['boo']})
      get_dynamic_queues.should == {'baz' => ['boo'], 'default' => ['*']}
      set_dynamic_queues({'baz' => nil})
      get_dynamic_queues.should == {'default' => ['*']}

      set_dynamic_queues({'foo' => ['bar'], 'baz' => ['boo']})
      set_dynamic_queue('foo', [])
      get_dynamic_queues.should == {'baz' => ['boo'], 'default' => ['*']}
      set_dynamic_queue('baz', nil)
      get_dynamic_queues.should == {'default' => ['*']}
    end

  end

  context "priority attributes" do

    it "can lookup a default priority" do
      get_priority_buckets.should == [{'pattern' => 'default'}]
    end

    it "can set priorities" do
      set_priority_buckets [{'pattern' => 'foo', 'fairly' => 'false'}]
      get_priority_buckets.should == [{'pattern' => 'foo', 'fairly' => 'false'},
                                      {'pattern' => 'default'}]
    end

    it "can set priorities including default" do
      set_priority_buckets [{'pattern' => 'foo', 'fairly' => false},
                            {'pattern' => 'default', 'fairly' => false},
                            {'pattern' => 'bar', 'fairly' => true}]
      get_priority_buckets.should == [{'pattern' => 'foo', 'fairly' => false},
                                      {'pattern' => 'default', 'fairly' => false},
                                      {'pattern' => 'bar', 'fairly' => true}]
    end

  end

  context "basic queue patterns" do

    it "can specify simple queues" do
      expand_queues(["foo"], @real_queues).should == ["foo"]
      expand_queues(["foo", "bar"], @real_queues).should == ["bar", "foo"]
    end

    it "can specify simple wildcard" do
      worker = Qless::Worker.new("*")
      expand_queues(["*"], @real_queues).should == ["foo", "high_x", "high_y", "superhigh_z"]
    end

    it "can include queues with pattern" do
      expand_queues(["high*"], @real_queues).should == ["high_x", "high_y"]
      expand_queues(["*high_z"], @real_queues).should == ["superhigh_z"]
      expand_queues(["*high*"], @real_queues).should == ["high_x", "high_y", "superhigh_z"]
    end

    it "can blacklist queues" do
      expand_queues(["*", "!foo"], @real_queues).should == ["high_x", "high_y", "superhigh_z"]
    end

    it "can blacklist queues with pattern" do
      expand_queues(["*", "!*high*"], @real_queues).should == ["foo"]
    end

  end

  context "redis backed queues" do

    it "can dynamically lookup queues" do
      set_dynamic_queue("mykey", ["foo", "bar"])
      expand_queues(["@mykey"], @real_queues).should == ["bar", "foo"]
    end

    it "can blacklist dynamic queues" do
      set_dynamic_queue("mykey", ["foo"])
      expand_queues(["*", "!@mykey"], @real_queues).should == ["high_x", "high_y", "superhigh_z"]
    end

    it "can blacklist dynamic queues with negation" do
      set_dynamic_queue("mykey", ["!foo", "high_x"])
      expand_queues(["!@mykey"], @real_queues).should == ["foo"]
    end

    it "will not bloat the given real_queues" do
      orig = @real_queues.dup
      expand_queues(["@mykey"], @real_queues)
      @real_queues.should == orig
    end

    it "uses hostname as default key in dynamic queues" do
      host = `hostname`.chomp
      set_dynamic_queue(host, ["foo", "bar"])
      expand_queues(["@"], @real_queues).should == ["bar", "foo"]
    end

    it "can use wildcards in dynamic queues" do
      set_dynamic_queue("mykey", ["*high*", "!high_y"])
      expand_queues(["@mykey"], @real_queues).should == ["high_x", "superhigh_z"]
    end

    it "falls back to default queues when missing" do
      set_dynamic_queue("default", ["foo", "bar"])
      expand_queues(["@mykey"], @real_queues).should == ["bar", "foo"]
    end

    it "falls back to all queues when missing and no default" do
      expand_queues(["@mykey"], @real_queues).should == ["foo", "high_x", "high_y", "superhigh_z"]
    end

    it "falls back to all queues when missing and no default and keep up to date" do
      expand_queues(["@mykey"], @real_queues).should == ["foo", "high_x", "high_y", "superhigh_z"]
      @real_queues << "bar"
      expand_queues(["@mykey"], @real_queues).should == ["bar", "foo", "high_x", "high_y", "superhigh_z"]
    end

  end

  context "queue priorities" do

    it "should pick up all queues with default priority" do
      priority_buckets = [{'pattern' => 'default', 'fairly' => false}]
      prioritize_queues(priority_buckets, @real_queues).should == ["high_x", "foo", "high_y", "superhigh_z"]
    end

    it "should pick up all queues fairly" do
      # do a bunch to reduce likelyhood of random match causing test failure
      @real_queues = 50.times.collect { |i| "auto_#{i}" }
      priority_buckets = [{'pattern' => 'default', 'fairly' => true}]
      prioritize_queues(priority_buckets, @real_queues).should_not == @real_queues.sort
      prioritize_queues(priority_buckets, @real_queues).sort.should == @real_queues.sort
    end

    it "should prioritize simple pattern" do
      priority_buckets = [{'pattern' => 'superhigh_z', 'fairly' => false},
                          {'pattern' => 'default', 'fairly' => false}]
      prioritize_queues(priority_buckets, @real_queues).should == ["superhigh_z", "high_x", "foo", "high_y"]
    end

    it "should prioritize multiple simple patterns" do
      priority_buckets = [{'pattern' => 'superhigh_z', 'fairly' => false},
                          {'pattern' => 'default', 'fairly' => false},
                          {'pattern' => 'foo', 'fairly' => false}]
      prioritize_queues(priority_buckets, @real_queues).should == ["superhigh_z", "high_x", "high_y", "foo"]
    end

    it "should prioritize simple wildcard pattern" do
      priority_buckets = [{'pattern' => 'high*', 'fairly' => false},
                          {'pattern' => 'default', 'fairly' => false}]
      prioritize_queues(priority_buckets, @real_queues).should == ["high_x", "high_y", "foo", "superhigh_z"]
    end

    it "should prioritize simple wildcard pattern with correct matching" do
      priority_buckets = [{'pattern' => '*high*', 'fairly' => false},
                          {'pattern' => 'default', 'fairly' => false}]
      prioritize_queues(priority_buckets, @real_queues).should == ["high_x", "high_y", "superhigh_z", "foo"]
    end

    it "should prioritize negation patterns" do
      @real_queues.delete("high_x")
      @real_queues << "high_x"
      priority_buckets = [{'pattern' => 'high*,!high_x', 'fairly' => false},
                          {'pattern' => 'default', 'fairly' => false}]
      prioritize_queues(priority_buckets, @real_queues).should == ["high_y", "foo", "superhigh_z", "high_x"]
    end

    it "should not be affected by standalone negation patterns" do
      priority_buckets = [{'pattern' => '!high_x', 'fairly' => false},
                          {'pattern' => 'default', 'fairly' => false}]
      prioritize_queues(priority_buckets, @real_queues).should == ["high_x", "foo", "high_y", "superhigh_z"]
    end

    it "should allow multiple inclusive patterns" do
      priority_buckets = [{'pattern' => 'high_x, superhigh*', 'fairly' => false},
                          {'pattern' => 'default', 'fairly' => false}]
      prioritize_queues(priority_buckets, @real_queues).should == ["high_x", "superhigh_z", "foo", "high_y"]
    end

    it "should prioritize fully inclusive wildcard pattern" do
      priority_buckets = [{'pattern' => '*high*', 'fairly' => false},
                          {'pattern' => 'default', 'fairly' => false}]
      prioritize_queues(priority_buckets, @real_queues).should == ["high_x", "high_y", "superhigh_z", "foo"]
    end

    it "should handle empty default match" do
      priority_buckets = [{'pattern' => '*', 'fairly' => false},
                          {'pattern' => 'default', 'fairly' => false}]
      prioritize_queues(priority_buckets, @real_queues).should == ["high_x", "foo", "high_y", "superhigh_z"]
    end

    it "should pickup wildcard queues fairly" do
      others = 5.times.collect { |i| "other#{i}" }
      @real_queues = @real_queues + others

      priority_buckets = [{'pattern' => 'other*', 'fairly' => true},
                          {'pattern' => 'default', 'fairly' => false}]
      queues = prioritize_queues(priority_buckets, @real_queues)
      queues[0..4].sort.should == others.sort
      queues[5..-1].should == ["high_x", "foo", "high_y", "superhigh_z"]
      queues.should_not == others.sort + ["high_x", "foo", "high_y", "superhigh_z"]
    end

  end

end
