Qmore is a qless plugin that gives one more control over how queues are processed.  Qmore allows one to specify the queues a worker processes by the use of wildcards, negations, or dynamic look up from redis.  It also allows one to specify the relative priority between queues (rather than within a single queue).  It plugs into the Qless webapp to make it easy to manage the queues.

Authored against Qless 0.9.3, so it at least works with that - try running the tests if you use a different version of qless

[![Build Status](https://secure.travis-ci.org/wr0ngway/qmore.png)](http://travis-ci.org/wr0ngway/qmore)
[![Coverage Status](https://coveralls.io/repos/wr0ngway/qmore/badge.png?branch=master)](https://coveralls.io/r/wr0ngway/qmore?branch=master)

Usage
-----

To use the rake tasks built into qless, just adding qless to your Gemfile should cause it to get required before the task executes.  If you aren't using a gemfile, then you'll need to require qmore directly so that it sets up ENV['JOB_RESERVER'] to use Qmore::Reservers::Default.

Alternatively, if you have some other way of launching workers (e.g. qless-pool), you can assign the reserver explicitly in the setup rake task or some other initializer:

    Qless::Pool.pool_factory.reserver_class = Qmore::Reservers::Default
    Qmore.client == Qless::Pool.pool_factory.client

    # Enabling Monitoring
    # Redis persistence defaults to using the same connection
    # used for reserving jobs, however it is not required that they
    # be the same redis connection. I.e. you can store configuration
    # on a completely separate instance of redis.
    Qmore.persistence = Qless::Persistence::Redis.new(Qmore.client.redis)
    # Configure the monitor thread with the persistence type, and the interval at which to update
    # Monitor defaults to using Qmore.persistence and 2 minutes
    Qmore.monitor = Qless::persistence::Monitor.new(Qmore.persistence, 120)
    # Start up monitor thread
    Qmore.monitor.start

To enable the web UI, use a config.ru similar to the following depending on your environment:

    require 'qless/server'
    require 'qmore-server'

    Qless::Server.client = Qless::Client.new(:host => "some-host", :port => 7000)
    Qmore.client = Qless::Server.client
    run Qless::Server.new(Qmore.client)

Dynamic Queues
--------------

Start your workers with a QUEUES that can contain '\*' for zero-or more of any character, '!' to exclude the following pattern, or @key to look up the patterns from redis.  Some examples help:

    QUEUES='foo' rake qless:work

Pulls jobs from the queue 'foo'

    QUEUES='*' rake qless:work

Pulls jobs from any queue

    QUEUES='*foo' rake qless:work

Pulls jobs from queues that end in foo

    QUEUES='*foo*' rake qless:work

Pulls jobs from queues whose names contain foo

    QUEUES='*foo*,!foobar' rake qless:work

Pulls jobs from queues whose names contain foo except the foobar queue

    QUEUES='*foo*,!*bar' rake qless:work

Pulls jobs from queues whose names contain foo except queues whose names end in bar

    QUEUES='@key' rake qless:work

Pulls jobs from queue names stored in redis (use Qless.set\_dynamic\_queue("key", ["queuename1", "queuename2"]) to set them)

    QUEUES='*,!@key' rake qless:work

Pulls jobs from any queue execept ones stored in redis

    QUEUES='@' rake qless:work

Pulls jobs from queue names stored in redis using the hostname of the worker

    Qless.set_dynamic_queue("key", ["*foo*", "!*bar"])
    QUEUES='@key' rake qless:work

Pulls jobs from queue names stored in redis, with wildcards/negations

    task :custom_worker do
      ENV['QUEUES'] = "*foo*,!*bar"
      Rake::Task['qless:work'].invoke
    end

From a custom rake script

Queue Priority
--------------

Start your workers with a QUEUES that contains many queue names - the priority is most useful when using wildcards.

The qmore priority web ui is shown as a tab in the qless web UI, and allows you to define the queue priorities.  To activate it, you need to require 'qmore-server' in whatever initializer you use to bring up qless-web.

Then you should set use the web ui to determine the order a worker will pick a queue for processing.  The "Fairly" checkbox makes all queues that match that pattern get ordered in a random fashion.

For example, say my qless system has the queues:

low_foo, low_bar, low_baz, high_foo, high_bar, high_baz, otherqueue, somequeue, myqueue

And I run my worker with QUEUES=\*

If I set my patterns like:

high\_\* (fairly unchecked)
default (fairly unchecked)
low\_\* (fairly unchecked)

Then, the worker will scan the queues for work in this order:
high_bar, high_baz, high_foo, myqueue, otherqueue, somequeue, low_bar, low_baz, low_foo

If I set my patterns like:

high\_\* (fairly checked)
default (fairly checked)
low\_\* (fairly checked)

Then, the worker will scan the queues for work in this order:

\*[high_bar, high_baz, high_foo].shuffle, \*[myqueue, otherqueue, somequeue].shuffle, \*[low_bar, low_baz, low_foo].shuffle


Contributors
------------

Matt Conway ( https://github.com/wr0ngway )
Bert Goethals ( https://github.com/Bertg )
James Lawrence ( https://github.com/jambli )
