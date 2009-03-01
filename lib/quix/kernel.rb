
require 'thread'

module Kernel
  def singleton_class
    class << self
      self
    end
  end

  def let
    yield self
  end

  unless respond_to? :tap
    def tap
      yield self
      self
    end
  end

  private

  def with_warnings(value = true)
    previous = $VERBOSE
    $VERBOSE = value
    begin
      yield
    ensure
      $VERBOSE = previous
    end
  end

  def no_warnings(&block)
    with_warnings(false, &block)
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
    private method_name
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
