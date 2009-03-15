$LOAD_PATH.unshift "#{File.dirname(__FILE__)}/../lib"

require 'cond'
include Cond  # (optional)

FredError, WilmaError, BarneyError = (1..3).map {
  Class.new RuntimeError
}

handlers = {
  #
  # We are able to handle Fred errors immediately; no need to unwind
  # the stack.
  #
  FredError => handler {
    # ...
    puts "Handled a FredError. Continuing..."
  },

  #
  # We want to be informed of Wilma errors, but we can't handle them.
  #
  WilmaError => handler {
    puts "Got a WilmaError. Re-raising..."
    raise
  },

  #
  # If an error occurs during a Barney calculation, try twice more;
  # thereafter, give up.
  #
  BarneyError => let {   # let { } is equivalent to lambda { }.call
    num_errors = 0
    handler {
      num_errors += 1
      if num_errors < 3
        puts "Got BarneyError ##{num_errors}. Retrying..."
        throw :retry_barney
      else
        puts "Got BarneyError ##{num_errors}. Giving up..."
        raise
      end
    }
  }
}

with_handlers(handlers) {
  raise FredError
  # => Handled a FredError. Continuing...
    
  #
  # We want to ignore Wilma errors here.
  # 
  with_handlers(WilmaError => handler { puts "Ignored WilmaError." }) {
    raise WilmaError
    # => Ignored WilmaError.
    
    # the FredError handler is still active
    raise FredError
    # => Handled a FredError. Continuing...
  }

  #
  # The previous WilmaError handler has been restored.
  #
  begin
    raise WilmaError, "should not be ignored"
  rescue WilmaError => e
    puts "Rescued: #{e.inspect}"
  end
  # => Got a WilmaError. Re-raising...
  # => Rescued: #<WilmaError: should not be ignored>
    
  begin
    loop {
      catch(:retry_barney) {
        puts "Starting Barney calculation..."
        # ...
        raise BarneyError
      }
    }
  rescue BarneyError
    puts "Gave up on Barney."
  end
  # => Starting Barney calculation...
  # => Got BarneyError #1. Retrying...
  # => Starting Barney calculation...
  # => Got BarneyError #2. Retrying...
  # => Starting Barney calculation...
  # => Got BarneyError #3. Giving up...
  # => Gave up on Barney.
}
