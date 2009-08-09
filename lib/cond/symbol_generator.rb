
module Cond
  module SymbolGenerator
    @count = 'a'
    @mutex = Mutex.new
    @recycled = []
    @object_id_to_sym_list = Hash.new
    @finalizer = lambda { |id|
      recycle(@object_id_to_sym_list.delete(id))
    }

    class << self
      def gensym
        @mutex.synchronize {
          if @recycled.empty?
            @count.succ!
            :"|#{@count}"
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
      
      def track(object, *syms)
        @mutex.synchronize {
          @object_id_to_sym_list[object.object_id] = syms.flatten
          ObjectSpace.define_finalizer(object, @finalizer)
        }
      end
    end
    
    define_method :gensym, &method(:gensym)
    private :gensym
  end
end
