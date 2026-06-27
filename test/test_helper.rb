ENV['RAILS_ENV'] = 'test'

require_relative 'dummy/config/environment'

ActiveRecord::Schema.verbose = false
load File.expand_path('dummy/db/schema.rb', __dir__)

require 'rails/test_help'

module CrudTestHelpers
  # Anonymous model on an existing table, for DSL validation tests.
  def define_model(table: 'books', name: 'TempModel', &block)
    klass = Class.new(ApplicationRecord) do
      self.table_name = table
      include CrudComponents::Model
      define_singleton_method(:name) { name }
    end
    klass.crud_structure(&block) if block
    klass
  end

  def structure_of(model)
    CrudComponents::Structure.for(model)
  end

  # Run a block with RENDERER_GEMS swapped — lets the "missing gem raises" test
  # simulate an absent renderer gem even though the playground bundles the real
  # ones (commonmarker/asciidoctor) for its demos.
  def with_renderer_gems(map)
    original = CrudComponents::Structure::RENDERER_GEMS
    CrudComponents::Structure.send(:remove_const, :RENDERER_GEMS)
    CrudComponents::Structure.const_set(:RENDERER_GEMS, map.freeze)
    yield
  ensure
    CrudComponents::Structure.send(:remove_const, :RENDERER_GEMS)
    CrudComponents::Structure.const_set(:RENDERER_GEMS, original)
  end

  # A can?-shaped ability granting everything (for permission tests).
  class AllowAll
    def can?(*) = true
  end

  class DenyAll
    def can?(*) = false
  end
end

module ActiveSupport
  class TestCase
    include CrudTestHelpers
  end
end
