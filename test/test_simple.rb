$LOAD_PATH.unshift "#{File.dirname(__FILE__)}/../lib"

require 'cond'

FredError, WilmaError, BarneyError = (1..3).map {
  Class.new(RuntimeError)
}

handlers = {
  #
  # For some reason we are able to handle Fred errors immediately; no
  # need to unwind the stack.
  #
  FredError => lambda { |exception, *args|
    puts "Handled a FredError. Continuing..."
  },

  #
  # We want to be informed of Wilma errors, but we can't handle them.
  #
  WilmaError => lambda { |exception, *args|
    puts "Got a WilmaError. Re-raising..."
    # actually raise it now
    raise exception, *args
  },

  #
  # If an error occurs during a Barney calculation, try twice more;
  # thereafter, give up.
  #
  BarneyError => let {
    num_errors = 0
    lambda { |exception, *args|
      num_errors += 1
      if num_errors <= 3
        throw :retry_barney
      else
        raise exception, *args
      end
    }
  }
}

Cond.with_handlers(handlers) {
  Cond.with_default_restarts {
  begin
    raise FredError

    Cond.with_handlers(WilmaError => lambda { puts "Ignored Wilma." }) {
      #
      # For some reason we want to ignore Wilma errors here.
      # 
      raise WilmaError
      raise FredError
    }

    begin
      loop {
        catch(:retry_barney) {
          puts "Starting Barney calculation..."
          raise BarneyError
        }
      }
    rescue BarneyError
      puts "Gave up on Barney."
    end

    raise WilmaError
  rescue => e
    puts "Rescued: #{e.inspect}."
  end
}
}
