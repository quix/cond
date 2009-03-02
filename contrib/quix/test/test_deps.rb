$LOAD_PATH.unshift "#{File.dirname(__FILE__)}/../lib"

require 'test/unit'
require 'quix/ruby'

class TestDeps < Test::Unit::TestCase
  def test_deps
    root = File.expand_path("#{File.dirname(__FILE__)}/../lib")
    Dir["#{root}/**/*.rb"].map { |file|
      file.
      sub(%r!\A#{root}/!, "").
      sub(%r!\.rb\Z!, "")
    }.each { |file|
      unless file =~ %r!cygwin! and RUBY_PLATFORM !~ %r!cygwin!
        Dir.chdir(root) {
          assert(
            Quix::Ruby.run("-r", file, "-e", ""),
            "error requiring: '#{file}'")
        }
      end
    }
  end
end
