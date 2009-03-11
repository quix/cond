$LOAD_PATH.unshift "contrib/quix/lib"

require 'rake/gempackagetask'
require 'rake/contrib/rubyforgepublisher'

$VERBOSE = nil
require 'rdoc/rdoc'
$VERBOSE = true

require 'fileutils'
include FileUtils

PROJECT_NAME = "cond"
GEMSPEC = eval(File.read("#{PROJECT_NAME}.gemspec"))
raise unless GEMSPEC.name == PROJECT_NAME

DOC_DIR = "html"

######################################################################
# default

task :default => :test

######################################################################
# clean

task :clean => [:clobber, :clean_doc] do
end

task :clean_doc do
  rm_rf(DOC_DIR)
end

######################################################################
# test

task :test do
  require 'test/all'
  Dir["test/test_*.rb"].each { |file|
    require file
  }
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
  files = %w[README lib/cond.rb]

  options = [
    "-o", DOC_DIR,
    "--title", "#{GEMSPEC.name}: #{GEMSPEC.summary}",
    "--main", "README"
  ]

  RDoc::RDoc.new.document(files + options)
end

######################################################################
# git

def git(*args)
  cmd = ["git"] + args
  sh(*cmd)
end

######################################################################
# publisher

task :publish => :doc do
  Rake::RubyForgePublisher.new(GEMSPEC.name, 'quix').upload
end

######################################################################
# release

task :prerelease => :clean do
  rm_rf(DOC_DIR)
  rm_rf("pkg")
  unless `git status` =~ %r!nothing to commit \(working directory clean\)!
    raise "Directory not clean"
  end
  unless `ping -c2 github.com` =~ %r!0% packet loss!i
    raise "No ping for github.com"
  end
end

def rubyforge(command, file)
  sh("rubyforge",
     command,
     GEMSPEC.rubyforge_project,
     GEMSPEC.rubyforge_project,
     GEMSPEC.version.to_s,
     file)
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
