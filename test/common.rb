
here = File.dirname(__FILE__)
$LOAD_PATH.unshift "#{here}/../lib"
$LOAD_PATH.unshift "#{here}/../support"

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

# from zentest_assertions.rb by Ryan Davis
def capture_io
  require 'stringio'
  orig_stdout = $stdout.dup
  orig_stderr = $stderr.dup
  captured_stdout = StringIO.new
  captured_stderr = StringIO.new
  $stdout = captured_stdout
  $stderr = captured_stderr
  yield
  captured_stdout.rewind
  captured_stderr.rewind
  return captured_stdout.string, captured_stderr.string
ensure
  $stdout = orig_stdout
  $stderr = orig_stderr
end
