require 'qless'
require 'qless/worker'
require 'qmore/configuration'
require 'qmore/persistance'
require 'qmore/attributes'
require 'qmore/job_reserver'

module Qmore

  def self.client=(client)
    @client = client
  end

  def self.client
    @client ||= Qless::Client.new
  end

  def self.configuration
    @configuration ||= Qmore.persistance.load
  end

  def self.configuration=(configuration)
    @configuration = configuration
  end

  def self.persistance
    @persistance ||= Qmore::Persistance::Redis.new(self.client.redis)
  end

  def self.persistance=(manager)
    @persistance = manager
  end

  def self.monitor
    @monitor ||= Qmore::Persistance::Monitor.new(self.persistance, 120)
  end

  def self.monitor=(monitor)
    @monitor = monitor
  end
end

module Qless
  module JobReservers
    QmoreReserver = Qmore::JobReserver
  end
end
ENV['JOB_RESERVER'] ||= 'QmoreReserver'
