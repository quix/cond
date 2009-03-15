
class Module
  instance_method_defined = lambda { |name|
    (
      public_instance_methods +
      protected_instance_methods +
      private_instance_methods
    ).map { |t| t.to_sym }.include? name.to_sym
  }
  unless instance_method_defined.call(:instance_method_defined?)
    define_method(:instance_method_defined?, &instance_method_defined)
  end
end
