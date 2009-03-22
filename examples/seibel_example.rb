here = File.dirname(__FILE__)
require here + "/../spec/common"

seibel_file = here + "/../readmes/seibel_pcl.rb"

include Cond

if RUBY_VERSION > "1.8.6"
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
