require File.dirname(__FILE__) + "/common"

describe "basic handler/restart functionality" do
  it "should work" do
    class ExampleError < RuntimeError
    end
    
    memo = []
    
    handlers = {
      ExampleError => Cond.handler {
        memo.push :handler
        Cond.invoke_restart(:example_restart, :x, :y)
      }
    }
    
    restarts = {
      :example_restart => Cond.restart { |*args|
        memo.push :restart
        memo.push args
      }
    }
  
    f = lambda {
      memo.push :f
      Cond.with_restarts(restarts) {
        memo.push :raise
        raise ExampleError
      }
    }
    
    memo.push :first
    Cond.with_handlers(handlers) {
      f.call
    }
    memo.push :last

    memo.should == [:first, :f, :raise, :handler, :restart, [:x, :y], :last]
  end
end
