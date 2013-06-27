require 'qless'
require 'qless/worker'
require 'qmore/attributes'
require 'qmore/job_reserver'

module Qmore
  
  def self.client=(client)
    @client = client
  end
  
  def self.client
    @client ||= Qless::Client.new 
  end
end

module Qless
  module JobReservers
    QmoreReserver = Qmore::JobReserver
  end
end
ENV['JOB_RESERVER'] ||= 'QmoreReserver'
