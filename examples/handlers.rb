$LOAD_PATH.unshift "#{File.dirname(__FILE__)}/../lib"

require 'cond'

include Cond

FredError, WilmaError, BarneyError = (1..3).map { Class.new RuntimeError }

handling do
  #
  # We are able to handle Fred errors immediately; no need to unwind
  # the stack.
  #
  handle FredError do
    # ...
    puts "Handled a FredError. Continuing..."
  end
  
  #
  # We want to be informed of Wilma errors, but we can't handle them.
  #
  handle WilmaError do
    puts "Got a WilmaError. Re-raising..."
    raise
  end

  body do
    raise FredError
    # => Handled a FredError. Continuing...
    
    handling do
      #
      # We want to ignore Wilma errors here.
      # 
      handle WilmaError do
        puts "Ignored WilmaError."
      end

      body do
        raise WilmaError
        # => Ignored WilmaError.

        # the FredError handler is still active
        raise FredError
        # => Handled a FredError. Continuing...
      end
    end

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

    handling do
      num_errors = 0

      #
      # If an error occurs during a Barney calculation, try twice
      # more; thereafter, give up.
      #
      handle BarneyError do
        num_errors += 1
        if num_errors == 3
          puts "Got BarneyError ##{num_errors}. Giving up..."
          raise
        else
          puts "Got BarneyError ##{num_errors}. Retrying..."
          again
        end
      end

      body do
        begin
          puts "Starting Barney calculation..."
          # ...
          raise BarneyError
        rescue BarneyError
          puts "Gave up on Barney."
        end
      end
    end
    # => Starting Barney calculation...
    # => Got BarneyError #1. Retrying...
    # => Starting Barney calculation...
    # => Got BarneyError #2. Retrying...
    # => Starting Barney calculation...
    # => Got BarneyError #3. Giving up...
    # => Gave up on Barney.
  end
end

