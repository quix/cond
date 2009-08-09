
class Jumpstart
  module Util
    module_function

    def run_ruby_on_each(*files)
      files.each { |file|
        Ruby.run("-w", file)
      }
    end

    def to_camel_case(str)
      str.split('_').map { |t| t.capitalize }.join
    end

    def write_file(file)
      contents = yield
      File.open(file, "wb") { |out|
        out.print(contents)
      }
      contents
    end

    def replace_file(file)
      old_contents = File.read(file)
      new_contents = yield(old_contents)
      if old_contents != new_contents
        File.open(file, "wb") { |output|
          output.print(new_contents)
        }
      end
      new_contents
    end
  end
end
