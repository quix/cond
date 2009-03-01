
class Thread
  class << self
    def with_abort_on_exception(value = true)
      previous = self.abort_on_exception
      self.abort_on_exception = value
      begin
        yield
      ensure
        self.abort_on_exception = previous
      end
    end
  end
end
