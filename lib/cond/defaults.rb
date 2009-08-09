
module Cond
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

    def handler(exception)
      stream_out.puts exception.backtrace.last

      if exception.respond_to? :message
        stream_out.puts exception.message, ""
      end
        
      #
      # Show restarts in the order they appear on the stack (via
      # partial differences).
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
      Cond.invoke_restart(restart_names[restart_index])
    end
  end
end
