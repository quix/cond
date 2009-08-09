
module Cond
  class HandlingSection < CodeSection  #:nodoc:
    def initialize(&block)
      super(:with_handlers, &block)
    end
    
    def handle(sym, message, &block)
      Cond.handlers_stack.last[sym] = Handler.new(message, &block)
    end
  end
end
