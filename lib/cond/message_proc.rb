
module Cond
  #
  # Common base for Handler and Restart.  A Proc with a message.
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
