
require 'cond/module'

class Array
  polite do
    def tail
      self[1..-1]
    end
  end
end
