
# 
# Resolve errors without unwinding the stack.
# 
module Cond
  VERSION = "0.3.0"

  class << self
    include DSL
    include Wrapping

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
        unless section.is_a? RestartableSection
          Cond.original_raise(
            ContextError,
            "`#{keyword}' called outside of `restartable' block"
          )
        end
      when :handle
        unless section.is_a? HandlingSection
          Cond.original_raise(
            ContextError,
            "`#{keyword}' called outside of `handling' block"
          )
        end
      when :leave, :again
        unless section
          Cond.original_raise(
            ContextError,
            "`#{keyword}' called outside of `handling' or `restartable' block"
          )
        end
      end
    end

    ###############################################
    # original raise
    
    define_method :original_raise, Kernel.instance_method(:raise)

    ######################################################################
    # data -- all data is per-thread and fetched from the singleton class
    #
    # Cond.defaults contains the default handlers.  To replace it,
    # call
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
    defaults = lambda { Defaults.new }
    {
      :code_section_stack => stack_0,
      :exception_stack    => stack_0,
      :handlers_stack     => stack_1,
      :restarts_stack     => stack_1,
      :defaults           => defaults,
    }.each_pair { |name, create|
      include ThreadLocal.reader_module(name, &create)
    }

    include ThreadLocal.accessor_module(:reraise_count) { 0 }
  end
end


