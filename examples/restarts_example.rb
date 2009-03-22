here = File.dirname(__FILE__)
require here + "/../spec/common"
require 'stringio'

file = here + "/../readmes/restarts.rb"

run_restarts = lambda { |string|
  previous = [
    $stdout, $stdin, Cond.defaults.stream_out, Cond.defaults.stream_in
  ]
  begin
    StringIO.open("", "r+") { |output|
      StringIO.open(string) { |input|
        Cond.defaults.stream_out = output
        Cond.defaults.stream_in = input
        $stdout = output
        $stdin = input
        load file
      }
      output.rewind
      output.read
    }
  ensure
    $stdout, $stdin, Cond.defaults.stream_out, Cond.defaults.stream_in =
      previous
  end
}

describe file do
  it "should fetch with with alternate hash" do
    hash = { "mango" => "mangoish fruit" }
    re = %r!#{hash.values.first}!
    run_restarts.call(%{2\n#{hash.inspect}\n}).should match(re)
  end

  it "should fetch with alternate value" do
    run_restarts.call(%{3\n"apple"\n}).should match(%r!value: "fruit"!)
  end
end
