require_relative 'lib/crud_components/version'

Gem::Specification.new do |spec|
  spec.name = 'crud_components'
  spec.version = CrudComponents::VERSION
  spec.authors = ['Anatoly Zelenin']
  spec.email = ['anatoly@zelenin.de']

  spec.summary = 'Declarative CRUD UI for ActiveRecord models, rendered inside your app'
  spec.description = 'Tables, record views and filter forms derived from what Rails ' \
                     'already knows about your models. Zero configuration works; ' \
                     'declarations only improve. No runtime dependencies outside Rails.'
  spec.homepage = 'https://github.com/itadventurer/crud_components'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.start_with?('test/', 'script/', '.github/') || %w[PROMPT.md DESIGN.md].include?(f)
  end
  spec.require_paths = ['lib']

  spec.add_dependency 'actionview', '>= 7.1'
  spec.add_dependency 'activerecord', '>= 7.1'
  spec.add_dependency 'activesupport', '>= 7.1'
end
