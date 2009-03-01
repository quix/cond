
class Array
  def rest
    self[1..-1]
  end

  def inject1(&block)
    tail.inject(head, &block)
  end

  alias_method :head, :first
  alias_method :tail, :rest
end
