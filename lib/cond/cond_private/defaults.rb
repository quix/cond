
require 'cond/cond_private/symbol_generator'

if RUBY_VERSION <= "1.8.6"
  require 'enumerator'
end

module Cond
  module CondPrivate
    class Defaults
      def initialize
        @stream_in = STDIN
        @stream_out = STDERR
      end

      attr_accessor :stream_in, :stream_out
      
      #
      # These are not restarts per se, but only a convenient way to
      # hook into the input loop.
      #
      def phony_restarts
        {
          :raise => Restart.new("Raise this exception.") { },
          :eval => Restart.new("Run some code.") { },
          :backtrace => Restart.new("Show backtrace.") { },
        }
      end

      def handlers
        {
          Exception => method(:handler)
        }
      end

      def debugger_handlers
        {
          Exception => method(:debugger_handler)
        }
      end

      def handler(exception)
        common_handler(exception, false)
      end

      def debugger_handler(exception)
        common_handler(exception, true)
      end
  
      def common_handler(exception, is_debugger)
        stream_out.puts exception.inspect, exception.backtrace.last

        if exception.respond_to? :message
          stream_out.puts exception.message, ""
        end
          
        #
        # Show restarts in the order they appear on the stack (partial
        # differences).
        #
        # grr:
        #
        #   % ruby186 -ve 'p({:x => 33}.eql?({:x => 33}))'
        #   ruby 1.8.6 (2009-03-10 patchlevel 362) [i686-darwin9.6.0]
        #   false
        #
        #   % ruby187 -ve 'p({:x => 33}.eql?({:x => 33}))'
        #   ruby 1.8.7 (2009-03-09 patchlevel 150) [i686-darwin9.6.0]
        #   true
        #
        stack_arrays = Cond.restarts_stack.map { |level|
          level.to_a.sort_by { |t| t.first.to_s }
        }
        restart_names = stack_arrays.to_enum(:each_with_index).map {
          |level, index|
          if index == 0
            level
          else
            level - stack_arrays[index - 1]
          end
        }.map { |level| level.map { |t| t.first } }.flatten

        loop {
          restart_index = loop {
            restart_names.each_with_index { |name, index|
              func = Cond.available_restarts[name]
              message = (
                if func.respond_to?(:message) and func.message != ""
                  func.message + " "
                else
                  ""
                end
              )
              stream_out.printf("%3d: %s(%s)\n", index, message, name.inspect)
            }
            stream_out.print "Choose number: "
            stream_out.flush
            input = stream_in.readline.strip
            if input =~ %r!\A\d+\Z! and
                (0...restart_names.size).include?(input.to_i)
              break input.to_i
            end
          }
          restart_name = restart_names[restart_index]
          if is_debugger
            case restart_name
            when :backtrace
              puts exception.backtrace
              # loop again
            when :eval
              stream_out.print("code to eval: ")
              eval(stream_in.readline.strip)
              # loop again
            when :raise
              raise
            else
              break Cond.invoke_restart(restart_name)
            end
          else
            break Cond.invoke_restart(restart_name)
          end
        }
      end

      def debugger
        Cond.with_handlers(debugger_handlers) {
          Cond.with_restarts(phony_restarts) {
            yield
          }
        }
      end
    end
  end
end
