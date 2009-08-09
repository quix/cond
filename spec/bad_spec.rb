require File.dirname(__FILE__) + "/../spec/common"

#
# This is a bad example because a handler should re-raise if no
# restart is provided.  All bets are off if code directly after a
# 'raise' gets executed.  But for fun let's see what it looks like.
#

require 'cond/dsl'

module BadExample
  A, B = (1..2).map { Class.new RuntimeError }

  memo = []

  describe "bad example" do
    it "should demonstrate how not to use Cond" do
      handling do
        handle A do
          memo.push :ignore_a
        end
        
        handle B do
          memo.push :reraise_b
          raise
        end

        raise A
        # ... still going!
        
        handling do
          handle B do
            memo.push :ignore_b
          end
          raise B
          # ... !
        end

        begin
          raise B, "should not be ignored"
        rescue B => e
          if e.message == "should not be ignored"
            memo.push :rescued_b
          end
        end
      end
      memo.should == [:ignore_a, :ignore_b, :reraise_b, :rescued_b]
    end
  end
end

