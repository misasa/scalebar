require "bundler/gem_tasks"
require "rspec/core/rake_task"
require_relative "lib/scalebar/version"

RSpec::Core::RakeTask.new(:spec)
task default: :spec

desc "Run the specs, build the gem, and check its installed executable"
task verify: [:spec, :build] do
  ruby "script/verify_package.rb", "pkg/scalebar-#{Scalebar::VERSION}.gem"
end
