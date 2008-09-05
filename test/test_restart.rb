$LOAD_PATH.unshift "#{File.dirname(__FILE__)}/../lib"

require 'cond'

class Restartable_Gethash_Error < RuntimeError
  attr_accessor :data
  def report
    sprintf("%s error getting %s from %s.\n",
      self, @data[:key].inspect, @data[:hash].inspect)
  end
end

def read_new_value(what)
  print("Enter a new #{what}: ")
  eval(STDIN.readline.chomp)
end

def restartable_gethash(hash, key, default = nil)
  continue, try_again = gensym, gensym
  restarts = {
    :continue => Cond.restart("Return not having found the value.") {
      throw continue
    },
    :try_again => Cond.restart("Try getting the key from the hash again.") {
      throw try_again
    },
    :use_new_key => Cond.restart("Use a new key.") { |exception|
      exception.data[:key] = read_new_value("key")
    },
    :use_new_hash => Cond.restart("Use a new hash.") { |exception|
      exception.data[:hash] = read_new_value("hash")
    },
  }
  Cond.with_restarts(restarts) {
    data = { :hash => hash, :key => key }
    catch(continue) {
      loop {
        catch(try_again) {
          if value = data[:hash].fetch(data[:key], default)
            return value
          else
            raise Restartable_Gethash_Error.new.tap { |t| t.data = data }
          end
        }
      }
    }
  }
end

fruits_and_vegetables = Hash[*%w[
   apple fruit
   orange fruit
   lettuce vegetable
   tomato depends_on_who_you_ask
]]

Cond.with_default_handler {
  puts("value: " + restartable_gethash(fruits_and_vegetables, "mango").inspect)
}
