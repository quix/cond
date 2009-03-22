require File.dirname(__FILE__) + "/common"

__END__
#
# By garbage colleting every cycle, we can demonstrate symbol
# recycling is working if the symbol count levels off.
#
# For MRI 1.8 @count is between 20 and 30.  For MRI 1.9 it is exactly
# 20.  For jruby it forever increases, which presumably is a bug.
#
loop {
  obj = Cond::CondInner::CodeSection.new(:foo)
  Cond::CondInner::SymbolGenerator.instance_eval {
    puts @count
  }
  GC.start
}
