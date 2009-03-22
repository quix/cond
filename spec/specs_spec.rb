here = File.dirname(__FILE__)
require here + "/common"

require 'quix/ruby'

describe "specs" do
  it "should run individually" do
    (Dir["#{here}/*_spec.rb"] + Dir["#{here}/../examples/*_example.rb"]).each {
      |spec|
      unless File.basename(spec) == File.basename(__FILE__)
        `"#{Quix::Ruby::EXECUTABLE}" "#{spec}"`
        $?.exitstatus.should == 0
      end
    }
  end
end
