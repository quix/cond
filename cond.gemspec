
Gem::Specification.new { |t|
  t.author = "James M. Lawrence"
  t.email = "quixoticsycophant@gmail.com"
  t.summary =
    "Intercept exceptions; resolve errors without unwinding the stack."
  t.name = "cond"
  t.rubyforge_project = t.name
  t.homepage = "#{t.name}.rubyforge.org"
  t.version = "0.1.0"
  t.description = <<-EOS
    +Cond+ allows errors to be handled at the place where they occur.
    You decide whether or not the stack should be unwound, depending on
    the circumstance and the error.
  EOS
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
