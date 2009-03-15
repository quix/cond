require File.dirname(__FILE__) + "/common"

require 'quix/ruby'

Dir["#{File.dirname(__FILE__)}/test_*.rb"].each { |test|
  unless Quix::Ruby.run(test)
    raise "test failed: #{test}"
  end
}
