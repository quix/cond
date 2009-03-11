
require 'cond/module'
require 'thread'

module Kernel
  unless instance_method_defined? :singleton_class
    def singleton_class
      class << self
        self
      end
    end
  end

  unless instance_method_defined? :tap
    def tap
      yield self
      self
    end
  end

  unless instance_method_defined? :let
    def let
      yield self
    end
  end

  private

  unless instance_method_defined? :system_or_raise
    def system_or_raise(*args)
      unless system(*args)
        raise "system(*#{args.inspect}) failed with status #{$?.exitstatus}"
      end
    end
  end
  
  let {
    name = :gensym
    unless instance_method_defined? name
      mutex = Mutex.new
      count = 0
      define_method(name) { |*args|
        mutex.synchronize {
          count += 1
        }
        case args.size
        when 0
          :"G#{count}"
        when 1
          :"|#{args.first}#{count}|"
        else
          raise ArgumentError, "wrong number of arguments (#{args.size} for 1)"
        end
      }
      private name
    end
  }

  unless instance_method_defined? :loop_with
    def loop_with(done = gensym, again = gensym)
      catch(done) {
        while true
          catch(again) {
            yield(done, again)
          }
        end
      }
    end
  end
end
