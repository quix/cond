here = File.dirname(__FILE__)
require here + "/common"

require 'quix/ruby'

(Dir["#{here}/*_spec.rb"] + Dir["#{here}/../examples/*_example.rb"]).each {
   |spec|
  unless Quix::Ruby.run(spec)
    raise "spec failed: #{spec}"
  end
}
