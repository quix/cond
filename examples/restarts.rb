#
# http://c2.com/cgi/wiki?LispRestartExample
#

$LOAD_PATH.unshift "#{File.dirname(__FILE__)}/../lib"
require 'cond'
require 'pp'

class RestartableGethashError < RuntimeError
  def initialize(info)
    super()
    @key, @hash = info
  end

  def report
    sprintf(
      "%s error getting %s from:\n%s",
      self, @key.inspect, @hash.pretty_inspect
    )
  end
end

def read_new_value(what)
  print("Enter a new #{what}: ")
  eval(STDIN.readline.chomp)
end

def restartable_gethash(hash, key, default = nil)
  restarts = {
    :continue => Cond.restart("Return not having found the value.") {
      throw :break
    },
    :try_again => Cond.restart("Try getting the key from the hash again.") {
      throw :next
    },
    :use_new_key => Cond.restart("Use a new key.") { |exception|
      key.replace read_new_value("key")
    },
    :use_new_hash => Cond.restart("Use a new hash.") { |exception|
      hash.replace read_new_value("hash")
    },
  }

  Cond.with_restarts(restarts) {
    # 'throw :break' is like 'break', 'throw :next' is like 'next'
    loop_with(:break, :next) {
      value = hash[key]
      if value
        return value
      else
        raise RestartableGethashError, [key, hash]
      end
    }
  }
end

fruits_and_vegetables = Hash[*%w[
   apple fruit
   orange fruit
   lettuce vegetable
   tomato depends_on_who_you_ask
]]

Cond.with_default_handlers {
  puts("value: " + restartable_gethash(fruits_and_vegetables, "mango").inspect)
}

#  
#  % ruby restart.rb
#  #<RestartableGethashError: RestartableGethashError>
#  restart.rb:64
#  RestartableGethashError error getting "mango" from:
#  {"orange"=>"fruit",
#   "apple"=>"fruit",
#   "tomato"=>"depends_on_who_you_ask",
#   "lettuce"=>"vegetable"}
#  
#    0: Return not having found the value. (:continue)
#    1: Try getting the key from the hash again. (:try_again)
#    2: Use a new hash. (:use_new_hash)
#    3: Use a new key. (:use_new_key)
#  > 0
#  value: nil
#
#
#  % ruby restart.rb
#  #<RestartableGethashError: RestartableGethashError>
#  restart.rb:64
#  RestartableGethashError error getting "mango" from:
#  {"orange"=>"fruit",
#   "apple"=>"fruit",
#   "tomato"=>"depends_on_who_you_ask",
#   "lettuce"=>"vegetable"}
#  
#    0: Return not having found the value. (:continue)
#    1: Try getting the key from the hash again. (:try_again)
#    2: Use a new hash. (:use_new_hash)
#    3: Use a new key. (:use_new_key)
#  > 2
#  Enter a new hash: { "mango" => "mangoish fruit" }
#  value: "mangoish fruit"
#
#
#  % ruby restart.rb
#  #<RestartableGethashError: RestartableGethashError>
#  restart.rb:64
#  RestartableGethashError error getting "mango" from:
#  {"orange"=>"fruit",
#   "apple"=>"fruit",
#   "tomato"=>"depends_on_who_you_ask",
#   "lettuce"=>"vegetable"}
#  
#    0: Return not having found the value. (:continue)
#    1: Try getting the key from the hash again. (:try_again)
#    2: Use a new hash. (:use_new_hash)
#    3: Use a new key. (:use_new_key)
#  > 3
#  Enter a new key: "apple"
#  value: "fruit"
#  
