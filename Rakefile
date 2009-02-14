require "rake/gempackagetask"
require 'rake/rdoctask'
require "rake/clean"
require 'spec'
require 'spec/rake/spectask'
require 'spec/rake/verify_rcov'
$LOAD_PATH.unshift << "lib" 
require 'caching_presenter'

##############################################################################
# Package && release
##############################################################################
spec = Gem::Specification.new do |s|
  s.name         = "caching_presenter"
  s.version      = CachingPresenter::VERSION
  s.platform     = Gem::Platform::RUBY
  s.author       = "Zach Dennis"
  s.email        = "zdennis" + "@" + "mutuallyhuman.com"
  s.homepage     = "http://github.com/mhs/caching_presenter"
  s.summary      = "CachingPresenter - an implementation of the presenter pattern in Ruby"
  s.description  = s.summary
  s.require_path = "lib"
  s.files        = %w(History.txt MIT-LICENSE.txt README.rdoc Rakefile) + Dir["lib/**/*"] + Dir["spec/**/*"]

  # rdoc
  s.has_rdoc         = true
  s.extra_rdoc_files = %w(README.rdoc MIT-LICENSE.txt)

  s.rubyforge_project = "caching_presenter"
end

Rake::GemPackageTask.new(spec) do |package|
  package.gem_spec = spec
end

desc 'Show information about the gem.'
task :debug_gem do
  puts spec.to_ruby
end

CLEAN.include ["pkg", "*.gem", "doc", "ri", "coverage"]

# desc "Upload rdoc to mutuallyhuman.com"
# task :publish_rdoc => :docs do
#   sh "scp -r doc/ mutuallyhuman.com:/apps/uploads/"
# end

desc "Run specs"
Spec::Rake::SpecTask.new do |t|
  t.spec_opts = ['--options', "\"#{File.dirname(__FILE__)}/spec/spec.opts\""]
  t.spec_files = FileList['spec/**/*_spec.rb']
end

desc "Run all specs with RCov"
Spec::Rake::SpecTask.new(:rcov) do |t|
  t.spec_opts = ['--options', "\"#{File.dirname(__FILE__)}/spec/spec.opts\""]
  t.spec_files = FileList['spec/**/*_spec.rb']
  t.rcov = true
  t.rcov_opts = lambda do
    IO.readlines(File.dirname(__FILE__) + "/spec/rcov.opts").map {|l| l.chomp.split " "}.flatten
  end
end

RCov::VerifyTask.new(:verify_rcov => :rcov) do |t|
  t.threshold = 96.2 # Make sure you have rcov 0.7 or higher!
end

desc "Install the package as a gem."
task :install_gem => [:clean, :package] do
  gem_filename = Dir['pkg/*.gem'].first
  sh "sudo gem install --no-rdoc --no-ri --local #{gem_filename}"
end

desc "Delete generated RDoc"
task :clobber_docs do
  FileUtils.rm_rf("doc")
end

desc "Generate RDoc"
task :docs => :clobber_docs do
  system "hanna --title 'CachingPresenter #{CachingPresenter::VERSION} API Documentation'"
end

# desc "Run specs using jruby"
# task "spec:jruby" do
#   result = system "jruby -S rake spec"
#   raise "JRuby tests failed" unless result
# end

desc "Run each spec in isolation to test for dependency issues"
task :spec_deps do
  Dir["spec/**/*_spec.rb"].each do |test|
    if !system("spec #{test} &> /dev/null")
      puts "Dependency Issues: #{test}"
    end
  end
end


task :default => :spec

# task :precommit => ["spec", "spec:jruby", ""]