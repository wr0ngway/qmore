ENV['RACK_ENV'] = 'test'

require 'spec_helper'
require 'rack'
require 'rack/test'
require 'qmore-server'
require 'orderedhash'

Sinatra::Base.set :environment, :test

describe "Qmore Server" do

  include Rack::Test::Methods
  include Qmore::Attributes

  def app
    @app ||= Qless::Server.new(Qmore.client)
  end

  before(:each) do
    Qmore.client.redis.flushall
    Qmore.configuration = Qmore::Configuration.new
  end

  context "DynamicQueue" do

    context "existence in application" do

      it "should respond to it's url" do
        get "/dynamicqueues"
        last_response.should be_ok
      end

      it "should display its tab" do
        get "/queues"
        last_response.body.should include "<a href='/dynamicqueues'>DynamicQueues</a>"
      end

    end

    context "show dynamic queues table" do

      it "should shows default queue when nothing set" do
        get "/dynamicqueues"

        last_response.body.should include 'default'
      end

      it "should shows names of queues" do
        Qmore.configuration.dynamic_queues["key_one"] = ["foo"]
        Qmore.configuration.dynamic_queues["key_two"] = ["bar"]
        Qmore.persistence.write(Qmore.configuration)

        get "/dynamicqueues"

        last_response.body.should include 'key_one'
        last_response.body.should include 'key_two'
      end

      it "should shows values of queues" do
        Qmore.configuration.dynamic_queues["key_one"] = ["foo"]
        Qmore.configuration.dynamic_queues["key_two"] = ["bar", "baz"]
        Qmore.persistence.write(Qmore.configuration)

        get "/dynamicqueues"

        last_response.body.should include 'foo'
        last_response.body.should include 'bar, baz'
      end

    end

    context "remove queue link" do

      it "should show remove link for queue" do
        Qmore.configuration.dynamic_queues["key_one"] = ["foo"]
        Qmore.persistence.write(Qmore.configuration)

        get "/dynamicqueues"

        last_response.body.should match /<a .*href=['"]#remove['"].*>/
      end

      it "should show add link" do
        get "/dynamicqueues"

        last_response.body.should match /<a .*href=['"]#add['"].*>/
      end

    end

    context "form to edit queues" do

      it "should have form to edit queues" do
        get "/dynamicqueues"

        last_response.body.should match /<form action="\/dynamicqueues"/
      end

      it "should show input fields" do
        Qmore.configuration.dynamic_queues["key_one"] = ["foo"]
        Qmore.configuration.dynamic_queues["key_two"] = ["bar", "baz"]
        Qmore.persistence.write(Qmore.configuration)

        get "/dynamicqueues"

        last_response.body.should match /<input type="text" id="input-0-name" name="queues\[\]\[name\]" value="key_one"/
        last_response.body.should match /<input type="text" id="input-0-value" name="queues\[\]\[value\]" value="foo"/
        last_response.body.should match /<input type="text" id="input-1-name" name="queues\[\]\[name\]" value="key_two"/
        last_response.body.should match /<input type="text" id="input-1-value" name="queues\[\]\[value\]" value="bar, baz"/
      end

      it "should delete queues on empty queue submit" do
        Qmore.configuration.dynamic_queues["key_two"] = ["bar", "baz"]
        Qmore.persistence.write(Qmore.configuration)
        Qmore.persistence.load.dynamic_queues.has_key?("key_two").should == true

        post "/dynamicqueues", {'queues' => [{'name' => "key_two", "value" => ""}]}

        last_response.should be_redirect
        last_response['Location'].should match /dynamicqueues/
        Qmore.configuration.dynamic_queues.has_key?("key_two").should == false
      end

      it "should create queues" do
        post "/dynamicqueues", {'queues' => [{'name' => "key_two", "value" => " foo, bar ,baz "}]}

        last_response.should be_redirect
        last_response['Location'].should match /dynamicqueues/
        Qmore.configuration.dynamic_queues["key_two"].should == %w{foo bar baz}
      end

      it "should update queues" do
        Qmore.configuration.dynamic_queues["key_two"] = ["bar", "baz"]
        Qmore.persistence.write(Qmore.configuration)

        post "/dynamicqueues", {'queues' => [{'name' => "key_two", "value" => "foo,bar,baz"}]}

        last_response.should be_redirect
        last_response['Location'].should match /dynamicqueues/
        Qmore.configuration.dynamic_queues["key_two"].should == %w{foo bar baz}
      end

    end

  end

  context "QueuePriority" do

    context "existence in application" do

      it "should respond to it's url" do
        get "/queuepriority"
        last_response.should be_ok
      end

      it "should display its tab" do
        get "/queues"
        last_response.body.should include "<a href='/queuepriority'>QueuePriority</a>"
      end

    end

    context "show queue priority table" do

      before(:each) do
        Qmore.configuration.priority_buckets = [{'pattern' => 'foo', 'fairly' => false},
                                                {'pattern' => 'default', 'fairly' => false},
                                                {'pattern' => 'bar', 'fairly' => true}]
        Qmore.persistence.write(Qmore.configuration)
      end

      it "should shows pattern input fields" do
        get "/queuepriority"

        last_response.body.should match /<input type="text" id="input-0-pattern" name="priorities\[\]\[pattern\]" value="foo"/
        last_response.body.should match /<input type="text" id="input-1-pattern" name="priorities\[\]\[pattern\]" value="default"/
        last_response.body.should match /<input type="text" id="input-2-pattern" name="priorities\[\]\[pattern\]" value="bar"/
      end

      it "should show fairly checkboxes" do
        get "/queuepriority"

        last_response.body.should match /<input type="checkbox" id="input-0-fairly" name="priorities\[\]\[fairly\]" value="true" *\/>/
        last_response.body.should match /<input type="checkbox" id="input-1-fairly" name="priorities\[\]\[fairly\]" value="true" *\/>/
        last_response.body.should match /<input type="checkbox" id="input-2-fairly" name="priorities\[\]\[fairly\]" value="true" checked *\/>/
      end

    end

    context "edit links" do

      before(:each) do
        Qmore.configuration.priority_buckets = [{'pattern' => 'foo', 'fairly' => false},
                                                {'pattern' => 'default', 'fairly' => false},
                                                {'pattern' => 'bar', 'fairly' => true}]
        Qmore.persistence.write(Qmore.configuration)
      end

      it "should show remove link for queue" do
        get "/queuepriority"

        last_response.body.should match /<a href="#remove"/
      end

      it "should show up link for queue" do
        get "/queuepriority"

        last_response.body.should match /<a href="#up"/
      end

      it "should show down link for queue" do
        get "/queuepriority"

        last_response.body.should match /<a href="#down"/
      end

    end

    context "form to edit queues" do

      it "should have form to edit queues" do
        get "/queuepriority"

        last_response.body.should match /<form action="\/queuepriority"/
      end

      it "should update queues" do
        Qmore.configuration.priority_buckets.should == [{'pattern' => 'default'}]

        params = {'priorities' => [
            OrderedHash["pattern", "foo"],
            OrderedHash["pattern", "default"],
            OrderedHash["pattern", "bar", "fairly", "true"]
        ]}
        post "/queuepriority", params

        last_response.should be_redirect
        last_response['Location'].should match /queuepriority/
        Qmore.configuration.priority_buckets.should == [{"pattern" => "foo"},
                                           {"pattern" => "default"},
                                           {"pattern" => "bar", "fairly" => "true"}]
      end

    end

  end
end
