require "#{File.dirname(__FILE__)}/common"

Dir["#{File.dirname(__FILE__)}/test_*.rb"].each { |test|
  Cond::Test::Ruby.run_or_raise(test, *ARGV)
}
