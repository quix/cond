
require 'thread'

module Cond
  module SymbolGenerator
    @object_id_to_sym_list = Hash.new
    @mutex = Mutex.new
    @count = 0
    @recycled = []
    @finalizer = lambda { |id|
      recycle(@object_id_to_sym_list[id])
      @object_id_to_sym_list.delete id
    }

    class << self
      def gensym(prefix = nil)
        @mutex.synchronize {
          if @recycled.empty?
            @count += 1
            if prefix
              :"|#{prefix}#{@count}|"
            else
              :"|#{@count}"
            end
          else
            @recycled.shift
          end
        }
      end

      def recycle(syms)
        @mutex.synchronize {
          @recycled.concat(syms)
        }
      end
      
      def track(object, syms)
        @object_id_to_sym_list[object.object_id] = syms.dup
        ObjectSpace.define_finalizer(object, @finalizer)
      end
    end
    
    define_method :gensym, &method(:gensym)
    private :gensym
  end
end
