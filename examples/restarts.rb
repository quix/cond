$LOAD_PATH.unshift "#{File.dirname(__FILE__)}/../lib"
require 'cond'
require 'pp'

include Cond

#
# http://c2.com/cgi/wiki?LispRestartExample
#

class RestartableFetchError < RuntimeError
  def initialize(key, hash)
    super()
    @key, @hash = key, hash
  end
  def message
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

def restartable_fetch(hash, key, default = nil)
  restartable do
    on :continue, "Return not having found the value." do
      return
    end
    on :try_again, "Try getting the key from the hash again." do
      again
    end
    on :use_new_key, "Use a new key." do
      key = read_new_value("key")
      again
    end
    on :use_new_hash, "Use a new hash." do
      hash = read_new_value("hash")
      again
    end
    hash.fetch(key) {
      raise RestartableFetchError.new(key, hash)
    }
  end
end

fruits_and_vegetables = Hash[*%w[
   apple fruit
   orange fruit
   lettuce vegetable
   tomato depends_on_who_you_ask
]]

Cond.with_default_handlers {
  puts("value: " + restartable_fetch(fruits_and_vegetables, "mango").inspect)
}

#  
#  % ruby restart.rb
#  #<RestartableFetchError: RestartableFetchError>
#  restart.rb:58
#  RestartableFetchError error getting "mango" from:
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
#  #<RestartableFetchError: RestartableFetchError>
#  restart.rb:58
#  RestartableFetchError error getting "mango" from:
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
#  #<RestartableFetchError: RestartableFetchError>
#  restart.rb:58
#  RestartableFetchError error getting "mango" from:
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
