$LOAD_PATH.unshift File.dirname(__FILE__) + "/../lib"
$LOAD_PATH.unshift File.dirname(__FILE__) + "/../support"

# darn rspec warnings
$VERBOSE = false
begin
  require 'spec'
rescue LoadError
  require 'rubygems'
  require 'spec'
end

# NOTE: In jruby this must come after require 'rubygems'
require 'cond'

require 'pathname'

def pipe_to_ruby(code)
  require 'quix/ruby'
  IO.popen(%{"#{Quix::Ruby::EXECUTABLE}"}, "r+") { |pipe|
    pipe.puts code
    pipe.flush
    pipe.close_write
    pipe.read
  }
end
