require File.dirname(__FILE__) + "/common"

class ExampleError < RuntimeError
end

include Cond

describe Cond do
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
        with_restarts(restarts) {
          memo.push :raise
          raise ExampleError
        }
      }
    
      memo.push :first
      with_handlers(handlers) {
        f.call
      }
      memo.push :last
      
      memo.should == [:first, :f, :raise, :handler, :restart, [:x, :y], :last]
    end

    it "should work using the shiny form" do
      memo = []

      f = lambda {
        restartable do
          body do
            memo.push :f
            memo.push :raise
            raise ExampleError
          end
          restart :example_restart do |*args|
            memo.push :restart
            memo.push args
          end
        end
      }
    
      memo.push :first
      handling do
        body do
          f.call
        end
        handle ExampleError do
          memo.push :handler
          invoke_restart :example_restart, :x, :y
        end
      end
      memo.push :last

      memo.should == [:first, :f, :raise, :handler, :restart, [:x, :y], :last]
    end
  end

  it "should raise NoRestartError when restart is not found" do
    lambda {
      invoke_restart(:zzz)
    }.should raise_error(Cond::NoRestartError)
  end
end
