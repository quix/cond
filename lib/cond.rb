
require 'cond/kernel'
require 'cond/thread_local_stack'

# 
# Condition system for handling errors in Ruby.  See README.
# 
module Cond
  @handlers_stack, @restarts_stack = (1..2).map {
    ThreadLocalStack.new.tap { |t| t.push(Hash.new) }
  }

  # for default handlers and default restarts
  @stream = ThreadLocal.new { STDERR }

  module_function

  #
  # Register a set of handlers.  The given hash is merged with the
  # set of current handlers.
  #
  # When the block exits, the previous set of handlers (if any) are
  # restored.
  #
  # Example:
  #
  #   handlers = {
  #     #
  #     # We are able to handle Fred errors immediately; no need to unwind
  #     # the stack.
  #     #
  #     FredError => Cond.handler {
  #       # ...
  #       puts "Handled a FredError. Continuing..."
  #     },
  #   
  #     #
  #     # We want to be informed of Wilma errors, but we can't handle them.
  #     #
  #     WilmaError => Cond.handler {
  #       puts "Got a WilmaError. Re-raising..."
  #       raise
  #     },
  #   }
  #
  #   Cond.with_handlers(handlers) {
  #     # ...
  #   }
  #
  def with_handlers(handlers)
    @handlers_stack.push(@handlers_stack.top.merge(handlers))
    begin
      yield
    ensure
      @handlers_stack.pop
    end
  end
  
  #
  # Register a set of restarts.  The given hash is merged with the
  # set of current restarts.
  #
  # When the block exits, the previous set of restarts (if any) are
  # restored.
  #
  # Example:
  #
  #   Cond.with_restarts(:return_nil => Cond.restart { return nil }) {
  #     # ..
  #   }
  #
  def with_restarts(restarts)
    @restarts_stack.push(@restarts_stack.top.merge(restarts))
    begin
      yield
    ensure
      @restarts_stack.pop
    end
  end
    
  #
  # A default handler is provided which runs a simple input loop when
  # an exception is raised.
  #
  def with_default_handlers
    with_handlers(default_handlers) {
      yield
    }
  end

  #
  # Some some default restarts are provided.
  #
  def with_default_restarts
    with_restarts(default_restarts) {
      yield
    }
  end

  #
  # Registers the default handlers and default restarts, and adds a
  # restart to leave the input loop.
  #
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

  #
  # The current set of restarts which have been registered.
  #
  def available_restarts
    @restarts_stack.top
  end
    
  #
  # Find a restart by name.
  #
  def find_restart(name)
    available_restarts[name]
  end

  #
  # Call a restart; optionally pass it some arguments.
  #
  def invoke_restart(name, *args)
    find_restart(name).call(*args)
  end

  #
  # Restart: an outlet to allow callers to hook into your code.
  #
  class Restart < Proc
    attr_accessor :report
  end

  #
  # Handler: a function called when an exception is raised; invoke
  # restarts from here.
  #
  class Handler < Proc
    attr_accessor :report
  end

  #
  # Define a restart.  This is optional: you could just pass lambdas
  # or Procs to with_restarts, but you'll miss the description string
  # shown inside Cond#debugger.
  #
  def restart(report = "", &block)
    Restart.new(&block).tap { |t| t.report = report }
  end

  #
  # Define a handler.  This is optional: you could just pass lambdas
  # or Procs to with_handlers, but you'll miss the description string
  # shown by whatever tools that use it (currently none).
  #
  def handler(report = "", &block)
    Handler.new(&block)
  end
  
  def find_handler(exception)  # :nodoc:
    if exception.nil?
      nil
    else
      handler = @handlers_stack.top[exception]
      if handler
        handler
      else
        # find the handler closest in the ancestry
        ancestors = (
          if exception.is_a? String
            RuntimeError
          elsif exception.is_a? Exception
            exception.class
          else
            exception
          end
        ).ancestors
        @handlers_stack.top.inject(Array.new) { |acc, (klass, func)|
          if index = ancestors.index(klass)
            acc << [index, func]
          else
            acc
          end
        }.sort_by { |elem| elem.first }.first.let { |t| t and t[1] }
      end
    end
  end

  #
  # Allow handlers to be called from C code by wrapping a method with
  # begin/rescue.  Returns the aliased name of the original method.
  #
  # See the README.
  #
  # Example:
  #
  #   Cond.wrap_instance_method(Fixnum, :/)
  #
  def wrap_instance_method(mod, method)
    "cond_original_#{mod.name}_#{method}_#{gensym}".to_sym.tap { |original|
      # use eval since 1.8.6 cannot handle |&block|
      mod.module_eval %{
        alias_method :"#{original}", :"#{method}"
        def #{method}(*args, &block)
          begin
            send(:"#{original}", *args, &block)
          rescue Exception => e
            raise e
          end
        end
      }
    }
  end

  #
  # Allow handlers to be called from C code by wrapping a method with
  # begin/rescue.  Returns the aliased name of the original method.
  #
  # See the README.
  #
  # Example:
  #
  #   Cond.wrap_singleton_method(IO, :read)
  #
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
    
    restarts = available_restarts.keys.map { |t| t.to_s }.sort.map { |name|
      {
        :name => name,
        :func => available_restarts[name.to_sym],
      }
    }
    
    index = loop_with(:done, :again) {
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
        throw :done, input.to_i
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
      # we are inside a handler
      if args.empty?
        cond_original_raise(*exception_inside_handler.top)
      else
        cond_original_raise(*args)
      end
    else
      # not inside a handler
      handler = Cond.find_handler(
        if args.empty?
          $!
        else
          args.first
        end
      )
      if handler
        # raise/rescue to generate exception.backtrace
        begin
          cond_original_raise(*args)
        rescue Exception => exception
        end
        
        backtrace_args = [exception, *args[1..-1]]
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
