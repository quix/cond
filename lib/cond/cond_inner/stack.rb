
module Cond
  module CondInner
    class Stack
      def initialize
        @array = Array.new
      end

      def top
        @array.last
      end
      
      def push(obj)
        @array.push(obj)
        self
      end

      def at(index)
        @array.at(index)
      end

      [:pop, :empty?, :size].each { |name|
        define_method(name) {
          @array.send(name)
        }
      }
    end
  end
end
