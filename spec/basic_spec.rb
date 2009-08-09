require File.dirname(__FILE__) + "/common"

class ExampleError < RuntimeError
end

require 'cond/dsl'

describe "basic handler/restart functionality" do
  it "should work using the raw form" do
    memo = []
    handlers = {
      ExampleError => lambda { |exception|
        memo.push :handler
        invoke_restart(:example_restart, :x, :y)
      }
    }
    restarts = {
      :example_restart => lambda { |*args|
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

  it "should work using the shiny form" do
    memo = []

    f = lambda {
      memo.push :f
      restartable do
        restart :example_restart do |*args|
          memo.push :restart
          memo.push args
        end
        memo.push :raise
        raise ExampleError
      end
    }
  
    memo.push :first
    handling do
      handle ExampleError do
        memo.push :handler
        invoke_restart :example_restart, :x, :y
      end
      f.call
    end
    memo.push :last

    memo.should == [:first, :f, :raise, :handler, :restart, [:x, :y], :last]
  end
end
