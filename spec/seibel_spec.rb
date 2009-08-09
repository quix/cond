require File.dirname(__FILE__) + "/common"
require 'cond/dsl'

seibel_file = File.dirname(__FILE__) + "/../readmes/seibel_pcl.rb"

if RUBY_VERSION >= "1.8.7"
  describe seibel_file do
    it "should run" do
      lambda {
        capture("0\n") {
          load seibel_file
        }
      }.should_not raise_error
    end
  end
end
