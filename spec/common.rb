$LOAD_PATH.unshift File.dirname(__FILE__) + "/../lib"
$LOAD_PATH.unshift File.dirname(__FILE__) + "/../support"

# darn rspec warnings
$VERBOSE = false
begin
  require 'spec'
rescue LoadError
  require 'rubygems'
  require 'spec'
end

# NOTE: In jruby this must come after require 'rubygems'
require 'cond'

require 'pathname'
require 'stringio'

def pipe_to_ruby(code)
  require 'quix/ruby'
  IO.popen(%{"#{Quix::Ruby::EXECUTABLE}"}, "r+") { |pipe|
    pipe.puts code
    pipe.flush
    pipe.close_write
    pipe.read
  }
end

def capture(input_string)
  previous = [
    $stdout, $stdin, Cond.defaults.stream_out, Cond.defaults.stream_in
  ]
  begin
    StringIO.open("", "r+") { |output|
      StringIO.open(input_string) { |input|
        Cond.defaults.stream_out = output
        Cond.defaults.stream_in = input
        $stdout = output
        $stdin = input
        yield
        output.rewind
        output.read
      }
    }
  ensure
    $stdout, $stdin, Cond.defaults.stream_out, Cond.defaults.stream_in =
      previous
  end
end
