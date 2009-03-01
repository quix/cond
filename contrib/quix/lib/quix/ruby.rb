
require 'rbconfig'
require 'cond/util'

module Cond
end

module Cond::Test
  module Ruby
    EXECUTABLE = File.join(
      Config::CONFIG["bindir"],
      Config::CONFIG["RUBY_INSTALL_NAME"]
    )

    class << self
      include Cond::Util

      def run(*args)
        system(EXECUTABLE, *args)
      end

      def run_or_raise(*args)
        system_or_raise(EXECUTABLE, *args)
      end

      def with_warnings(value = true)
        previous = $VERBOSE
        $VERBOSE = value
        begin
          yield
        ensure
          $VERBOSE = previous
        end
      end
      
      def no_warnings(&block)
        with_warnings(false, &block)
      end
    end
  end
end
