require File.dirname(__FILE__) + "/common"

#
# Try to demonstrate symbol recycling by calling GC.start on each pass
# through a symbol-generating loop.
#
# I have not yet seen jruby call the finalizers required for symbol
# recycling.
#

def symbols_spec(&block)
  if defined?(RUBY_ENGINE) and RUBY_ENGINE == "jruby"
    xit "jruby failing #{File.basename(__FILE__)}", &block
  else
    it "should be recycled", &block
  end
end

describe "generated symbols" do
  symbols_spec do
    histogram = Hash.new { |hash, key| hash[key] = 0 }

    300.times { |n|
      obj = Cond::CondPrivate::CodeSection.new(:foo)
      leave, again = obj.instance_eval { [@leave, @again] }
      histogram[leave] += 1
      histogram[again] += 1
      GC.start
    }
      
    histogram.values.any? { |t| t > 1 }.should == true
  end
end
