
class Array
  unless [].respond_to? :tail
    def tail
      self[1..-1]
    end
  end
end
