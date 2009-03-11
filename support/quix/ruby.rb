
require 'rbconfig'
require 'quix/kernel'

module Quix
  module Ruby
    EXECUTABLE = let {
      name = File.join(
        Config::CONFIG["bindir"],
        Config::CONFIG["RUBY_INSTALL_NAME"]
      )

      if Config::CONFIG["host"] =~ %r!(mswin|cygwin|mingw)! and
          File.basename(name) !~ %r!\.(exe|com|bat|cmd)\Z!i
        name + ".exe"
      else
        name
      end
    }

    class << self
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
