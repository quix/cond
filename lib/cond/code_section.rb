
module Cond
  class CodeSection  #:nodoc:
    include SymbolGenerator
    
    def initialize(with, &block)
      @with = with
      @block = block
      @again_args = []
      @leave, @again = gensym, gensym
      SymbolGenerator.track(self, @leave, @again)
    end

    def again(*args)
      @again_args = (
        case args.size
        when 0
          []
        when 1
          args.first
        else
          args
        end
      )
      throw @again
    end

    def leave(*args)
      case args.size
      when 0
        throw @leave
      when 1
        throw @leave, args.first
      else
        throw @leave, args
      end
    end

    def run
      catch(@leave) {
        while true
          catch(@again) {
            Cond.send(@with, Hash.new) {
              throw @leave, @block.call(*@again_args)
            }
          }
        end
      }
    end
  end
end
