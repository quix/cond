$LOAD_PATH.unshift "devel"

require 'jumpstart'

readme_file = nil
 
Jumpstart.new('cond') do |s|
  s.developers << ['James M. Lawrence', 'quixoticsycophant@gmail.com']
  s.github_user = "quix"
  s.description_sentences = 2
  s.rdoc_files = %w[
    lib/cond/cond.rb
    lib/cond/dsl_definition.rb
    lib/cond/error.rb
    lib/cond/handler.rb
    lib/cond/message_proc.rb
    lib/cond/restart.rb
    lib/cond/wrapping.rb
  ]
  readme_file = s.readme_file
end

task :readme do
  readme = File.read(readme_file)
  restarts = File.read("readmes/restarts.rb")
  run_re = %r!\A\#  !
  update = readme.sub(%r!(= Restart Example\n)(.*?)(?=^Run)!m) {
    $1 + "\n" +
    restarts[%r!^(require.*?)(?=^\#)!m].
    gsub(%r!^!m, "  ")
  }.sub(%r!^(Run:\n)(.*?)(?=^\S)!m) {
    $1 + "\n" +
    restarts.lines.grep(run_re).map { |t| t.sub(run_re, "  ") }.join + "\n"
  }
  File.open(readme_file, "w") { |f| f.print update }
end

task :prerelease => :readme
