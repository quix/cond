$LOAD_PATH.unshift File.dirname(__FILE__) + "/../lib"
$LOAD_PATH.unshift File.dirname(__FILE__) + "/../support"

require 'cond'
require 'pathname'

# darn rspec warnings
$VERBOSE = false
begin
  require 'spec'
rescue LoadError
  require 'rubygems'
  require 'spec'
end

def pipe_to_ruby(code)
  require 'quix/ruby'
  IO.popen(%{"#{Quix::Ruby::EXECUTABLE}"}, "r+") { |pipe|
    pipe.puts code
    pipe.close_write
    pipe.read
  }
end
