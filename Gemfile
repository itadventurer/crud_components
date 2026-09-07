source 'https://rubygems.org'

gemspec

# The CI matrix sets RAILS_VERSION to pin a minor (e.g. 7.1, 7.2, 8.0) and
# resolves a fresh lockfile per combo; unset, dev just uses the latest.
rails_version = ENV.fetch('RAILS_VERSION', nil)

group :development, :test do
  gem 'image_processing' # playground only: lets the attachment renderer preview PDFs (with poppler)
  gem 'kaminari' # playground only: the gem ships no pager; the demo brings one
  gem 'ruby-vips' # playground only: the libvips backend image_processing uses to make previews
  # playground only: soft-dependency renderers (as: :markdown / :asciidoc / :json highlight).
  # crud_components feature-detects these — it never requires them itself.
  gem 'asciidoctor'  # as: :asciidoc
  gem 'commonmarker' # as: :markdown
  gem 'minitest'
  gem 'puma'
  gem 'rails', rails_version ? "~> #{rails_version}.0" : '>= 7.1'
  # json 3.0.0 dropped the second positional argument of JSON.parse, which
  # ActiveSupport::JSON.decode still passes (active_support/json/decoding.rb).
  # Every Rails 8.1 request that reads a signed or encrypted cookie therefore
  # raises ArgumentError, the session included. Not ours to fix and not ours to
  # constrain for the people who install the gem, so the pin lives here in the
  # development bundle. Drop it once Rails ships a compatible ActiveSupport.
  gem 'json', '< 3'
  gem 'rake'
  gem 'rouge'        # :json cell syntax highlighting
  # Linting. Pinned to a minor so a new cop cannot turn CI red on a commit that
  # did not touch the code; bump deliberately.
  gem 'rubocop', '~> 1.81.0', require: false
  gem 'rubocop-minitest', '~> 0.38.2', require: false
  gem 'rubocop-performance', '~> 1.26.0', require: false
  gem 'rubocop-rails', '~> 2.34.0', require: false
  gem 'rubocop-rake', '~> 0.7.1', require: false
  gem 'sqlite3' # unconstrained: bundler picks a version compatible with the Rails above
end
