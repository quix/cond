
Gem::Specification.new { |t|
  t.author = "James M. Lawrence"
  t.email = "quixoticsycophant@gmail.com"
  t.summary = "Handle exceptions without unwinding the stack."
  t.name = "cond"
  t.rubyforge_project = t.name
  t.homepage = "#{t.name}.rubyforge.org"
  t.version = "0.1.0"
  t.description = (
    "Cond is an error handling system which allows exceptions to be " +
    "handled near the place where they occur, before the stack unwinds."
  )
  t.files = (
    %W[README #{t.name}.gemspec] +
    Dir["./**/*.rb"] +
    Dir["./**/Rakefile"]
  )
  rdoc_exclude = %w[
    test
    examples
    support
  ]
  t.has_rdoc = true
  t.extra_rdoc_files = %w[README]
  t.rdoc_options += [
    "--main",
    "README",
    "--title",
    "#{t.name}: #{t.summary}",
  ] + rdoc_exclude.inject(Array.new) { |acc, pattern|
    acc + ["--exclude", pattern]
  }
}
