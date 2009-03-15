
module Cond
  module LoopWith
    module_function
    
    def loop_with(done = nil, again = nil)
      if done
        if again
          catch(done) {
            while true
              catch(again) {
                yield
              }
            end
          }
        else
          catch(done) {
            while true
              yield
            end
          }
        end
      elsif again
        while true
          catch(again) {
            yield
          }
        end
      else
        while true
          yield
        end
      end
    end
  end
end
