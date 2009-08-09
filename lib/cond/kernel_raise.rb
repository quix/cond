
module Kernel
  remove_method :raise
  def raise(*args)
    if Cond.handlers_stack.last.empty?
      # not using Cond
      Cond.original_raise(*args)
    else
      last_exception, current_handler = Cond.exception_stack.last
      exception = (
        if last_exception and args.empty?
          last_exception
        else
          begin
            Cond.original_raise(*args)
          rescue Exception => e
            e
          end
        end
      )
      if current_handler
        # inside a handler
        handler = loop {
          Cond.reraise_count += 1
          handlers = Cond.handlers_stack[-1 - Cond.reraise_count]
          if handlers.nil?
            break nil
          end
          found = Cond.find_handler_from(handlers, exception.class)
          if found and found != current_handler
            break found
          end
        }
        if handler
          handler.call(exception)
        else
          Cond.reraise_count = 0
          Cond.original_raise(exception)
        end
      else
        # not inside a handler
        Cond.reraise_count = 0
        handler = Cond.find_handler(exception.class)
        if handler
          Cond.exception_stack.push([exception, handler])
          begin
            handler.call(exception)
          ensure
            Cond.exception_stack.pop
          end
        else
          Cond.original_raise(exception)
        end
      end
    end
  end
  remove_method :fail
  alias_method :fail, :raise
end
