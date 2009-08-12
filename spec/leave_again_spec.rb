require File.dirname(__FILE__) + '/cond_spec_base'

require 'cond/dsl'

[:handling, :restartable].each { |keyword|
  describe "arguments to 'leave' have semantics of 'return'" do
    it "should be passed to the #{keyword} block result (none)" do
      send(keyword) do
        leave
      end.should == nil
    end
    it "should be passed to the #{keyword} block result (single)" do
      send(keyword) do
        leave 3
      end.should == 3
    end
    it "should be passed to the #{keyword} block result (multiple)" do
      send(keyword) do
        leave 4, 5
      end.should == [4, 5]
    end
    it "should be passed to the #{keyword} block result (single array)" do
      send(keyword) do
        leave([6, 7])
      end.should == [6, 7]
    end
  end
}

[:handling, :restartable].each { |keyword|
  describe "arguments to 'again' have semantics of 'return'" do
    before :each do
      @memo = []
    end
    it "should be passed to the #{keyword} block args (none)" do
      send(keyword) do |*args|
        @memo.push :visit
        if @memo.size == 2
          args.should eql([])
          again
        elsif @memo.size == 3
          args.should eql([])
          leave
        end
        again
      end
    end
    it "should be passed to the #{keyword} block args (single)" do
      send(keyword) do |*args|
        @memo.push :visit
        if @memo.size == 2
          args.should eql([3])
          again
        elsif @memo.size == 3
          args.should eql([])
          leave
        end
        again 3
      end
    end
    it "should be passed to the #{keyword} block args (multiple)" do
      send(keyword) do |*args|
        @memo.push :visit
        if @memo.size == 2
          args.should eql([4, 5])
          again
        elsif @memo.size == 3
          args.should eql([])
          leave
        end
        again 4, 5
      end
    end
    it "should be passed to the #{keyword} block args (single array)" do
      send(keyword) do |*args|
        @memo.push :visit
        if @memo.size == 2
          args.should eql([6, 7])
          again
        elsif @memo.size == 3
          args.should eql([])
          leave
        end
        again [6, 7]
      end
    end
  end
}
