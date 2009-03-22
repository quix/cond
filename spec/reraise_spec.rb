require File.dirname(__FILE__) + "/common"

class ReraiseExampleError < Exception
end

include Cond

describe "Re-raise" do
  it "should work work with no arguments" do
    lambda {
      handling do
        handle ReraiseExampleError do
          raise
        end
        raise ReraiseExampleError 
      end
    }.should raise_error(ReraiseExampleError)
  end

  describe "with arguments" do
    before :all do
      @memo = []
      @func = lambda {
        begin
          handling do
            handle ReraiseExampleError do
              raise "---test"
            end
            raise ReraiseExampleError 
          end
        rescue Exception => e
          @memo.push e
          raise
        end
      }
    end

    it "should raise the new exception" do
      @func.should raise_error(RuntimeError)
    end

    it "should preserve 'message'" do
      @memo.first.message.should == "---test"
    end
  end

  describe "nested" do
    before :all do
      @memo = []
      @func = lambda {
        handling do
          handle ReraiseExampleError do
            @memo.push :outer
          end 
          handling do
            handle ReraiseExampleError do
              @memo.push :inner
              raise
            end
            raise ReraiseExampleError 
          end
        end
      }
    end

    it "should transfer to handlers earlier in the stack" do
      @func.should_not raise_error
    end
    
    it "should be ordered inside to outside" do
      @memo.should == [:inner, :outer]
    end
  end
end
