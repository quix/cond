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
  
    a.value.x.should eql(33)
    other_value.should eql(44)
    a.clear { 99 }
    a.value.should eql(99)
  end
  
  it "should work with included accessor_module" do
    a = Class.new {
      include Cond::CondPrivate::ThreadLocal.accessor_module(:x) { 33 }
    }.new
    a.x.should eql(33)
    a.x = 44
    a.x.should eql(44)
  end
end
