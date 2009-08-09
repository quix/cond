
module Cond
  #
  # A handler.  Use of this class is optional: you could pass lambdas
  # to Cond.with_handlers, but you'll miss the description string
  # shown by whichever tools might use it (currently none).
  #
  class Handler < MessageProc
  end
end
