require_relative 'lib/crud_components/version'

Gem::Specification.new do |spec|
  spec.name = 'crud_components'
  spec.version = CrudComponents::VERSION
  spec.authors = ['Anatoly Zelenin']
  spec.email = ['anatoly@zelenin.de']

  spec.summary = 'Declarative CRUD UI for ActiveRecord models, rendered inside your app'
  spec.description = 'Tables, record views and filter forms derived from what Rails ' \
                     'already knows about your models. Zero configuration works; ' \
                     'declarations only improve. Forms render through simple_form; ' \
                     'nothing beyond Rails is otherwise required.'
  spec.homepage = 'https://github.com/itadventurer/crud_components'
  spec.license = 'MIT'
  # 3.2 floor: the lib itself only needs 3.1-era syntax, but Ruby 3.1 is EOL and
  # i18n (>= 1.15, pulled transitively by Rails) uses Fiber storage that needs
  # 3.2+. The CI matrix proves Ruby 3.2–3.4.
  spec.required_ruby_version = '>= 3.2'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Prefer git, but fall back to a glob so the gem (and the demo image) build
  # without a .git directory. Excludes tests, the dummy, CI and demo-deploy
  # artifacts — none ship in the gem.
  tracked = `git ls-files -z`.split("\x0")
  tracked = Dir.glob('**/*', File::FNM_DOTMATCH).select { |f| File.file?(f) } if tracked.empty?
  spec.files = tracked.reject do |f|
    f.start_with?('test/', 'script/', '.github/', 'docs/screenshots/', 'deploy/') ||
      %w[AGENTS.md Dockerfile .dockerignore].include?(f)
  end
  spec.require_paths = ['lib']

  spec.add_dependency 'actionview', '>= 7.1'
  spec.add_dependency 'activerecord', '>= 7.1'
  spec.add_dependency 'activesupport', '>= 7.1'
  # Form rendering. simple_form's wrappers are the standard way to make form
  # markup match a design system (Bootstrap/Tailwind/Bulma/…); deferring to it
  # is less code and a better fit than reinventing wrappers. Light + ubiquitous.
  spec.add_dependency 'simple_form', '>= 5.0'
end
