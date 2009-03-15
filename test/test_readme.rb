require File.dirname(__FILE__) + "/common"

require 'quix/ruby'

here = Pathname(__FILE__).dirname
file = here + ".." + "README"
lib = (here + ".." + "lib").expand_path

describe file do
  it "should run as claimed" do
    contents = file.read
    expected = contents.scan(%r!\# => (.*?)\n!).flatten.join("\n")
    code = (
      "$LOAD_PATH.unshift '#{lib}'\n" +
      contents.match(%r!^== Synopsis.*?\n(.*?)^==!m)[1]
    )
    pipe_to_ruby(code).chomp.should == expected
  end
end
