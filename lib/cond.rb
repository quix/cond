
require 'quix'

module Cond
  class << self
    ###################################################################
    #
    # Cond metaclass
    #
    ###################################################################

    def with_handlers(handlers, &block)
      #
      # We are redefining and re-redefining raise--modifying the
      # Object singleton--so we must hold the global lock.
      #
      Thread.exclusive {
        if @first_call
          if $DEBUG
            exception_wrap_builtins
          end
          @first_call = false
        end
        (stack = @handler_stack.value).push(stack.last.merge(handlers))
        define_raise
        begin
          block.call
        ensure
          stack.pop
          if stack.size == 1
            remove_raise
          end
        end
      }
    end

    def with_restarts(restarts, &block)
      (stack = @restarts_stack.value).push(stack.last.merge(restarts))
      begin
        block.call
      ensure
        stack.pop
      end
    end
    
    def with_default_handler(&block)
      with_handlers(Exception => default_handler) {
        block.call
      }
    end

    def with_default_restarts(&block)
      with_restarts(default_restarts) {
        block.call
      }
    end

    def available_restarts
      @restarts_stack.value.last
    end
    
    def find_restart(name)
      compute_restarts[name]
    end

    def invoke_restart(name, *args)
      find_restart(name).call(*args)
    end

    class Restart < Proc
      attr_accessor :report
    end

    def restart(report, &block)
      Restart.new(&block).tap { |it| it.report = report }
    end

    attr_accessor :default_handler, :default_restarts

    def stream
      STDERR
    end

    private

    def remove_raise
      Object.instance_eval {
        remove_method(:raise)
      }
    end
    
    def find_handler(exception)
      handlers = @handler_stack.value.last
      if handler = handlers[exception]
        handler
      else
        # find a superclass handler
        catch(done = gensym) {
          ancestors =
            if exception.is_a? String
              RuntimeError
            elsif exception.is_a? Exception
              exception.class
            else
              exception
            end.ancestors
          handlers.each { |klass, handler|
            if ancestors.include?(klass)
              throw done, handler
            end
          }
          nil # not found
        }
      end
    end

    def create_backtrace(exception)
      begin
        raise exception
      rescue => excpetion
      end
    end
    
    def define_raise
      Object.instance_eval {
        define_method(:raise) { |exception, *args|
          Cond.instance_eval {
            if handler = find_handler(exception)
              begin
                remove_raise
                create_backtrace(exception)
                handler.call(exception, *args)
              ensure
                define_raise
              end
            else
              remove_raise
              raise exception, *args
            end
          }
        }
      }
    end

    ###################################################################
    #
    # Wrappers for methods of built-in classes.
    #
    # Since these methods are written in C, our trick of redefining
    # raise does not work, as the call to the built-in raise method is
    # hard-codedly bound.
    #
    # As a workaround, wrap every method with a rescue-all/re-raise
    # block.
    #
    # Due to performance worries, these wrappers are only installed
    # when $DEBUG is true.
    #
    ###################################################################

    def exception_wrapper
      begin
        yield
      rescue => exception
        raise exception
      end
    end
    
    WRAPPER_FLAG = :has_exception_wrapper?
    
    def exception_wrap_method(klass, method)
      unless klass.singleton_class.respond_to?(WRAPPER_FLAG)
        klass.instance_eval {
          old_method = instance_method(method)
          remove_method(method)
          define_method(method) { |*args, &block|
            Cond.call_private(:exception_wrapper) {
              old_method.bind(self).call(*args, &block)
            }
          }
          singleton_class.instance_eval {
            define_method(WRAPPER_FLAG) {
              true
            }
          }
        }
      end
    end
    
    def exception_wrap_classes(*klasses)
      klasses.each { |klass|
        klass.public_instance_methods(false).each { |method|
          if method != "raise"
            exception_wrap_method(klass, :"#{method}")
          end
        }
      }
    end
    
    SELECTED_BUILTINS = [
      Array,
      Binding,
      Dir,
      File::Stat,
      File,
      Hash,
      IO,
      MatchData,
      Range,
      Regexp,
      String,
      Struct,
      Struct::Tms,
      Time,
    ]

    def exception_wrap_builtins
      exception_wrap_classes(*SELECTED_BUILTINS)
    end
  end
  
  ###################################################################
  #
  # module Cond
  #
  ###################################################################

  @handler_stack, @restarts_stack = (1..2).map {
    ThreadLocal.new { [Hash.new] }
  }

  @first_call = true

  ###################################################################
  # Default handler
  ###################################################################
  
  @default_handler = lambda { |exception, *args|
    puts exception.backtrace.last
    if exception.respond_to? :report
      stream.puts(exception.report + "\n")
    end
    
    restarts = available_restarts.keys.map { |name|
      name.to_s
    }.sort.map { |name|
      { :name => name, :func => available_restarts[name.to_sym] }
    }
    
    catch(:default_handler_loop) {
      index = catch(done = gensym) {
        loop {
          restarts.each_with_index { |restart, index|
            report =
            if (f = restart[:func]).respond_to?(:report) and f.report != ""
              f.report
            else
              ""
            end + " "
            stream.printf(
              "%3d: %s(:%s)\n",
              index, report, restart[:name])
          }
          stream.print "> "
          input = STDIN.readline.trim
          if input =~ %r!\A\d+\Z! and
              (0...restarts.size).include?(input.to_i)
            throw done, input.to_i
          end
        }
      }
      restarts[index][:func].call(exception)
    }
  }

  ###################################################################
  # Default restarts
  ###################################################################
  
  @default_restarts = {
    :raise => restart("Raise this exception.") { |exception|
      raise exception
    },
    :eval => restart("Run some code.") {
      print("Enter code: ")
      eval(STDIN.readline.trim)
    },
    :exit => restart("Exit.") {
      exit
    },
    :backtrace => restart("Show backtrace.") { |exception|
      puts exception.backtrace
      throw :default_handler_loop
    },
  }
end
