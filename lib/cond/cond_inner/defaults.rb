
require 'cond/cond_inner/symbol_generator'

module Cond
  module CondInner
    module Defaults
      module_function
  
      def default_handler(exception)
        stream = Cond.stream
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
        
        index = LoopWith.loop_with(:leave) {
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
            throw :leave, input.to_i
          end
        }
        restarts[index][:func].call(exception)
      end
      
      def default_handlers
        {
          Exception => method(:default_handler)
        }
      end
  
      def default_restarts
        {
          :raise => Cond::Restart.new("Raise this exception.") {
            raise
          },
          :eval => Cond::Restart.new("Run some code.") {
            Cond.stream.print("Enter code: ")
            eval(STDIN.readline.strip)
          },
          :backtrace => Cond::Restart.new("Show backtrace.") { |exception|
            Cond.stream.puts exception.backtrace
          },
        }
      end
  
      def stream
        STDERR
      end
    end
  end
end
