
require 'thread'

module Cond
  module Generator
    module_function

    def gensym(*args)
      genstr(*args).to_sym
    end

    #
    # define_method avoids module_function + instance variable problems
    #
    name = :genstr
    mutex = Mutex.new
    count = 0
    define_method(name) { |*args|
      mutex.synchronize {
        count += 1
      }
      # TODO: jettison 1.8, use |prefix = nil|
      case args.size
      when 0
        "G#{count}"
      when 1
        "|#{args.first}#{count}|"
      else
        raise ArgumentError, "wrong number of arguments (#{args.size} for 1)"
      end
    }
    module_function name
  end
end
