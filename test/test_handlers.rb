require "#{File.dirname(__FILE__)}/common"

file = Pathname(__FILE__).dirname + ".." + "examples" + "handlers.rb"

describe file do
  it "should run as claimed" do
    expected = file.read.scan(%r!\# => (.*?)\n!).flatten.join("\n")
    `"#{Cond::Test::Ruby::EXECUTABLE}" "#{file}"`.chomp.should == expected
  end
end
