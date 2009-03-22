require File.dirname(__FILE__) + "/common"

#
# By garbage colleting every cycle, we can demonstrate symbol
# recycling is working if the symbol count levels off.
#
# For MRI 1.8 @count is between 20 and 30.  For MRI 1.9 it is exactly
# 20.  For jruby it forever increases, which presumably is a bug.
#

unless defined?(RUBY_ENGINE) and RUBY_ENGINE == "jruby"
  describe "generated symbols" do
    it "should be recycled" do
      200.times { |n|
        Cond::CondInner::CodeSection.new(:foo)
        GC.start
      }
      Cond::CondInner::SymbolGenerator.gensym.to_s.should match(%r!\A\|[a-z]\Z!)
    end
  end
end
