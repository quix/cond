
require 'rake'
require 'spec/rake/spectask'
require 'rake/gempackagetask'
require 'rake/contrib/rubyforgepublisher'
require 'rdoc/rdoc'

require 'fileutils'
include FileUtils

README = "README"
PROJECT_NAME = "cond"
GEMSPEC = eval(File.read("#{PROJECT_NAME}.gemspec"))
raise unless GEMSPEC.name == PROJECT_NAME
DOC_DIR = "html"

SPEC_FILES = Dir['spec/*_spec.rb'] + Dir['examples/*_example.rb']
SPEC_OUTPUT = "spec_output.html"

######################################################################
# default

task :default => :spec

######################################################################
# spec

Spec::Rake::SpecTask.new('spec') do |t|
  t.spec_files = SPEC_FILES
end

Spec::Rake::SpecTask.new('text_spec') do |t|
  t.spec_files = SPEC_FILES
  t.spec_opts = ['-fs']
end

Spec::Rake::SpecTask.new('full_spec') do |t|
  t.spec_files = SPEC_FILES
  t.rcov = true
  exclude_dirs = %w[readmes support examples spec]
  t.rcov_opts = exclude_dirs.inject(Array.new) { |acc, dir|
    acc + ["--exclude", dir]
  }
  t.spec_opts = ["-fh:#{SPEC_OUTPUT}"]
end

task :show_full_spec => :full_spec do
  args = SPEC_OUTPUT, "coverage/index.html"
  open_browser(*args)
end

######################################################################
# readme

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

######################################################################
# clean

task :clean => [:clobber, :clean_doc] do
end

task :clean_doc do
  rm_rf(DOC_DIR)
  rm_f(SPEC_OUTPUT)
end

######################################################################
# package

task :package => :clean

Rake::GemPackageTask.new(GEMSPEC) { |t|
  t.need_tar = true
}

######################################################################
# doc

task :doc => :clean_doc do 
  files = %W[#{README} lib/cond.rb]

  options = [
    "-o", DOC_DIR,
    "--title", "#{GEMSPEC.name}: #{GEMSPEC.summary}",
    "--main", README
  ]

  RDoc::RDoc.new.document(files + options)
end

task :rdoc => :doc

task :show_doc => :doc do
  open_browser("#{DOC_DIR}/index.html")
end

######################################################################
# misc

def open_browser(*files)
  if Config::CONFIG["host"] =~ %r!darwin!
    sh("open", "/Applications/Firefox.app", *files)
  else
    sh("firefox", *files)
  end
end

######################################################################
# git

def git(*args)
  sh("git", *args)
end

######################################################################
# publisher

task :publish => :doc do
  Rake::RubyForgePublisher.new(GEMSPEC.name, 'quix').upload
end

######################################################################
# release

unless respond_to? :tap
  module Kernel
    def tap
      yield self
      self
    end
  end
end 

task :prerelease => :clean do
  rm_rf(DOC_DIR)
  rm_rf("pkg")
  unless `git status` =~ %r!nothing to commit \(working directory clean\)!
    raise "Directory not clean"
  end
  unless `ping github.com 2 2` =~ %r!0% packet loss!i
    raise "No ping for github.com"
  end
end

def rubyforge(command, file)
  sh(
    "rubyforge",
    command,
    GEMSPEC.rubyforge_project,
    GEMSPEC.rubyforge_project,
    GEMSPEC.version.to_s,
    file
  )
end

task :finish_release do
  gem, tgz = %w(gem tgz).map { |ext|
    "pkg/#{GEMSPEC.name}-#{GEMSPEC.version}.#{ext}"
  }
  gem_md5, tgz_md5 = [gem, tgz].map { |file|
    "#{file}.md5".tap { |md5|
      sh("md5sum #{file} > #{md5}")
    }
  }

  rubyforge("add_release", gem)
  rubyforge("add_file", gem_md5)
  rubyforge("add_file", tgz)
  rubyforge("add_file", tgz_md5)

  git("tag", "#{GEMSPEC.name}-" + GEMSPEC.version.to_s)
  git(*%w(push --tags origin master))
end

task :release =>
  [
   :prerelease,
   :package,
   :publish,
   :finish_release,
  ]
