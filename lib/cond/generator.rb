
require 'thread'

module Cond
  module Generator
    @mutex = Mutex.new
    @count = 0

    class << self
      def gensym(*args)
        genstr(*args).to_sym
      end

      #
      # define_method avoids module_function + instance variable problems
      #
      def genstr(prefix = nil)
        @mutex.synchronize {
          @count += 1
        }
        # TODO: jettison 1.8, use |prefix = nil|
        if prefix
          "|#{prefix}#{@count}|"
        else
          "G#{@count}"
        end
      end
    end
    
    [:genstr, :gensym].each { |name|
      define_method name, &method(name)
      private name
    }
  end
end
