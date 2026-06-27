# Defines the `build`/`install`/`release` tasks from the gemspec. The
# rubygems/release-gem CI action runs `rake release` to push the gem.
require 'bundler/gem_tasks'
require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.test_files = FileList['test/**/*_test.rb']
end

task default: :test
