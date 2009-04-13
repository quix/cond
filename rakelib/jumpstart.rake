$LOAD_PATH.unshift File.dirname(__FILE__)

require 'rake/gempackagetask'
require 'rake/contrib/sshpublisher'
require 'rake/clean'
require 'rdoc/rdoc'

require "jumpstart/simple_installer"
require "jumpstart/ruby"

######################################################################
# constants

unless defined?(RUBYFORGE_USER)
  RUBYFORGE_USER = "quix"
end

GEMSPEC = eval(File.read(Dir["*.gemspec"].last))

DOC_DIR = "documentation"
SPEC_FILES = Dir['spec/*_spec.rb'] + Dir['examples/*_example.rb']
TEST_FILES = Dir['test/test_*.rb']
RCOV_DIR = "coverage"
SPEC_OUTPUT = "spec.html"

RCOV_OPTIONS = Dir["*"].select { |file|
  File.directory?(file) and file != "lib"
}.inject(Array.new) { |acc, file|
  acc + ["--exclude", file + "/"]
}

######################################################################
# spec

unless SPEC_FILES.empty?
  require 'spec/rake/spectask'

  desc "run specs"
  Spec::Rake::SpecTask.new('spec') do |t|
    t.spec_files = SPEC_FILES
  end
  
  desc "run specs with text output"
  Spec::Rake::SpecTask.new('text_spec') do |t|
    t.spec_files = SPEC_FILES
    t.spec_opts = ['-fs']
  end
  
  desc "run specs with html output"
  Spec::Rake::SpecTask.new('full_spec') do |t|
    t.spec_files = SPEC_FILES
    t.rcov = true
    t.rcov_opts = RCOV_OPTIONS
    t.spec_opts = ["-fh:#{SPEC_OUTPUT}"]
  end
  
  desc "run full_spec then open browser"
  task :show_spec => :full_spec do
    open_browser(SPEC_OUTPUT, RCOV_DIR + "/index.html")
  end

  desc "run specs individually"
  task :spec_deps do
    run_ruby_on_each(*SPEC_FILES)
  end

  task :prerelease => :spec_deps

  task :default => :spec

  CLEAN.include(SPEC_OUTPUT)
end

######################################################################
# test

unless TEST_FILES.empty?
  desc "run tests"
  task :test do
    TEST_FILES.each { |file|
      require file
    }
  end

  desc "run tests with rcov"
  task :full_test do
    previous = RakeFileUtils.verbose_flag
    begin
      sh("rcov", "-o", RCOV_DIR, *(TEST_FILES + RCOV_OPTIONS))
    ensure
      RakeFileUtils.verbose_flag = previous
    end
  end

  desc "run full_test then open browser"
  task :show_test => :full_test do
    open_browser(RCOV_DIR + "/index.html")
  end

  desc "run tests individually"
  task :test_deps do
    run_ruby_on_each(*TEST_FILES)
  end

  task :prerelease => :test_deps
  task :default => :test

  CLEAN.include RCOV_DIR
end

######################################################################
# clean

task :clean do
  Rake::Task[:clobber].invoke
end

######################################################################
# package

task :package => :clean
task :gem => :clean

Rake::GemPackageTask.new(GEMSPEC) { |t|
  t.need_tar = true
}

######################################################################
# doc

#
# Try to mimic the gem documentation
#
desc "run rdoc"
task :doc => :clean_doc do
  args = (
    GEMSPEC.rdoc_options +
    GEMSPEC.require_paths.clone +
    GEMSPEC.extra_rdoc_files +
    ["-o", DOC_DIR]
  ).flatten.map { |t| t.to_s }
  RDoc::RDoc.new.document args
end

task :clean_doc do
  # normally rm_rf, but mimic rake/clean
  rm_r(DOC_DIR) rescue nil
end

desc "run rdoc then open browser"
task :show_doc => :doc do
  open_browser(DOC_DIR + "/index.html")
end

task :rdoc => :doc
task :clean => :clean_doc

######################################################################
# publisher

desc "upload docs"
task :publish => [:clean_doc, :doc] do
  Rake::SshDirPublisher.new(
    "#{RUBYFORGE_USER}@rubyforge.org",
    "/var/www/gforge-projects/#{GEMSPEC.rubyforge_project}",
    DOC_DIR
  ).upload
end

######################################################################
# install/uninstall

desc "direct install (no gem)"
task :install do
  Jumpstart::SimpleInstaller.new.run([])
end

desc "direct uninstall (no gem)"
task :uninstall do
  Jumpstart::SimpleInstaller.new.run(["--uninstall"])
end

######################################################################
# debug

def comment_src_dst(on)
  on ? ["", "#"] : ["#", ""]
end

def comment_regions(on, contents, start)
  src, dst = comment_src_dst(on)
  contents.gsub(%r!^(\s+)#{src}#{start}.*?^\1#{src}(\}|end)!m) { |chunk|
    indent = $1
    chunk.gsub(%r!^#{indent}#{src}!, "#{indent}#{dst}")
  }
end

def comment_lines(on, contents, start)
  src, dst = comment_src_dst(on)
  contents.gsub(%r!^(\s*)#{src}#{start}!) { 
    $1 + dst + start
  }
end

def debug_info(enable)
  Find.find("lib", "test") { |path|
    if path =~ %r!\.rb\Z!
      replace_file(path) { |contents|
        result1 = comment_regions(!enable, contents, "def trace_compute")
        result2 = comment_regions(!enable, result1, "debug")
        comment_lines(!enable, result2, "trace")
      }
    end
  }
end

desc "enable debug and trace calls"
task :debug_on do
  debug_info(true)
end

desc "disable debug and trace calls"
task :debug_off do
  debug_info(false)
end

######################################################################
# check columns

desc "check for columns > 80"
task :check_columns do
  Dir["**/*.rb"].each { |file|
    File.read(file).scan(%r!^.{81}!) { |match|
      unless match =~ %r!http://!
        raise "#{file} greater than 80 columns"
      end
    }
  }
end

task :prerelease => :check_columns

######################################################################
# comments

task :comments do
  write_file("comments") {
    Array.new.tap { |result|
      (["Rakefile"] + Dir["**/*.{rb,rake}"]).each { |file|
        File.read(file).scan(%r!\#[^\{].*$!) { |match|
          result << match
        }
      }
    }.join("\n")
  }
end

######################################################################
# release

def git(*args)
  sh("git", *args)
end

task :prerelease => :clean do
  unless `git status` =~ %r!nothing to commit \(working directory clean\)!
    raise "Directory not clean"
  end
  %w[github.com rubyforge.org].each { |server|
    cmd = "ping " + (
      if Config::CONFIG["host"] =~ %r!darwin!
        "-c2 #{server}"
      else
        "#{server} 2 2"
      end
    )
    unless `#{cmd}` =~ %r!0% packet loss!
      raise "No ping for #{server}"
    end
  }
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
  [gem_md5, tgz, tgz_md5].each { |file|
    rubyforge("add_file", file)
  }

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

######################################################################
# util

def open_browser(*files)
  if Config::CONFIG["host"] =~ %r!darwin!
    sh("open", "/Applications/Firefox.app", *files)
  else
    sh("firefox", *files)
  end
end

unless respond_to? :tap
  class Object
    def tap
      yield self
      self
    end
  end
end 

def replace_file(file)
  old_contents = File.read(file)
  yield(old_contents).tap { |new_contents|
    if old_contents != new_contents
      File.open(file, "wb") { |output|
        output.print(new_contents)
      }
    end
  }
end

def write_file(file)
  yield.tap { |contents|
    File.open(file, "wb") { |out|
      out.print(contents)
    }
  }
end

def run_ruby_on_each(*files)
  files.each { |file|
    Jumpstart::Ruby.run_or_raise("-w", file)
  }
end
