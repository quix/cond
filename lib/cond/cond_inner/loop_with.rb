
module Cond
  module CondInner
    module LoopWith
      module_function
      
      def loop_with(leave = nil, again = nil)
        if leave
          if again
            catch(leave) {
              while true
                catch(again) {
                  yield
                }
              end
            }
          else
            catch(leave) {
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
end
