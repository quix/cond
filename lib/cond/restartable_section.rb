
module Cond
  class RestartableSection < CodeSection  #:nodoc:
    def initialize(&block)
      super(:with_restarts, &block)
    end
    
    def restart(sym, message, &block)
      Cond.restarts_stack.last[sym] = Restart.new(message, &block)
    end
  end
end
