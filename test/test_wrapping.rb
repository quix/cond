require File.dirname(__FILE__) + "/common"

describe "singleton method defined in C" do
  before :all do
    @memo = []
    @handlers = {
      ArgumentError => Cond.handler {
        @memo.push :handled
      }
    }
  end

  describe "unwrapped" do
    it "should unwind" do
      lambda {
        Cond.with_handlers(@handlers) {
          IO.read
        }
      }.should raise_error(ArgumentError)
    end
    
    it "should not call handler" do
      @memo.should == []
    end
  end

  describe "wrapped" do
    before :all do
      Cond.wrap_singleton_method(IO, :read)
    end
    
    it "should not unwind" do
      lambda {
        Cond.with_handlers(@handlers) {
          IO.read
        }
      }.should_not raise_error(ArgumentError)
    end

    it "should call handler" do
      @memo.should == [:handled]
    end
  end
end

describe "instance method defined in C" do
  before :all do
    @memo = []
    @handlers = {
      ZeroDivisionError => Cond.handler {
        @memo.push :handled
      }
    }
  end

  describe "unwrapped" do
    it "should unwind" do
      lambda {
        Cond.with_handlers(@handlers) {
          3/0
        }
      }.should raise_error(ZeroDivisionError)
    end

    it "should not call handler" do
      @memo.should == []
    end
  end

  describe "wrapped" do
    before :all do
      Cond.wrap_instance_method(Fixnum, :/)
    end
    
    it "should not unwind" do
      lambda {
        Cond.with_handlers(@handlers) {
          3/0
        }
      }.should_not raise_error(ZeroDivisionError )
    end

    it "should call handler" do
      @memo.should == [:handled]
    end
  end
end
