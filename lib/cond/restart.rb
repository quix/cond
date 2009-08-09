
module Cond
  #
  # A restart.  Use of this class is optional: you could pass lambdas
  # to Cond.with_restarts, but you'll miss the description string
  # shown inside Cond.default_handler.
  #
  class Restart < MessageProc
  end
end
