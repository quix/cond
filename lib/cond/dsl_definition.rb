
module Cond
  module DSL
    #
    # Begin a handling block.  Inside this block, a matching handler
    # gets called when +raise+ gets called.
    #
    def handling(&block)
      Cond.run_code_section(HandlingSection, &block)
    end

    #
    # Begin a restartable block.  A handler may transfer control to one
    # of the restarts in this block.
    #
    def restartable(&block)
      Cond.run_code_section(RestartableSection, &block)
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
end
