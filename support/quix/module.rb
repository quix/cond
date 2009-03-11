
class Module
  lambda {
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
  }.call

  unless instance_method_defined? :polite
    def polite(&block)
      added =       Hash.new { |hash, key| hash[key] = Array.new }
      scope_cache = Hash.new { |hash, key| hash[key] = Array.new }
      current_scope = :public

      mod = Module.new {
        (class << self ; self ; end).module_eval {
          [:public, :protected, :private, :module_function].each { |scope|
            define_method(scope) { |*args|
              if args.empty?
                current_scope = scope
              else
                scope_cache[scope] += args
              end
            }
          }
          define_method(:method_added) { |name|
            added[current_scope] << name
          }
        }
        module_eval(&block)
      }

      added_dup = added.inject(Hash.new) { |acc, (scope, names)|
        acc.merge!(scope => names.dup)
      }

      added_dup.each_pair { |scope, names|
        names.each { |name|
          if instance_method_defined? name
            mod.module_eval {
              remove_method(name)
            }
            added[scope].delete(name)
            scope_cache[scope].delete(name)
          end
        }
      }

      include mod

      [added, scope_cache].each { |hash|
        hash.each_pair { |scope, names|
          send(scope, *names)
        }
      }
    end
  end
end
