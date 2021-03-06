require File.dirname(__FILE__) + '/cond_spec_base'

describe "raise replacement" do
  it "should raise" do
    lambda {
      raise NameError
    }.should raise_error(NameError)
  end

  it "should raise RuntimeError for 'raise \"string\"'" do
    lambda {
      raise "The mass of men lead lives of quiet desperation. --Thoreau"
    }.should raise_error(RuntimeError)
  end

  it "should accept the three-argument form" do
    begin
      raise RuntimeError, "msg", ["zz"]
    rescue => e
      [e.class, e.message, e.backtrace].should == [RuntimeError, "msg", ["zz"]]
    end
  end

  it "should raise TypeError if the third arg is not array of strings" do
    ex = nil
    begin
      raise RuntimeError, "zz", Hash.new
    rescue Exception => ex
      ex = ex
    end
    ex.class.should == TypeError
  end

  it "should raise TypeError for random junk arguments" do
    lambda {
      raise "a", "b"
    }.should raise_error(TypeError)
    lambda {
      raise 1, "b"
    }.should raise_error(TypeError)
    lambda {
      raise RuntimeError, "msg", 33
    }.should raise_error(TypeError)
  end

  it "should accept a non-Exception non-String which responds to #exception" do
    klass = Class.new {
      def exception
        RuntimeError.new("my exception")
      end
    }
    begin
      raise klass.new
    rescue => e
      e.message.should == "my exception"
    end
  end

  it "should raise TypeError if the argument is not a String, not " +
    "an Exception, and does not respond to #exception" do
    lambda {
      raise 27
    }.should raise_error(TypeError)
  end

  it "should be aliased to 'fail'" do
    Kernel.instance_method(:raise).should == Kernel.instance_method(:fail)
  end
end
