
require 'cond/cond_inner/thread_local'
require 'cond/cond_inner/stack'
require 'cond/cond_inner/loop_with'
require 'cond/cond_inner/symbol_generator'
require 'cond/cond_inner/defaults'

# 
# Handle exceptions without unwinding the stack.  See README.
# 
module Cond
  ######################################################################
  # Restart and Handler 

  module CondInner
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
  end

  #
  # A restart.  Use of this class is optional: you could pass lambdas
  # to Cond.with_restarts, but you'll miss the description string
  # shown inside Cond.default_handler.
  #
  class Restart < CondInner::MessageProc
  end

  #
  # A handler.  Use of this class is optional: you could pass lambdas
  # to Cond.with_handlers, but you'll miss the description string
  # shown by whichever tools might use it (currently none).
  #
  class Handler < CondInner::MessageProc
  end

  ######################################################################
  # errors
  
  #
  # Cond.invoke_restart was called with an unknown restart.
  #
  class NoRestartError < StandardError
  end

  ######################################################################
  # singleton methods

  class << self
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
      # note: leave unfactored due to notable yield vs &block performance
      handlers_stack.push(handlers_stack.top.merge(handlers))
      begin
        yield
      ensure
        handlers_stack.pop
      end
    end
    
    #
    # Register a set of restarts.  The given hash is merged with the
    # set of current restarts.
    #
    # When the block exits, the previous set of restarts (if any) are
    # restored.
    #
    def with_restarts(restarts)
      # note: leave unfactored due to notable yield vs &block performance
      restarts_stack.push(restarts_stack.top.merge(restarts))
      begin
        yield
      ensure
        restarts_stack.pop
      end
    end
      
    #
    # A default handler is provided which runs a simple input loop when
    # an exception is raised.
    #
    def with_default_handlers
      # note: leave unfactored due to notable yield vs &block performance
      with_handlers(default_handlers) {
        yield
      }
    end
  
    #
    # Some default restarts are provided.
    #
    def with_default_restarts
      # note: leave unfactored due to notable yield vs &block performance
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
      restarts_stack.top
    end
      
    #
    # Find a restart by name.
    #
    def find_restart(name)
      available_restarts[name]
    end
  
    #
    # Find the closest-matching handler for the given Exception.
    #
    def find_handler(target)
      handlers_stack.top.fetch(target) {
        found = handlers_stack.top.inject(Array.new) { |acc, (klass, func)|
          index = target.ancestors.index(klass)
          if index
            acc << [index, func]
          else
            acc
          end
        }.sort_by { |t| t.first }.first
        found and found[1]
      }
    end
  
    def run_code_section(klass, &block) #:nodoc:
      section = klass.new(&block)
      Cond.code_section_stack.push(section)
      begin
        section.instance_eval { run }
      ensure
        Cond.code_section_stack.pop
      end
    end

    ###############################################
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
      original = "cond_original_#{mod.inspect}_#{method.inspect}"
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
      original
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
  
    ###############################################
    # original raise
    
    #
    # MRI 1.9 does not like this.  Now aliased in Kernel.
    #
    #define_method :original_raise, Kernel.instance_method(:raise)
    #module_function :original_raise

    ######################################################################
    # data -- all data is per-thread and fetched from the singleton class
    
    stack_0  = lambda { |*| CondInner::Stack.new }
    stack_1  = lambda { |*| CondInner::Stack.new.push(Hash.new) }
    defaults = lambda { |name| CondInner::Defaults.send(name) }
    {
      :code_section_stack => stack_0,
      :exception_stack    => stack_0,
      :handlers_stack     => stack_1,
      :restarts_stack     => stack_1,
      :stream             => defaults,
      :default_handlers   => defaults,
      :default_restarts   => defaults,
    }.each_pair { |name, init|
      include CondInner::ThreadLocal.accessor_module(name) {
        init.call(name)
      }
    }
  end

  ######################################################################
  
  module CondInner
    class CodeSection  #:nodoc:
      include LoopWith
      include SymbolGenerator
      
      def initialize(with, &block)
        @with = with
        @block = block
        @leave, @again = gensym, gensym
        SymbolGenerator.track(self, [@leave, @again])
      end
      
      def again(*args)
        throw @again
      end

      def leave(*args)
        case args.size
        when 0
          throw @leave
        when 1
          throw @leave, args.first
        else
          throw @leave, args
        end
      end

      def run
        loop_with(@leave, @again) {
          Cond.send(@with, Hash.new) {
            throw @leave, @block.call
          }
        }
      end
    end

    class RestartableSection < CodeSection  #:nodoc:
      def initialize(&block)
        super(:with_restarts, &block)
      end
      
      def on(sym, message, &block)
        Cond.restarts_stack.top[sym] = Restart.new(message, &block)
      end
    end

    class HandlingSection < CodeSection  #:nodoc:
      def initialize(&block)
        super(:with_handlers, &block)
      end
      
      def on(sym, message, &block)
        Cond.handlers_stack.top[sym] = Handler.new(message, &block)
      end
    end
  end

  ######################################################################
  # shiny exterior

  module_function

  #
  # Begin a handling block.  Inside this block, exceptions may be
  # handled without unwinding the stack.
  #
  def handling(&block)
    Cond.run_code_section(CondInner::HandlingSection, &block)
  end

  #
  # Begin a restartable block.  A handler may transfer control to one
  # of the restarts in this block.
  #
  def restartable(&block)
    Cond.run_code_section(CondInner::RestartableSection, &block)
  end
  
  #
  # Define a handler or a restart.
  #
  # When inside a handling block, define a handler.  The exception
  # instance is passed to the block.
  #
  # When inside a restartable block, define a restart.  When a
  # handler calls invoke_restart, it may pass additional arguments
  # which are in turn passed to &block.
  #
  def on(arg, message = "", &block)
    Cond.code_section_stack.top.on(arg, message, &block)
  end

  #
  # Leave the current handling or restartable block, optionally
  # providing a value for the block.
  #
  # The semantics are the same as 'return'.  When given multiple
  # arguments, it returns an array.  When given one argument, it
  # returns only that argument (not an array).
  #
  def leave(*args)
    Cond.code_section_stack.top.leave(*args)
  end

  #
  # Run the handling or restartable block again.
  #
  # Optionally pass arguments which are given to the block.
  #
  def again(*args)
    Cond.code_section_stack.top.again(*args)
  end

  #
  # Call a restart from a handler; optionally pass it some arguments.
  #
  def invoke_restart(name, *args, &block)
    Cond.available_restarts.fetch(name) {
      raise(
        NoRestartError,
        "Did not find `#{name.inspect}' in available restarts"
      )
    }.call(*args, &block)
  end
end

module Kernel
  alias_method :cond_original_raise, :raise
  remove_method :raise
  def raise(*args)
    if Cond.exception_stack.top
      # we are inside a handler
      if args.empty?
        cond_original_raise(Cond.exception_stack.top)
      else
        cond_original_raise(*args)
      end
    else
      exception = nil
      # not inside a handler
      begin
        cond_original_raise(*args)
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
        cond_original_raise(exception)
      end
    end
  end
  alias_method :cond_original_fail, :fail
  remove_method :fail
  alias_method :fail, :raise
end
