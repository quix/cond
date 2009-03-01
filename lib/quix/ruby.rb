
require 'rbconfig'
require 'quix/kernel'

module Quix
  module Ruby
    EXECUTABLE = File.join(
      Config::CONFIG["bindir"],
      Config::CONFIG["RUBY_INSTALL_NAME"]
    )

    class << self
      def run(*args)
        system(EXECUTABLE, *args)
      end
      def run_or_raise(*args)
        system_or_raise(EXECUTABLE, *args)
      end
    end
  end
end
