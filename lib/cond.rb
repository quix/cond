
require 'cond/cond_private/thread_local'
require 'cond/cond_private/symbol_generator'
require 'cond/cond_private/defaults'

# 
# A supplemental, backward-compatible error-handling system for
# resolving errors before the stack unwinds.
# 
module Cond
  module CondPrivate
    class MessageProc < Proc  #:nodoc:
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
  class Restart < CondPrivate::MessageProc
  end

  #
  # A handler.  Use of this class is optional: you could pass lambdas
  # to Cond.with_handlers, but you'll miss the description string
  # shown by whichever tools might use it (currently none).
  #
  class Handler < CondPrivate::MessageProc
  end

  ######################################################################
  # errors
  
  #
  # Cond.invoke_restart was called with an unknown restart.
  #
  class NoRestartError < StandardError
  end

  #
  # `handle', `restart', `leave', or `again' called out of context.
  #
  class ContextError < StandardError
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
    def with_handlers(handlers)
      # note: leave unfactored due to notable yield vs &block performance
      handlers_stack.push(handlers_stack.last.merge(handlers))
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
      restarts_stack.push(restarts_stack.last.merge(restarts))
      begin
        yield
      ensure
        restarts_stack.pop
      end
    end
      
    #
    # A default handler is provided which runs a simple
    # choose-a-restart input loop when +raise+ is called.
    #
    def with_default_handlers
      # note: leave unfactored due to notable yield vs &block performance
      with_handlers(defaults.handlers) {
        yield
      }
    end
  
    #
    # The current set of restarts which have been registered.
    #
    def available_restarts
      restarts_stack.last
    end
      
    #
    # Find the closest-matching handler for the given Exception.
    #
    def find_handler(target)  #:nodoc:
      find_handler_from(handlers_stack.last, target)
    end

    def find_handler_from(handlers, target)  #:nodoc:
      handlers.fetch(target) {
        found = handlers.inject(Array.new) { |acc, (klass, func)|
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

    def check_context(keyword)  #:nodoc:
      section = Cond.code_section_stack.last
      case keyword
      when :restart
        unless section.is_a? CondPrivate::RestartableSection
          cond_original_raise(
            ContextError,
            "`#{keyword}' called outside of `restartable' block"
          )
        end
      when :handle
        unless section.is_a? CondPrivate::HandlingSection
          cond_original_raise(
            ContextError,
            "`#{keyword}' called outside of `handling' block"
          )
        end
      when :leave, :again
        unless section
          cond_original_raise(
            ContextError,
            "`#{keyword}' called outside of `handling' or `restartable' block"
          )
        end
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
      # TODO: fix rcov bug -- does not see %{}
      mod.module_eval <<-eval_end
        alias_method :'#{original}', :'#{method}'
        def #{method}(*args, &block)
          begin
            send(:'#{original}', *args, &block)
          rescue Exception => e
            raise e
          end
        end
      eval_end
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
    #
    # Cond.defaults contains the default handlers and restarts.  To
    # replace it, call
    #
    #   Cond.defaults.clear(&block)
    #
    # where &block creates a new instance of your class which
    # implements the method 'handlers'.
    #
    # Note that &block should return a brand new instance.  Otherwise
    # the returned object will be shared across threads.
    #

    stack_0  = lambda { Array.new }
    stack_1  = lambda { Array.new.push(Hash.new) }
    defaults = lambda { CondPrivate::Defaults.new }
    {
      :code_section_stack => stack_0,
      :exception_stack    => stack_0,
      :handlers_stack     => stack_1,
      :restarts_stack     => stack_1,
      :defaults           => defaults,
    }.each_pair { |name, create|
      include CondPrivate::ThreadLocal.reader_module(name) {
        create.call
      }
    }

    include CondPrivate::ThreadLocal.accessor_module(:reraise_count) { 0 }
  end

  ######################################################################
  
  module CondPrivate
    class CodeSection  #:nodoc:
      include SymbolGenerator
      
      def initialize(with, &block)
        @with = with
        @block = block
        @leave, @again = gensym, gensym
        @again_args = []
        SymbolGenerator.track(self, [@leave, @again])
      end

      def again(*args)
        @again_args = (
          case args.size
          when 0
            []
          when 1
            args.first
          else
            args
          end
        )
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
        catch(@leave) {
          while true
            catch(@again) {
              Cond.send(@with, Hash.new) {
                throw @leave, @block.call(*@again_args)
              }
            }
          end
        }
      end
    end

    class RestartableSection < CodeSection  #:nodoc:
      def initialize(&block)
        super(:with_restarts, &block)
      end
      
      def restart(sym, message, &block)
        Cond.restarts_stack.last[sym] = Restart.new(message, &block)
      end
    end

    class HandlingSection < CodeSection  #:nodoc:
      def initialize(&block)
        super(:with_handlers, &block)
      end
      
      def handle(sym, message, &block)
        Cond.handlers_stack.last[sym] = Handler.new(message, &block)
      end
    end
  end

  ######################################################################
  # shiny exterior

  module_function

  #
  # Begin a handling block.  Inside this block, a matching handler
  # gets called when +raise+ gets called.
  #
  def handling(&block)
    Cond.run_code_section(CondPrivate::HandlingSection, &block)
  end

  #
  # Begin a restartable block.  A handler may transfer control to one
  # of the restarts in this block.
  #
  def restartable(&block)
    Cond.run_code_section(CondPrivate::RestartableSection, &block)
  end
  
  #
  # Define a handler.
  #
  # The exception instance is passed to the block.
  #
  def handle(arg, message = "", &block)
    Cond.check_context(:handle)
    Cond.code_section_stack.last.handle(arg, message, &block)
  end

  #
  # Define a restart.
  #
  # When a handler calls invoke_restart, it may pass additional
  # arguments which are in turn passed to &block.
  #
  def restart(arg, message = "", &block)
    Cond.check_context(:restart)
    Cond.code_section_stack.last.restart(arg, message, &block)
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
    Cond.check_context(:leave)
    Cond.code_section_stack.last.leave(*args)
  end

  #
  # Run the handling or restartable block again.
  #
  # Optionally pass arguments which are given to the block.
  #
  def again(*args)
    Cond.check_context(:again)
    Cond.code_section_stack.last.again(*args)
  end

  #
  # Call a restart from a handler; optionally pass it some arguments.
  #
  def invoke_restart(name, *args, &block)
    Cond.available_restarts.fetch(name) {
      raise NoRestartError,
        "Did not find `#{name.inspect}' in available restarts"
    }.call(*args, &block)
  end
end

module Kernel
  alias_method :cond_original_raise, :raise
  remove_method :raise
  def raise(*args)
    if Cond.handlers_stack.last.empty?
      # not using Cond
      cond_original_raise(*args)
    else
      last_exception = Cond.exception_stack.last
      exception = (
        if last_exception and args.empty?
          last_exception
        else
          begin
            cond_original_raise(*args)
          rescue Exception => e
            e
          end
        end
      )
      if last_exception
        # inside a handler
        handler = loop {
          Cond.reraise_count += 1
          handlers = Cond.handlers_stack[-1 - Cond.reraise_count]
          if handlers.nil?
            break nil
          end
          found = Cond.find_handler_from(handlers, exception.class)
          if found
            break found
          end
        }
        if handler
          handler.call(exception)
        else
          Cond.reraise_count = 0
          cond_original_raise(exception)
        end
      else
        # not inside a handler
        Cond.reraise_count = 0
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
  end
  alias_method :cond_original_fail, :fail
  remove_method :fail
  alias_method :fail, :raise
end
