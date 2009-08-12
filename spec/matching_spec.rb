require File.dirname(__FILE__) + '/cond_spec_base'

class AnimalError < StandardError ; end
class BirdError < AnimalError ; end
class SparrowError < BirdError ; end
class DogError < AnimalError ; end
class RawError < Exception ; end

RANDOM_ERRORS = [
  Exception,
  RuntimeError,
  AnimalError,
  BirdError,
  SparrowError,
  DogError,
  RawError,
]

describe "handler matching system" do
  before :all do
    @memo = []
    @handlers = RANDOM_ERRORS.inject(Hash.new) { |acc, ex|
      acc.merge!(ex => lambda { |t| @memo.push ex })
    }
  end

  it "should find an exact match when it is the only option" do
    @memo.clear
    Cond.with_handlers(DogError => @handlers[DogError]) {
      raise DogError
    }
    @memo.should == [DogError]
  end
  
  it "should find an exact match among other matches" do
    @memo.clear
    Cond.with_handlers(@handlers) {
      raise DogError
    }
    @memo.should == [DogError]
  end

  it "should find a match given an Exception instance" do
    @memo.clear
    Cond.with_handlers(@handlers) {
      raise DogError.new
    }
    @memo.should == [DogError]
  end

  it "should not find non-matches" do
    lambda {
      Cond.with_handlers(BirdError => lambda { |e| }) {
        raise DogError
      }
    }.should raise_error(DogError)
  end
  
  it "should find a related match" do
    @memo.clear
    Cond.with_handlers(BirdError => @handlers[BirdError]) {
      raise SparrowError
    }
    @memo.should == [BirdError]
  end

  it "should find the closest related match" do
    @memo.clear
    handlers = {
      BirdError => @handlers[BirdError],
      AnimalError => @handlers[AnimalError],
    }
    Cond.with_handlers(handlers) {
      raise SparrowError
    }
    @memo.should == [BirdError]
  end

  it "should work with the catch-all handler" do
    @memo.clear
    Cond.with_handlers(@handlers) {
      raise SyntaxError
    }
    @memo.should == [Exception]
  end
end
