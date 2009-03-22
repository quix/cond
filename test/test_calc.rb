require File.dirname(__FILE__) + "/common"

include Cond

class DivergedError < StandardError
  attr_reader :epsilon

  def initialize(epsilon)
    super()
    @epsilon = epsilon
  end

  def message
    "Failed to converge with epsilon #{@epsilon}"
  end
end

def calc(x, y, epsilon)
  restartable do
    restart :change_epsilon do |new_epsilon|
      epsilon = new_epsilon
      again
    end
    restart :give_up do
      leave
    end
    # ...
    # ... some calculation
    # ...
    if epsilon < 0.01
      raise DivergedError.new(epsilon)
    end
    42
  end
end

describe "A calculation which can raise a divergent error," do
  describe "with a handler which increases epsilon" do
    before :all do
      handling do
        @memo = []
        @result = nil
        epsilon = 0.0005
        handle DivergedError do
          epsilon += 0.001
          @memo.push :increase
          invoke_restart :change_epsilon, epsilon
        end
        @result = calc(3, 4, epsilon)
      end
    end

    it "should converge after repeated epsilon increases" do
      @memo.should == (1..10).map { :increase }
    end

    it "should obtain a result" do
      @result.should == 42
    end
  end

  describe "with a give-up handler and a too-small epsilon" do
    before :all do
      handling do
        @result = 9999
        @memo = []
        epsilon = 1e-10
        handle DivergedError do
          @memo.push :give_up
          invoke_restart :give_up
        end
        @result = calc(3, 4, epsilon)
      end
    end

    it "should give up" do
      @memo.should == [:give_up]
    end

    it "should obtain a nil result" do
      @result.should == nil
    end
  end
end
