
# sorry -- it's too awkward without these

module Kernel
  unless respond_to? :singleton_class
    def singleton_class
      class << self
        self
      end
    end
  end

  unless respond_to? :tap
    def tap
      yield self
      self
    end
  end
end

class Array
  unless [].respond_to? :tail
    def tail
      self[1..-1]
    end
  end
end
