
require 'cond/thread_local'
require 'cond/stack'
require 'cond/loop_with'
require 'cond/generator'
require 'cond/ext'
require 'cond/defaults'

# 
# Condition system for handling errors in Ruby.  See README.
# 
module Cond
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
  #     FredError => lambda { |exception|
  #       # ...
  #       puts "Handled a FredError. Continuing..."
  #     },
  #   
  #     #
  #     # We want to be informed of Wilma errors, but we can't handle them.
  #     #
  #     WilmaError => lambda { |exception|
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
  #   Cond.with_restarts(:return_nil => lambda { return nil }) {
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
  # Some default restarts are provided.
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
      :leave_debugger => Restart.new("Leave debugger") {
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
  # Call a restart from a handler; optionally pass it some arguments.
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
  # Find the closest-matching handler for the given Exception.
  #
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

  ######################################################################
  # Restart and Handler 

  #
  # Base class for Restart and Handler.
  #
  class MessageProc < Proc
    def initialize(message = "", &block)
      @message = message
    end

    def message
      @message
    end
  end

  #
  # A restart.  Use of this is optional: you could just pass lambdas
  # to with_restarts, but you'll miss the description string shown
  # inside Cond#default_handler.
  #
  class Restart < MessageProc
  end

  #
  # A handler.  Use of this is optional: you could just pass lambdas
  # to with_handlers, but you'll miss the description string shown by
  # whichever tools might use it (currently none).
  #
  class Handler < MessageProc
  end

  ######################################################################
  # wrapping

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
  # errors
  
  #
  # Cond.invoke_restart was called with an unknown restart.
  #
  class NoRestartError < StandardError
  end

  ######################################################################
  # singleton class

  class << self
    include LoopWith
    public :loop_with

    include Generator
    public :gensym

    [:handlers_stack, :restarts_stack].each { |name|
      include ThreadLocal.accessor_module(name) {
        Stack.new.extend(Ext).tap { |t| t.push(Hash.new) }
      }
    }
    
    [:code_section_stack, :exception_stack].each { |name|
      include ThreadLocal.accessor_module(name) {
        Stack.new
      }
    }
    
    [:stream, :default_handlers, :default_restarts].each { |name|
      include ThreadLocal.accessor_module(name) {
        Defaults.send(name)
      }
    }
  end

  ######################################################################
  # shiny exterior

  #
  # Begin a restartable section of code.
  #
  def restartable(&block)
    section = RestartableSection.new
    Cond.code_section_stack.push(section)
    begin
      block.call
      section.instance_eval { run }
    ensure
      Cond.code_section_stack.pop
    end
  end
  
  #
  # Begin a section of code in which exceptions may be handled without
  # unwinding the stack.
  #
  def handling(&block)
    section = HandlingSection.new
    Cond.code_section_stack.push(section)
    begin
      block.call
      section.instance_eval { run }
    ensure
      Cond.code_section_stack.pop
    end
  end

  #
  # Begin the principle portion of a +restartable+ or +handling+
  # section.
  #
  # +again+ may pass arguments to the block parameters of +body+.
  #
  def body(&block)
    Cond.code_section_stack.top.body(&block)
  end

  #
  # Run the +body+ block again.  This is called from inside handlers
  # and restarts.
  #
  # Optionally pass arguments which are given to the +body+ block.
  #
  def again(*args)
    Cond.code_section_stack.top.again(*args)
  end

  #
  # Similar to +return+ for the current +restartable+ or +handling+
  # section.
  #
  # Optionally pass arguments which will be the value returned by the
  # +restartable+ or +handling+ block.
  #
  # It has the semantics of +return+.  When given multiple arguments,
  # it returns an array.  When given one argument, it returns only
  # that argument (not an array).
  #
  def done(*args)
    Cond.code_section_stack.top.done(*args)
  end

  #
  # Define a restart while inside a +restartable+ section.
  #
  def restart(symbol, message = "", &block)
    Cond.code_section_stack.top.restart(symbol, message, &block)
  end

  #
  # Define a handler while inside a +handling+ section.
  #
  def handle(symbol, message = "", &block)
    Cond.code_section_stack.top.handle(symbol, message, &block)
  end
  
  class CodeSection  #:nodoc:
    include LoopWith

    def initialize(with_functions)
      @with_functions = with_functions
      @functions = Hash.new
      @done, @again = (1..2).map { Generator.gensym }
      @body_args = []
    end

    def body(&block)
      @body = block
    end
    
    def again(*args)
      @body_args = args
      throw @again
    end

    def done(*args)
      case args.size
      when 0
        throw @done
      when 1
        throw @done, args.first
      else
        throw @done, args
      end
    end

    def run
      loop_with(@done, @again) {
        Cond.send(@with_functions, @functions) {
          throw @done, @body.call(*@body_args)
        }
      }
    end
  end

  class RestartableSection < CodeSection  #:nodoc:
    def initialize
      super(:with_restarts)
    end

    def restart(sym, message, &block)
      @functions[sym] = Restart.new(message, &block)
    end
  end

  class HandlingSection < CodeSection  #:nodoc:
    def initialize
      super(:with_handlers)
    end

    def handle(sym, message, &block)
      @functions[sym] = Handler.new(message, &block)
    end
  end

  ######################################################################
  # original raise

  define_method :original_raise, &method(:raise)
  module_function :original_raise
end

module Kernel
  remove_method :raise
  def raise(*args)
    if Cond.exception_stack.top
      # we are inside a handler
      if args.empty?
        Cond.original_raise(Cond.exception_stack.top)
      else
        Cond.original_raise(*args)
      end
    else
      # not inside a handler
      begin
        Cond.original_raise(*args)
      rescue Exception => exception
      end
      handler = Cond.find_handler(exception.class)
      if handler
        Cond.exception_stack.push(exception)
        begin
          handler.call(exception)
        ensure
          Cond.exception_stack.pop
        end
      else
        Cond.original_raise(exception)
      end
    end
  end
  remove_method :fail
  alias_method :fail, :raise
end
