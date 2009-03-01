
require 'thread'

module Cond
end

module Cond::Util
  module_function

  def let
    yield self
  end

  def system_or_raise(*args)
    unless system(*args)
      raise "system(*#{args.inspect}) failed with exit status #{$?.exitstatus}"
    end
  end

  let {
    method_name = :gensym
    mutex = Mutex.new
    count = 0

    define_method(method_name) { |*args|
      # workaround for no default args
      prefix = (
        case args.size
        when 0
          :G
        when 1
          args.first
        else
          raise ArgumentError, "wrong number of arguments (#{args.size} for 1)"
        end
      )

      mutex.synchronize {
        count += 1
      }
      "#{prefix}#{count}".to_sym
    }
    module_function method_name
  }

  def loop_with(done = gensym, restart = gensym)
    catch(done) {
      while true
        catch(restart) {
          yield(done, restart)
        }
      end
    }
  end
end
