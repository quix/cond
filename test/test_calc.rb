require "#{File.dirname(__FILE__)}/common"

class DivergedError < StandardError
  attr_reader :epsilon

  def initialize(epsilon)
    super()
    @epsilon = epsilon
  end

  def report
    "Failed to converge with epsilon #{@epsilon}"
  end
end

def calc(x, y, epsilon)
  done, try_again = gensym, gensym

  restarts = {
    :change_epsilon => Cond.restart("Try again with new epsilon.") {
      |new_epsilon|
      epsilon = new_epsilon
      throw try_again
    },
    :give_up => Cond.restart("Skip this calculation.") {
      throw done, nil
    },
  }

  loop_with(done, try_again) {
    Cond.with_restarts(restarts) {
      # ...
      # ... some calculation
      # ...
      if epsilon < 0.01
        raise DivergedError, epsilon
      end
      throw done, 42
    }
  }
end

describe "A calculation which can signal a divergent state" do
  describe "with a handler which increases epsilon" do
    before :all do
      @result = nil
      @memo = []

      epsilon = 0.0005

      handlers = {
        DivergedError => Cond.handler {
          epsilon += 0.001
          @memo.push :increase
          Cond.invoke_restart(:change_epsilon, epsilon)
        }
      }

      @result = Cond.with_handlers(handlers) {
        calc(3, 4, epsilon)
      }
    end

    it "should converge after 10 epsilon increases" do
      @memo.should == (1..10).map { :increase }
    end

    it "should obtain a result" do
      @result.should == 42
    end
  end

  describe "with a give-up handler and a too-small epsilon" do
    before :all do
      @result = 9999
      @memo = []

      epsilon = 1e-10

      handlers = {
        DivergedError => Cond.handler {
          @memo.push :give_up
          Cond.invoke_restart(:give_up)
        }
      }

      @result = Cond.with_handlers(handlers) {
        calc(3, 4, epsilon)
      }
    end

    it "should give up" do
      @memo.should == [:give_up]
    end

    it "should obtain a nil result" do
      @result.should == nil
    end
  end
end

