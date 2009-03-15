require File.dirname(__FILE__) + "/common"

class ExampleError < RuntimeError
end

describe Cond do
  describe "basic handler/restart functionality" do
    it "should work using the raw form" do
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

    it "should work using the shiny form" do
      memo = []

      f = lambda {
        Cond.restartable do
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
      Cond.handling do
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
      Cond.invoke_restart(:zzz)
    }.should raise_error(Cond::NoRestartError)
  end
end
