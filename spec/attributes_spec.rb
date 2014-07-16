require "spec_helper"

describe "Attributes" do
  include Qmore::Attributes

  before(:each) do
    Qmore.client.redis.flushall
    Qmore.configuration = Qmore::Configuration.new

    @real_queues = ["high_x", "foo", "high_y", "superhigh_z"]
  end

  context "basic queue patterns" do
    it "can specify simple queues" do
      expect(expand_queues(["foo"], @real_queues)).to(eq(["foo"]))
      expect(expand_queues(["foo", "bar"], @real_queues)).to(eq(["bar", "foo"]))
    end

    it "can specify simple wildcard" do
      worker = Qless::Worker.new("*")
      expect(expand_queues(["*"], @real_queues)).to(eq(["foo", "high_x", "high_y", "superhigh_z"]))
    end

    it "can include queues with pattern" do
      expect(expand_queues(["high*"], @real_queues)).to(eq(["high_x", "high_y"]))
      expect(expand_queues(["*high_z"], @real_queues)).to(eq(["superhigh_z"]))
      expect(expand_queues(["*high*"], @real_queues)).to(eq(["high_x", "high_y", "superhigh_z"]))
    end

    it "can blacklist queues" do
      expect(expand_queues(["*", "!foo"], @real_queues)).to(eq(["high_x", "high_y", "superhigh_z"]))
    end

    it "can blacklist queues with pattern" do
      expect(expand_queues(["*", "!*high*"], @real_queues)).to(eq(["foo"]))
    end
  end

  context "expanding queues" do
    it "can dynamically lookup queues" do
      Qmore.configuration.dynamic_queues = {"mykey" => ["foo", "bar"]}
      expect(expand_queues(["@mykey"], @real_queues)).to(eq(["bar", "foo"]))
    end

    it "can blacklist dynamic queues" do
      Qmore.configuration.dynamic_queues["mykey"] = ["foo"]
      expect(expand_queues(["*", "!@mykey"], @real_queues)).to(eq(["high_x", "high_y", "superhigh_z"]))
    end

    it "can blacklist dynamic queues with negation" do
      Qmore.configuration.dynamic_queues["mykey"] = ["!foo", "high_x"]
      expect(expand_queues(["!@mykey"], @real_queues)).to(eq(["foo"]))
    end

    it "will not bloat the given real_queues" do
      orig = @real_queues.dup
      expand_queues(["@mykey"], @real_queues)
      expect(@real_queues).to(eq(orig))
    end

    it "uses hostname as default key in dynamic queues" do
      host = Socket.gethostname
      Qmore.configuration.dynamic_queues[host] = ["foo", "bar"]

      expect(expand_queues(["@"], @real_queues)).to(eq(["bar", "foo"]))
    end

    it "can use wildcards in dynamic queues" do
      Qmore.configuration.dynamic_queues["mykey"] = ["*high*", "!high_y"]
      expect(expand_queues(["@mykey"], @real_queues)).to(eq(["high_x", "superhigh_z"]))
    end

    it "falls back to default queues when missing" do
      Qmore.configuration.dynamic_queues["default"] = ["foo", "bar"]
      expect(expand_queues(["@mykey"], @real_queues)).to(eq(["bar", "foo"]))
    end

    it "falls back to all queues when missing and no default" do
      expect(expand_queues(["@mykey"], @real_queues)).to(eq(["foo", "high_x", "high_y", "superhigh_z"]))
    end

    it "falls back to all queues when missing and no default and keep up to date" do
      expect(expand_queues(["@mykey"], @real_queues)).to(eq(["foo", "high_x", "high_y", "superhigh_z"]))
      @real_queues << "bar"
      expect(expand_queues(["@mykey"], @real_queues)).to(eq(["bar", "foo", "high_x", "high_y", "superhigh_z"]))
    end
  end

  context "queue priorities" do
    it "should pick up all queues with default priority" do
      priority_buckets = [{'pattern' => 'default', 'fairly' => false}]
      expect(prioritize_queues(priority_buckets, @real_queues)).to(eq(["high_x", "foo", "high_y", "superhigh_z"]))
    end

    it "should pick up all queues fairly" do
      # do a bunch to reduce likelyhood of random match causing test failure
      @real_queues = 50.times.collect { |i| "auto_#{i}" }
      priority_buckets = [{'pattern' => 'default', 'fairly' => true}]
      expect(prioritize_queues(priority_buckets, @real_queues)).not_to(eq(@real_queues.sort))
      expect(prioritize_queues(priority_buckets, @real_queues).sort).to(eq(@real_queues.sort))
    end

    it "should prioritize simple pattern" do
      priority_buckets = [{'pattern' => 'superhigh_z', 'fairly' => false},
                          {'pattern' => 'default', 'fairly' => false}]
      expect(prioritize_queues(priority_buckets, @real_queues)).to(eq(["superhigh_z", "high_x", "foo", "high_y"]))
    end

    it "should prioritize multiple simple patterns" do
      priority_buckets = [{'pattern' => 'superhigh_z', 'fairly' => false},
                          {'pattern' => 'default', 'fairly' => false},
                          {'pattern' => 'foo', 'fairly' => false}]
      expect(prioritize_queues(priority_buckets, @real_queues)).to(eq(["superhigh_z", "high_x", "high_y", "foo"]))
    end

    it "should prioritize simple wildcard pattern" do
      priority_buckets = [{'pattern' => 'high*', 'fairly' => false},
                          {'pattern' => 'default', 'fairly' => false}]
      expect(prioritize_queues(priority_buckets, @real_queues)).to(eq(["high_x", "high_y", "foo", "superhigh_z"]))
    end

    it "should prioritize simple wildcard pattern with correct matching" do
      priority_buckets = [{'pattern' => '*high*', 'fairly' => false},
                          {'pattern' => 'default', 'fairly' => false}]
      expect(prioritize_queues(priority_buckets, @real_queues)).to(eq(["high_x", "high_y", "superhigh_z", "foo"]))
    end

    it "should prioritize negation patterns" do
      @real_queues.delete("high_x")
      @real_queues << "high_x"
      priority_buckets = [{'pattern' => 'high*,!high_x', 'fairly' => false},
                          {'pattern' => 'default', 'fairly' => false}]
      expect(prioritize_queues(priority_buckets, @real_queues)).to(eq(["high_y", "foo", "superhigh_z", "high_x"]))
    end

    it "should not be affected by standalone negation patterns" do
      priority_buckets = [{'pattern' => '!high_x', 'fairly' => false},
                          {'pattern' => 'default', 'fairly' => false}]
      expect(prioritize_queues(priority_buckets, @real_queues)).to(eq(["high_x", "foo", "high_y", "superhigh_z"]))
    end

    it "should allow multiple inclusive patterns" do
      priority_buckets = [{'pattern' => 'high_x, superhigh*', 'fairly' => false},
                          {'pattern' => 'default', 'fairly' => false}]
      expect(prioritize_queues(priority_buckets, @real_queues)).to(eq(["high_x", "superhigh_z", "foo", "high_y"]))
    end

    it "should prioritize fully inclusive wildcard pattern" do
      priority_buckets = [{'pattern' => '*high*', 'fairly' => false},
                          {'pattern' => 'default', 'fairly' => false}]
      expect(prioritize_queues(priority_buckets, @real_queues)).to(eq(["high_x", "high_y", "superhigh_z", "foo"]))
    end

    it "should handle empty default match" do
      priority_buckets = [{'pattern' => '*', 'fairly' => false},
                          {'pattern' => 'default', 'fairly' => false}]
      expect(prioritize_queues(priority_buckets, @real_queues)).to(eq(["high_x", "foo", "high_y", "superhigh_z"]))
    end

    it "should pickup wildcard queues fairly" do
      others = 5.times.collect { |i| "other#{i}" }
      @real_queues = @real_queues + others

      priority_buckets = [{'pattern' => 'other*', 'fairly' => true},
                          {'pattern' => 'default', 'fairly' => false}]
      queues = prioritize_queues(priority_buckets, @real_queues)

      expect(queues[0..4].sort).to eq(others.sort)
      expect(queues[5..-1]).to eq(["high_x", "foo", "high_y", "superhigh_z"])
      expect(queues).not_to eq(others.sort + ["high_x", "foo", "high_y", "superhigh_z"])
    end
  end
end
