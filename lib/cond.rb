
require 'cond/ext'
require 'cond/thread_local'
require 'cond/stack'
require 'cond/defaults'
require 'cond/loop_with'

# 
# Condition system for handling errors in Ruby.  See README.
# 
module Cond
  include Ext
  include LoopWith
  include Generator

  #
  # Cond.invoke_restart was called with an unknown restart.
  #
  class NoRestartError < StandardError
  end

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
    Cond.handlers_stack.push(Cond.handlers_stack.top.merge(handlers))
    begin
      yield
    ensure
      Cond.handlers_stack.pop
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
    Cond.restarts_stack.push(Cond.restarts_stack.top.merge(restarts))
    begin
      yield
    ensure
      Cond.restarts_stack.pop
    end
  end
    
  #
  # A default handler is provided which runs a simple input loop when
  # an exception is raised.
  #
  def with_default_handlers
    with_handlers(Cond.default_handlers) {
      yield
    }
  end

  #
  # Some some default restarts are provided.
  #
  def with_default_restarts
    with_restarts(Cond.default_restarts) {
      yield
    }
  end

  #
  # Registers the default handlers and default restarts, and adds a
  # restart to leave the input loop.
  #
  def debugger
    restarts = {
      :leave_debugger => restart("Leave debugger") {
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
    Cond.restarts_stack.top
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
  def invoke_restart(name, *args, &block)
    available_restarts.fetch(name) {
      raise(
        NoRestartError,
        "Did not find `#{name.inspect}' in available restarts"
      )
    }.call(*args, &block)
  end

  #
  # Define a handler.  This is optional: you could just pass lambdas
  # or Procs to with_handlers, but you'll miss the description string
  # shown by whatever tools that use it (currently none).
  #
  def handler(message = "", &block)
    # this particular contortion is to avoid a jruby bug
    Proc.new(&block).extend(Ext).tap { |func|
      func.singleton_class.module_eval {
        define_method(:message) {
          message
        }
      }
    }
  end
  
  #
  # Define a restart.  This is optional: you could just pass lambdas
  # or Procs to with_restarts, but you'll miss the description string
  # shown inside Cond#debugger.
  #
  alias_method :restart, :handler
  module_function :restart

  def find_handler(target)
    Cond.handlers_stack.top.fetch(target) {
      Cond.handlers_stack.top.inject(Array.new) { |acc, (klass, func)|
        if index = target.ancestors.index(klass)
          acc << [index, func]
        else
          acc
        end
      }.sort_by { |t| t.first }.first.extend(Ext).let { |t| t and t[1] }
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
  #   Cond.wrap_instance_method(Fixnum, :/)
  #
  def wrap_instance_method(mod, method)
    "cond_original_#{mod.inspect}_#{method.inspect}".extend(Ext).tap {
      |original|
      # TODO: jettison 1.8.6, remove eval and use |&block|
      mod.module_eval %{
        alias_method :'#{original}', :'#{method}'
        def #{method}(*args, &block)
          begin
            send(:'#{original}', *args, &block)
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
    singleton_class = class << mod ; self ; end
    wrap_instance_method(singleton_class, method)
  end
  
  ######################################################################
  # singleton class

  class << self
    [:handlers_stack, :restarts_stack].each { |name|
      include ThreadLocal.accessor_module(name) {
        Stack.new.extend(Ext).tap { |t| t.push(Hash.new) }
      }
    }

    [:stream, :default_handlers, :default_restarts].each { |name|
      include ThreadLocal.accessor_module(name) {
        Defaults.send(name)
      }
    }
  end

  ######################################################################
  # glossy exterior

  def restartable(&block)
    section = RestartableSection.new
    section.instance_eval(&block)
    section.instance_eval { __run__ }
  end
  
  def handling(&block)
    section = HandlingSection.new
    section.instance_eval(&block)
    section.instance_eval { __run__ }
  end

  class CodeSection
    include LoopWith

    private

    def initialize(with_functions)
      @__with_functions = with_functions
      @__functions = Hash.new
      @__done, @__again = (1..2).map { Generator.gensym }
      @__body_args = []
    end

    def body(&block)
      @__body = block
    end
    
    def again(*args)
      @__body_args = args
      throw @__again
    end

    def done(*args)
      case args.size
      when 0
        throw @__done
      when 1
        throw @__done, args.first
      else
        throw @__done, args
      end
    end

    def __run__
      loop_with(@__done, @__again) {
        Cond.send(@__with_functions, @__functions) {
          throw @__done, @__body.call(*@__body_args)
        }
      }
    end
  end

  class RestartableSection < CodeSection
    def initialize
      super(:with_restarts)
    end

    def restart(sym, message = "", &block)
      @__functions[sym] = Cond.restart(message, &block)
    end
  end

  class HandlingSection < CodeSection
    def initialize
      super(:with_handlers)
    end

    def handle(sym, message = "", &block)
      @__functions[sym] = Cond.handler(message, &block)
    end

    def invoke_restart(name, *args, &block)
      Cond.invoke_restart(name, *args, &block)
    end
  end
end

module Kernel
  alias_method :cond_original_raise, :raise

  exception_inside_handler = Cond::ThreadLocal.wrap_new(Cond::Stack)

  define_method(:raise) { |*args|
    if exception_inside_handler.top
      # we are inside a handler
      if args.empty?
        cond_original_raise(exception_inside_handler.top)
      else
        cond_original_raise(*args)
      end
    else
      # not inside a handler
      begin
        cond_original_raise(*args)
      rescue Exception => exception
      end
      handler = Cond.find_handler(exception.class)
      if handler
        exception_inside_handler.push(exception)
        begin
          handler.call(exception)
        ensure
          exception_inside_handler.pop
        end
      else
        cond_original_raise(exception)
      end
    end
  }

  alias_method :cond_original_fail, :fail
  alias_method :fail, :raise
end
