
class Array
  alias_method :head, :first

  def tail
    self[1..-1]
  end

  def inject1(&block)
    tail.inject(head, &block)
  end
end
