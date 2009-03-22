
require 'cond/cond_inner/symbol_generator'

module Cond
  module CondInner
    class Defaults
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
            stream.print("Enter code: ")
            eval(STDIN.readline.strip)
          },
          :backtrace => Restart.new("Show backtrace.") { |exception|
            stream.puts exception.backtrace
          },
        }
      end

      def stream
        STDERR
      end

      def handler(exception)
        stream.puts exception.inspect, exception.backtrace.last

        if exception.respond_to? :message
          stream.puts exception.message, ""
        end
          
        restarts = Cond.available_restarts.keys.map { |t| t.to_s }.sort.map {
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
            stream.printf(
              "%3d: %s(:%s)\n",
              inner_index, message, restart[:name]
            )
          }
          stream.print "> "
          stream.flush
          input = STDIN.readline.strip
          if input =~ %r!\A\d+\Z! and (0...restarts.size).include?(input.to_i)
            break input.to_i
          end
        }
        restarts[index][:func].call(exception)
      end
    end
  end
end
