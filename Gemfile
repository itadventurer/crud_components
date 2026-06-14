source 'https://rubygems.org'

gemspec

# The CI matrix sets RAILS_VERSION to pin a minor (e.g. 7.1, 7.2, 8.0) and
# resolves a fresh lockfile per combo; unset, dev just uses the latest.
rails_version = ENV['RAILS_VERSION']

group :development, :test do
  gem 'kaminari' # playground only: the gem ships no pager; the demo brings one
  gem 'minitest'
  gem 'puma'
  gem 'rails', rails_version ? "~> #{rails_version}.0" : '>= 7.1'
  gem 'rake'
  gem 'sqlite3' # unconstrained: bundler picks a version compatible with the Rails above
end
