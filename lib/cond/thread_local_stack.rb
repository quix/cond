
require 'cond/thread_local'

module Cond
  class ThreadLocalStack
    def initialize
      @stack = ThreadLocal.new { Array.new }
    end
    
    def empty?
      @stack.value.empty?
    end
    
    def top
      @stack.value.last
    end
    
    def push(obj)
      @stack.value.push(obj)
    end

    def pop
      @stack.value.pop
    end
  end
end
