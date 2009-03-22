here = File.dirname(__FILE__)
require here + "/../spec/common"

RESTARTS_FILE = here + "/../readmes/restarts.rb"

def run_restarts(input_string)
  capture(input_string) {
    load RESTARTS_FILE
  }
end

describe RESTARTS_FILE do
  it "should fetch with with alternate hash" do
    hash = { "mango" => "mangoish fruit" }
    re = %r!#{hash.values.first}!
    run_restarts(%{2\n#{hash.inspect}\n}).should match(re)
  end

  it "should fetch with alternate value" do
    class Cond::Restart
      # coverage hack
      undef :message
    end
    run_restarts(%{3\n"apple"\n}).should match(%r!value: "fruit"!)
  end
end
