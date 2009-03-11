require "#{File.dirname(__FILE__)}/common"

require 'quix/ruby'

Dir["#{File.dirname(__FILE__)}/test_*.rb"].each { |test|
  Quix::Ruby.run_or_raise(test, *ARGV)
}
