require "bundler/gem_tasks"

require "rake"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = Dir.glob("spec/**/*_spec.rb")
  t.rspec_opts = "--format documentation --tag ~integration --tag ~connected --tag ~slow"
end

task default: :spec

desc "Run integration tests against a live TWS/Gateway"
task :integration do
  sh "TEST_ENV=real bundle exec rspec --tag integration"
end
