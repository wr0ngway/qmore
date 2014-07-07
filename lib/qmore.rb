require 'qless'
require 'qless/worker'
require 'gem_logger'
require 'qmore/configuration'
require 'qmore/persistence'
require 'qmore/attributes'
require 'qmore/reservers'

module Qmore
  def self.client=(client)
    @client = client
  end

  def self.client
    @client ||= Qless::Client.new
  end

  def self.configuration
    @configuration ||= Qmore::LegacyConfiguration.new(Qmore.persistence)
  end

  def self.configuration=(configuration)
    @configuration = configuration
  end

  def self.persistence
    @persistence ||= Qmore::Persistence::Redis.new(self.client.redis)
  end

  def self.persistence=(manager)
    @persistence = manager
  end

  def self.monitor
    @monitor ||= Qmore::Persistence::Monitor.new(self.persistence, 120)
  end

  def self.monitor=(monitor)
    @monitor = monitor
  end
end

module Qless
  module JobReservers
    QmoreReserver = Qmore::Reservers::Default
  end
end
ENV['JOB_RESERVER'] ||= 'QmoreReserver'
