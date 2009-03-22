require File.dirname(__FILE__) + "/common"

include Cond

describe Cond do
  it "should raise NoRestartError when restart is not found" do
    lambda {
      invoke_restart(:zzz)
    }.should raise_error(Cond::NoRestartError)
  end

  it "should raise ContextError when restart called outside " +
    "restartable block" do
    lambda {
      restart :zzz do
      end
    }.should raise_error(Cond::ContextError)
  end

  it "should raise ContextError when restart called inside handling block" do
    lambda {
      handling do
        restart :zzz do
        end
      end
    }.should raise_error(Cond::ContextError)
  end

  it "should raise ContextError when handle called outside handling block" do
    lambda {
      handle RuntimeError do
      end
    }.should raise_error(Cond::ContextError)
  end

  it "should raise ContextError when restart called inside handling block" do
    lambda {
      handling do
        restart :zzz do
        end
      end
    }.should raise_error(Cond::ContextError)
  end

  [:leave, :again].each { |keyword|
    desc =
      "should raise ContextError when #{keyword} called outside " +
      "restartable or handling block"
    it desc do
      lambda {
        send keyword
      }.should raise_error(Cond::ContextError)
    end
  }
end
