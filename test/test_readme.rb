require File.dirname(__FILE__) + "/common"

file = Pathname(__FILE__).dirname + ".." + "README"

describe file do
  it "should run as claimed" do
    contents = file.read
    expected = contents.scan(%r!\# => (.*?)\n!).flatten.join("\n")
    code = contents.match(%r!^== Synopsis.*?\n(.*?)^==!m)[1]
    stdout, stderr = capture_io {
      eval(code)
    }
    [stdout.chomp, stderr].should == [expected, ""]
  end
end
