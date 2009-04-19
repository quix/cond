
require 'rbconfig'

class Jumpstart
  module Ruby
    EXECUTABLE = lambda {
      name = File.join(
        Config::CONFIG["bindir"],
        Config::CONFIG["RUBY_INSTALL_NAME"]
      )

      if Config::CONFIG["host"] =~ %r!(mswin|cygwin|mingw)! and
          File.basename(name) !~ %r!\.(exe|com|bat|cmd)\Z!i
        name + Config::CONFIG["EXEEXT"]
      else
        name
      end
    }.call

    class << self
      def run(*args)
        cmd = [EXECUTABLE, *args]
        unless system(*cmd)
          cmd_str = cmd.map { |t| "'#{t}'" }.join(", ")
          raise "system(#{cmd_str}) failed with status #{$?.exitstatus}"
        end
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
