$LOAD_PATH.unshift File.dirname(__FILE__) + "/../lib"
$LOAD_PATH.unshift File.dirname(__FILE__) + "/../devel"

require 'cond'
require 'spec/autorun'
require 'stringio'

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
