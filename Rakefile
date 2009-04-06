
README = "README"

task :readme do
  readme = File.read(README)
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
  File.open(README, "w") { |f| f.print update }
end

task :prerelease => :readme
