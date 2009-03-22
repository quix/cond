
require 'cond/cond_private/symbol_generator'

module Cond
  module CondPrivate
    class Defaults
      def initialize
        @stream_in = STDIN
        @stream_out = STDERR
      end

      attr_accessor :stream_in, :stream_out
      
      def handlers
        {
          Exception => method(:handler)
        }
      end
  
      def restarts
        {
          :raise => Restart.new("Raise this exception.") {
            raise
          },
          :eval => Restart.new("Run some code.") {
            stream_out.print("Enter code: ")
            eval(stream_in.readline.strip)
          },
          :backtrace => Restart.new("Show backtrace.") { |exception|
            stream_out.puts exception.backtrace
          },
        }
      end

      def handler(exception)
        stream_out.puts exception.inspect, exception.backtrace.last

        if exception.respond_to? :message
          stream_out.puts exception.message, ""
        end
          
        restarts = Cond.available_restarts.keys.sort_by { |t| t.to_s}.map {
          |name|
          {
            :name => name,
            :func => Cond.available_restarts[name.to_sym],
          }
        }
          
        index = loop {
          restarts.each_with_index { |restart, inner_index|
            t = restart[:func]
            message = (
              if t.respond_to?(:message) and t.message != ""
                t.message + " "
              else
                ""
              end
            )
            stream_out.printf(
              "%3d: #{message}(#{restart[:name].inspect})\n",
              inner_index
            )
          }
          stream_out.print "> "
          stream_out.flush
          input = stream_in.readline.strip
          if input =~ %r!\A\d+\Z! and (0...restarts.size).include?(input.to_i)
            break input.to_i
          end
        }
        restarts[index][:func].call(exception)
      end
    end
  end
end
