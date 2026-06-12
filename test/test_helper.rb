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
