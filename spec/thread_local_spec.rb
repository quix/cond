require File.dirname(__FILE__) + "/common"

require 'ostruct'

describe "ThreadLocal" do
  it "should keep independent values in separate threads" do
    a = Cond::CondPrivate::ThreadLocal.new { OpenStruct.new }
    a.value.x = 33
    other_value = nil
    Thread.new {
      a.value.x = 44
      other_value = a.value.x
    }.join
  
    a.value.x.should == 33
    other_value.should == 44
    a.clear { 99 }
    a.value.should == 99
  end
  
  it "should implement accessor module" do
    a = Class.new {
      include Cond::CondPrivate::ThreadLocal.accessor_module(:x) { 33 }
    }.new
    a.x.should == 33
    a.x = 44
    a.x.should == 44
  end
end
