require File.dirname(__FILE__) + "/../spec/common"

require 'quix/ruby'

file = Pathname(__FILE__).dirname + ".." + "readmes" + "handlers.rb"

describe file do
  it "should run as claimed" do
    expected = file.read.scan(%r!\# => (.*?)\n!).flatten.join("\n")
    `"#{Quix::Ruby::EXECUTABLE}" "#{file}"`.chomp.should == expected
  end
end
