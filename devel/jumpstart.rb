$LOAD_PATH.unshift File.dirname(__FILE__) + '/../lib'
$LOAD_PATH.unshift File.dirname(__FILE__)

require 'rubygems'
require 'ostruct'
require 'rbconfig'

require 'rake/gempackagetask'
require 'rake/contrib/sshpublisher'
require 'rake/clean'

require 'rdoc/rdoc'

require 'jumpstart/ruby'
require 'jumpstart/attr_lazy'
require 'jumpstart/simple_installer'

class Jumpstart
  include AttrLazy

  attr_reader :project_name

  def initialize(project_name)
    @project_name = project_name

    yield self

    self.class.instance_methods(false).select { |t|
      t.to_s =~ %r!\Adefine_!
    }.each { |method_name|
      send(method_name)
    }
  end

  class << self
    alias_method :attribute, :attr_lazy_accessor
  end

  attribute :name do
    project_name
  end

  attribute :version do
    require name
    mod = to_camel_case(name)
    
    (full_const_get("#{mod}::VERSION") rescue nil) ||
    (full_const_get("#{mod}::#{mod}Private::VERSION") rescue nil) ||
    "0.0.0"
  end
  
  attribute :rubyforge_name do
    name.gsub('_', '')
  end

  attribute :rubyforge_user do
    email.first[%r!^.*(?=@)!]
  end
  
  attribute :readme_file do
    "README.rdoc"
  end
  
  attribute :history_file do
    "CHANGES.rdoc"
  end
  
  attribute :doc_dir do
    "documentation"
  end
  
  attribute :spec_files do
    Dir["spec/*_{spec,example}.rb"]
  end
  
  attribute :test_files do
    (Dir["test/test_*.rb"] + Dir["test/*_test.rb"]).uniq
  end
  
  attribute :rcov_dir do
    "coverage"
  end
  
  attribute :spec_output do
    "spec.html"
  end

  [:gem, :tgz].map { |ext|
    attribute ext do
      "pkg/#{name}-#{version}.#{ext}"
    end
  }

  attribute :rcov_options do
    # workaround for the default rspec task
    Dir["*"].select { |f| File.directory? f }.inject(Array.new) { |acc, dir|
      if dir == "lib"
        acc
      else
        acc + ["--exclude", dir + "/"]
      end
    } + ["--text-report"]
  end

  attribute :readme_file do
    "README.rdoc"
  end
    
  attribute :manifest_file do
    "MANIFEST"
  end

  attribute :files do
    if File.exist?(manifest_file)
      File.read(manifest_file).split("\n")
    else
      [manifest_file] + `git ls-files`.split("\n")
    end
  end

  attribute :rdoc_files do
    Dir["lib/**/*.rb"]
  end
    
  attribute :extra_rdoc_files do
    if File.exist?(readme_file)
      [readme_file]
    else
      []
    end
  end

  attribute :rdoc_options do
    if File.exist?(readme_file)
      ["--main", readme_file]
    else
      []
    end + [
     "--title", "#{name}: #{summary}",
    ] + (files - rdoc_files).inject(Array.new) { |acc, file|
      acc + ["--exclude", file]
    }
  end

  attribute :browser do
    if Config::CONFIG["host"] =~ %r!darwin!
      app = %w[Firefox Safari].map { |t|
        "/Applications/#{t}.app"
      }.select { |t|
        File.exist? t
      }.first
      if app
        ["open", app]
      else
        raise "need to set `browser'"
      end
    else
      "firefox"
    end
  end

  attribute :gemspec do
    Gem::Specification.new { |g|
      g.has_rdoc = true
      %w[
        name
        authors
        email
        summary
        version
        description
        files
        extra_rdoc_files
        rdoc_options
      ].each { |param|
        value = send(param) and (
          g.send("#{param}=", value)
        )
      }

      if rubyforge_name
        g.rubyforge_project = rubyforge_name
      end

      if url
        g.homepage = url
      end

      extra_deps.each { |dep|
        g.add_dependency(*dep)
      }

      extra_dev_deps.each { |dep|
        g.add_development_dependency(*dep)
      }
    }
  end

  attribute :readme_contents do
    File.read(readme_file) rescue "FIXME: readme_file"
  end
  
  attribute :sections do
    begin
      pairs = Hash[*readme_contents.split(%r!^== (\w+).*?$!)[1..-1]].map {
        |section, contents|
        [section.downcase, contents.strip]
      }
      Hash[*pairs.flatten]
    rescue
      nil
    end
  end

  attribute :description_section do
    "description"
  end

  attribute :summary_section do
    "summary"
  end

  attribute :description_sentences do
    1
  end

  attribute :summary_sentences do
    1
  end
  
  [:summary, :description].each { |section|
    attribute section do
      begin
        sections[send("#{section}_section")].
        gsub("\n", " ").
        split(%r!\.\s*!m).
        first(send("#{section}_sentences")).
        join(".  ") << "."
      rescue
        "FIXME: #{section}"
      end
    end
  }

  attribute :url do
    begin
      readme_contents.match(%r!^\*.*?(http://\S+)!)[1]
    rescue
      "http://#{rubyforge_name}.rubyforge.org"
    end
  end

  attribute :extra_deps do
    []
  end

  attribute :extra_dev_deps do
    []
  end

  attribute :authors do
    Array.new
  end

  attribute :email do
    Array.new
  end

  def developer(name, email)
    authors << name
    self.email << email
  end

  def dependency(name, version)
    extra_deps << [name, version]
  end

  def define_clean
    task :clean do
      Rake::Task[:clobber].invoke
    end
  end

  def define_package
    task manifest_file do
      create_manifest
    end
    CLEAN.include manifest_file
    task :package => :clean
    Rake::GemPackageTask.new(gemspec) { |t|
      t.need_tar = true
    }
  end

  def define_spec
    unless spec_files.empty?
      require 'spec/rake/spectask'
      
      desc "run specs"
      Spec::Rake::SpecTask.new('spec') do |t|
        t.spec_files = spec_files
      end
    
      desc "run specs with text output"
      Spec::Rake::SpecTask.new('text_spec') do |t|
        t.spec_files = spec_files
        t.spec_opts = ['-fs']
      end
  
      desc "run specs with html output"
      Spec::Rake::SpecTask.new('full_spec') do |t|
        t.spec_files = spec_files
        t.rcov = true
        t.rcov_opts = rcov_options
        t.spec_opts = ["-fh:#{spec_output}"]
      end
      
      desc "run full_spec then open browser"
      task :show_spec => :full_spec do
        open_browser(spec_output, rcov_dir + "/index.html")
      end

      desc "run specs individually"
      task :spec_deps do
        run_ruby_on_each(*spec_files)
      end

      task :prerelease => [:spec, :spec_deps]
      task :default => :spec

      CLEAN.include spec_output
    end
  end

  def define_test
    unless test_files.empty?
      desc "run tests"
      task :test do
        test_files.each { |file|
          require file
        }
      end
      
      desc "run tests with rcov"
      task :full_test do
        verbose(false) {
          sh("rcov", "-o", rcov_dir, "--text-report",
            *(test_files + rcov_options)
          )
        }
      end
      
      desc "run full_test then open browser"
      task :show_test => :full_test do
        open_browser(rcov_dir + "/index.html")
      end
      
      desc "run tests individually"
      task :test_deps do
        run_ruby_on_each(*test_files)
      end
      
      task :prerelease => [:test, :test_deps]
      task :default => :test
      
      CLEAN.include rcov_dir
    end
  end

  def define_doc
    desc "run rdoc"
    task :doc => :clean_doc do
      args = (
        gemspec.rdoc_options +
        gemspec.require_paths.clone +
        gemspec.extra_rdoc_files +
        ["-o", doc_dir]
      ).flatten.map { |t| t.to_s }
      RDoc::RDoc.new.document args
    end
    
    task :clean_doc do
      # normally rm_rf, but mimic rake/clean output
      rm_r(doc_dir) rescue nil
    end

    desc "run rdoc then open browser"
    task :show_doc => :doc do
      open_browser(doc_dir + "/index.html")
    end

    task :rdoc => :doc
    task :clean => :clean_doc
  end

  def define_publish
    desc "upload docs"
    task :publish => [:clean_doc, :doc] do
      Rake::SshDirPublisher.new(
        "#{rubyforge_user}@rubyforge.org",
        "/var/www/gforge-projects/#{rubyforge_name}",
        doc_dir
      ).upload
    end
  end

  def define_install
    desc "direct install (no gem)"
    task :install do
      SimpleInstaller.new.run([])
    end

    desc "direct uninstall (no gem)"
    task :uninstall do
      SimpleInstaller.new.run(["--uninstall"])
    end
  end
  
  def define_debug
    runner = Class.new do
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
            Jumpstart.replace_file(path) { |contents|
              result = comment_regions(!enable, contents, "debug")
              comment_lines(!enable, result, "trace")
            }
          end
        }
      end
    end
    
    desc "enable debug and trace calls"
    task :debug_on do
      runner.new.debug_info(true)
    end
    
    desc "disable debug and trace calls"
    task :debug_off do
      runner.new.debug_info(false)
    end
  end

  def define_columns
    desc "check for columns > 80"
    task :check_columns do
      Dir["**/*.rb"].each { |file|
        File.read(file).scan(%r!^.{81}!) { |match|
          unless match =~ %r!http://!
            raise "#{file} greater than 80 columns: #{match}"
          end
        }
      }
    end
    task :prerelease => :check_columns
  end

  def define_comments
    task :comments do
      file = "comments.txt"
      Jumpstart.write_file(file) {
        result = Array.new
        (["Rakefile"] + Dir["**/*.{rb,rake}"]).each { |file|
          File.read(file).scan(%r!\#[^\{].*$!) { |match|
            result << match
          }
        }
        result.join("\n")
      }
      CLEAN.include file
    end
  end

  def define_check_directory
    task :check_directory do
      unless `git status` =~ %r!nothing to commit \(working directory clean\)!
        raise "Directory not clean"
      end
    end
  end

  def define_ping
    task :ping do
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
  end

  def define_update_jumpstart
    url = ENV["RUBY_JUMPSTART"] || "git://github.com/quix/jumpstart.git"
    task :update_jumpstart do
      git "clone", url
      rm_rf "devel/jumpstart"
      Dir["jumpstart/**/*.rb"].each { |source|
        dest = source.sub(%r!\Ajumpstart/!, "devel/")
        dest_dir = File.dirname(dest)
        mkdir_p(dest_dir) unless File.directory?(dest_dir)
        cp source, dest
      }
      rm_r "jumpstart"
      git "commit", "devel", "-m", "update jumpstart"
    end
  end

  def git(*args)
    sh("git", *args)
  end

  def create_manifest
    Jumpstart.write_file(manifest_file) {
      files.sort.join("\n")
    }
  end

  def rubyforge(command, file)
    sh(
      "rubyforge",
      command,
      rubyforge_name,
      rubyforge_name,
      version.to_s,
      file
    )
  end

  def define_release
    task :prerelease => [:clean, :check_directory, :ping]

    task :finish_release do
      gem_md5, tgz_md5 = [gem, tgz].map { |file|
        md5 = "#{file}.md5"
        sh("md5sum #{file} > #{md5}")
        md5
      }

      rubyforge("add_release", gem)
      [gem_md5, tgz, tgz_md5].each { |file|
        rubyforge("add_file", file)
      }

      git("tag", "#{name}-" + version.to_s)
      git(*%w(push --tags origin master))
    end

    task :release => [:prerelease, :package, :publish, :finish_release]
  end

  def define_debug_gem
    task :debug_gem do
      puts gemspec.to_ruby
    end
  end
  
  def open_browser(*files)
    sh(*([browser].flatten + files))
  end

  def run_ruby_on_each(*files)
    files.each { |file|
      Ruby.run("-w", file)
    }
  end

  def to_camel_case(str)
    str.split('_').map { |t| t.capitalize }.join
  end

  def full_const_get(string)
    string.split("::").inject(Object) { |acc, name|
      if acc.constants.include?(name)
        acc.const_get(name)
      else
        raise NameError, "uninitialized constant #{string}"
      end
    }
  end

  class << self
    def write_file(file)
      contents = yield
      File.open(file, "wb") { |out|
        out.print(contents)
      }
      contents
    end

    def replace_file(file)
      old_contents = File.read(file)
      new_contents = yield(old_contents)
      if old_contents != new_contents
        File.open(file, "wb") { |output|
          output.print(new_contents)
        }
      end
      new_contents
    end

    def run_doc_section(file, section)
      require 'tempfile'

      body, expected = (
        contents = File.read(file)
        re = %r!^=+[ \t]*#{section}.*?^(.*?)^(\S.*?)\s*?^(.*?)^\S!m
        if match = contents.match(re)
          if match[2] == "output:"
            [match[1], match[3]]
          else
            [match[1], match[1].scan(%r!\# => (.*?)\n!).flatten.join("\n")]
          end
        else
          raise "couldn't find section `#{section}' of `#{file}'"
        end
      )

      lib = File.expand_path(File.dirname(__FILE__) + "/../lib")
      header = %{
        $LOAD_PATH.unshift "#{lib}"
        require 'rubygems'
      }
      code = header + body

      actual = nil
      Tempfile.open("run-ruby-#{file}") { |temp_file|
        temp_file.print(code)
        temp_file.close
        result = `"#{::Jumpstart::Ruby::EXECUTABLE}" "#{temp_file.path}"`
        unless $?.exitstatus == 0
          raise "failed to run ruby"
        end
        actual = result.chomp
      }

      if block_given?
        yield expected, actual
      else
        [expected, actual]
      end
    end

    def doc_to_spec(file, *sections, &block)
      jump = self
      describe file do
        sections.each { |section|
          describe section do
            it "should run as claimed" do
              expected, actual = jump.run_doc_section(file, section, &block)
              actual.should == expected
            end
          end
        }
      end
    end

    def doc_to_test(file, *sections, &block)
      jump = self
      klass = Class.new Test::Unit::TestCase do
        sections.each { |section|
          define_method "test_#{file}_#{section}" do
            expected, actual = jump.run_doc_section(file, section, &block)
            assert_equal expected, actual
          end
        }
      end
      # minitest fails without a const name in 1.9
      Object.const_set("Test#{file}".gsub(".", ""), klass)
    end
  end
end

