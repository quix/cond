
require 'cond/util'
require 'cond/invade'
require 'cond/thread_local_stack'

module Cond
  extend Util

  @handlers_stack, @restarts_stack = (1..2).map {
    ThreadLocalStack.new.tap { |t| t.push(Hash.new) }
  }

  # for default handlers and default restarts
  @stream = ThreadLocal.new { STDERR }

  module_function

  def with_handlers(handlers)
    @handlers_stack.push(@handlers_stack.top.merge(handlers))
    begin
      yield
    ensure
      @handlers_stack.pop
    end
  end
  
  def with_restarts(restarts)
    @restarts_stack.push(@restarts_stack.top.merge(restarts))
    begin
      yield
    ensure
      @restarts_stack.pop
    end
  end
    
  def with_default_handlers(&block)
    with_handlers(default_handlers) {
      block.call
    }
  end

  def with_default_restarts(&block)
    with_restarts(default_restarts) {
      block.call
    }
  end

  def debugger
    restarts = {
      :leave_debugger => restart("Leave #{self}.debugger") {
        throw :leave_debugger
      }
    }
    catch(:leave_debugger) {
      with_default_handlers {
        with_default_restarts {
          with_restarts(restarts) {
            yield
          }
        }
      }
    }
  end

  def available_restarts
    @restarts_stack.top
  end
    
  def find_restart(name)
    available_restarts[name]
  end

  def invoke_restart(name, *args)
    find_restart(name).call(*args)
  end

  class Restart < Proc
    attr_accessor :report
  end

  class Handler < Proc
    attr_accessor :report
  end

  def restart(report = "", &block)
    Restart.new(&block).tap { |t| t.report = report }
  end

  def handler(report = "", &block)
    Handler.new(&block)
  end
  
  def find_handler(exception)
    handler = @handlers_stack.top[exception]
    if handler
      handler
    else
      # find a superclass handler
      catch(found = gensym) {
        ancestors = (
          if exception.is_a? String
            RuntimeError
          elsif exception.is_a? Exception
            exception.class
          else
            exception
          end
        ).ancestors
        @handlers_stack.top.each { |klass, inner_handler|
          if ancestors.include?(klass)
            throw found, inner_handler
          end
        }
        # not found
        nil
      }
    end
  end

  def wrap_instance_method(mod, method)
    mod.module_eval {
      original = instance_method(method)
      remove_method(method)
      define_method(method) { |*args, &block|
        begin
          original.bind(self).call(*args, &block)
        rescue Exception => e
          raise e
        end
      }
    }
  end

  def wrap_singleton_method(mod, method)
    wrap_instance_method(mod.singleton_class, method)
  end

  def default_handlers     ; @default_handlers.value     end
  def default_restarts     ; @default_restarts.value     end
  def stream               ; @stream.value               end

  def default_handlers=(t) ; @default_handlers.value = t end
  def default_restarts=(t) ; @default_restarts.value = t end
  def stream=(t)           ; @stream.value = t           end

  default_handler = lambda { |*args|
    exception = args.first
    stream.puts exception.inspect
    stream.puts exception.backtrace.last
    if exception.respond_to? :report
      stream.puts(exception.report)
      stream.puts
    end
    
    restarts = available_restarts.keys.map(&:to_s).sort.map { |name|
      {
        :name => name,
        :func => available_restarts[name.to_sym],
      }
    }
    
    index = loop_with { |done, again|
      restarts.each_with_index { |restart, inner_index|
        report = let {
          t = restart[:func]
          if t.respond_to?(:report) and t.report != ""
            t.report + " "
          else
            ""
          end
        }
        stream.printf(
          "%3d: %s(:%s)\n",
          inner_index, report, restart[:name]
        )
      }
      stream.print "> "
      input = STDIN.readline.strip
      if input =~ %r!\A\d+\Z! and (0...restarts.size).include?(input.to_i)
        throw done, input.to_i
      end
    }
    restarts[index][:func].call(exception)
  }

  @default_handlers = ThreadLocal.new {
    {
      Exception => default_handler
    }
  }

  @default_restarts = ThreadLocal.new {
    {
      :raise => restart("Raise this exception.") { |exception|
        raise
      },
      :eval => restart("Run some code.") {
        stream.print("Enter code: ")
        eval(STDIN.readline.strip)
      },
      :backtrace => restart("Show backtrace.") { |exception|
        stream.puts exception.backtrace
      },
    }
  }
end

module Kernel
  alias_method :cond_original_raise, :raise

  exception_inside_handler = Cond::ThreadLocalStack.new

  define_method(:raise) { |*args|
    if exception_inside_handler.top
      if args.empty?
        cond_original_raise(*exception_inside_handler.top)
      else
        cond_original_raise(*args)
      end
    else
      handler = Cond.find_handler(args.first)
      if handler
        # raise/rescue to generate exception.backtrace
        begin
          cond_original_raise(*args)
        rescue Exception => exception
        end
        
        backtrace_args = [exception, *args.tail]
        exception_inside_handler.push(backtrace_args)
        begin
          handler.call(*backtrace_args)
        ensure
          exception_inside_handler.pop
        end
      else
        cond_original_raise(*args)
      end
    end
  }
end
