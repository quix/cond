require File.dirname(__FILE__) + "/common"

require 'cond/dsl'

describe "singleton method defined in C" do
  before :all do
    @memo = []
    @define_handler = lambda {
      handle ArgumentError do
        @memo.push :handled
      end
    }
  end

  describe "unwrapped" do
    it "should unwind" do
      lambda {
        handling do
          @define_handler.call
          IO.read
        end
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
        handling do
          @define_handler.call
          IO.read
        end
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
    @define_handler = lambda {
      handle ZeroDivisionError do |exception|
        @memo.push :handled
      end
    }
  end

  describe "unwrapped" do
    it "should unwind" do
      lambda {
        handling do
          @define_handler.call
          3/0
        end
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
        handling do
          @define_handler.call
          3/0
        end
      }.should_not raise_error(ZeroDivisionError )
    end

    it "should call handler" do
      @memo.should == [:handled]
    end
  end
end
