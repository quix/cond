
module Cond
  class Error < RuntimeError
  end

  #
  # Cond.invoke_restart was called with an unknown restart.
  #
  class NoRestartError < Error
  end

  #
  # `handle', `restart', `leave', or `again' called out of context.
  #
  class ContextError < Error
  end
end
