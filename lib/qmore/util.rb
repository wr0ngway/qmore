module Qmore
  module Util
    def procline(value)
      $0 = "Qless-#{Qless::VERSION}: #{value} at #{Time.now.iso8601}"
    end
  end
end
