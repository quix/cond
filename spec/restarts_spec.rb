require File.dirname(__FILE__) + '/cond_spec_base'

require 'jumpstart'

RESTARTS_FILE = File.dirname(__FILE__) + '/../readmes/restarts.rb'

def run_restarts(input_string)
  capture(input_string) {
    Jumpstart::Ruby.no_warnings {
      load RESTARTS_FILE
    }
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
