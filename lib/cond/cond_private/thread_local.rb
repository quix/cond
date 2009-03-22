
require 'thread'
require 'cond/cond_private/symbol_generator'

module Cond
  module CondPrivate
    #
    # Thread-local variable.
    #
    class ThreadLocal
      include SymbolGenerator

      #
      # If +value+ is called before +value=+ then the result of
      # &default is used.
      #
      # &default normally creates a new object, otherwise the returned
      # object will be shared across threads.
      #
      def initialize(&default)
        @name = gensym
        @accessed = gensym
        @default = default
        SymbolGenerator.track(self, [@name, @accessed])
      end

      #
      # Reset to just-initialized state for all threads.
      #
      def clear(&default)
        @default = default
        Thread.exclusive {
          Thread.list.each { |thread|
            thread[@accessed] = nil
            thread[@name] = nil
          }
        }
      end
      
      def value
        unless Thread.current[@accessed]
          if @default
            Thread.current[@name] = @default.call
          end
          Thread.current[@accessed] = true
        end
        Thread.current[@name]
      end
      
      def value=(value)
        Thread.current[@accessed] = true
        Thread.current[@name] = value
      end

      class << self
        def accessor_module(name, subclass = self, &block)
          var = subclass.new(&block)
          Module.new {
            define_method(name) {
              var.value
            }
            define_method("#{name}=") { |value|
              var.value = value
            }
          }
        end
        
        def reader_module(name, subclass = self, &block)
          accessor_module(name, subclass, &block).instance_eval {
            remove_method "#{name}="
            self
          }
        end
      end
    end
  end
end
