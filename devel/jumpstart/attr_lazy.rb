
class Jumpstart
  #
  # Lazily-evaluated attributes.
  #
  # An attr_lazy block is evaluated in the context of the instance
  # when the attribute is requested.  The same result is then returned
  # for subsequent calls until the attribute is redefined with another
  # attr_lazy block.
  #
  module AttrLazy
    def attr_lazy(name, &block)
      AttrLazy.define_attribute(class << self ; self ; end, name, false, &block)
    end

    def attr_lazy_accessor(name, &block)
      AttrLazy.define_attribute(class << self ; self ; end, name, true, &block)
    end

    class << self
      def included(mod)
        (class << mod ; self ; end).class_eval do
          def attr_lazy(name, &block)
            AttrLazy.define_attribute(self, name, false, &block)
          end

          def attr_lazy_accessor(name, &block)
            AttrLazy.define_attribute(self, name, true, &block)
          end
        end
      end

      def define_attribute(klass, name, define_writer, &block)
        klass.class_eval do
          # Factoring this code is possible but convoluted, requiring
          # the definition of a temporary method.

          remove_method name rescue nil
          define_method name do
            value = instance_eval(&block)
            (class << self ; self ; end).class_eval do
              remove_method name rescue nil
              define_method name do
                value
              end
            end
            value
          end

          if define_writer
            writer = "#{name}="
            remove_method writer rescue nil
            define_method writer do |value|
              (class << self ; self ; end).class_eval do
                remove_method name rescue nil
                define_method name do
                  value
                end
              end
              value
            end
          end
        end
      end
    end
  end
end
