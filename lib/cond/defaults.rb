
require 'cond'

module Cond
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
      
      index = loop_with(:done) {
        restarts.each_with_index { |restart, inner_index|
          message = let {
            t = restart[:func]
            if t.respond_to?(:message) and t.message != ""
              t.message + " "
            else
              ""
            end
          }
          stream.printf(
            "%3d: %s(:%s)\n",
            inner_index, message, restart[:name]
          )
        }
        stream.print "> "
        stream.flush
        input = STDIN.readline.strip
        if input =~ %r!\A\d+\Z! and (0...restarts.size).include?(input.to_i)
          throw :done, input.to_i
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
        :raise => restart("Raise this exception.") { |exception|
          raise
        },
        :eval => restart("Run some code.") {
          Cond.stream.print("Enter code: ")
          eval(STDIN.readline.strip)
        },
        :backtrace => restart("Show backtrace.") { |exception|
          Cond.stream.puts exception.backtrace
        },
      }
    end

    def stream
      STDERR
    end
  end
end
