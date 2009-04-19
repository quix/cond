
class Jumpstart
  #
  # Mixin for lazily-evaluated attributes.
  #
  module LazyAttribute
    #
    # &block is evaluated when this attribute is requested.  The same
    # result is returned for subsequent calls until the attribute is
    # assigned a different value.
    #
    def attribute(reader, &block)
      writer = "#{reader}="

      singleton = (class << self ; self ; end)

      define_evaluated_reader = lambda { |value|
        singleton.class_eval {
          remove_method(reader)
          define_method(reader) { value }
        }
      }

      singleton.class_eval {
        define_method(reader) {
          value = block.call
          define_evaluated_reader.call(value)
          value
        }
          
        define_method(writer) { |value|
          define_evaluated_reader.call(value)
          value
        }
      }
    end
  end
end
