
require 'pathname'

class Pathname
  def ext(new_ext)
    sub(%r!#{extname}\Z!, ".#{new_ext}")
  end
  
  def stem
    sub(%r!#{extname}\Z!, "")
  end

  def explode
    to_s.split(SEPARATOR_PAT).map { |path|
      Pathname.new path
    }
  end

  def =~(regexp)
    to_s =~ regexp
  end

  def restring
    Pathname.new(yield(to_s))
  end

  def to_dos
    restring { |t| t.gsub("/", "\\") }
  end

  class << self
    def join(*paths)
      Pathname.new File.join(*paths)
    end
  end
end

