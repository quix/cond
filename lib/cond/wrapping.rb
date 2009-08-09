
module Cond
  module Wrapping
    #
    # Allow handlers to be called from C code by wrapping a method with
    # begin/rescue.  Returns the aliased name of the original method.
    #
    # See the README.
    #
    # Example:
    #
    #   Cond.wrap_instance_method(Fixnum, :/)
    #
    def wrap_instance_method(mod, method)
      original = "cond_original_#{mod.inspect}_#{method.inspect}"
      # TODO: jettison 1.8.6, remove eval and use |&block|
      mod.module_eval <<-eval_end
        alias_method :'#{original}', :'#{method}'
        def #{method}(*args, &block)
          begin
            send(:'#{original}', *args, &block)
          rescue Exception => e
            raise e
          end
        end
      eval_end
      original
    end
  
    #
    # Allow handlers to be called from C code by wrapping a method with
    # begin/rescue.  Returns the aliased name of the original method.
    #
    # See the README.
    #
    # Example:
    #
    #   Cond.wrap_singleton_method(IO, :read)
    #
    def wrap_singleton_method(mod, method)
      singleton_class = class << mod ; self ; end
      wrap_instance_method(singleton_class, method)
    end
  end
end
