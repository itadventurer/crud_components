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

  # Swap a model's crud_structure for a minimal one with the given label.
  def with_label(model, label_name)
    original = model.instance_variable_get(:@_crud_structure_block)
    model.reset_crud_structure!
    model.crud_structure { label label_name }
    yield
  ensure
    model.instance_variable_set(:@_crud_structure_block, original)
    model.instance_variable_set(:@_crud_structure, nil)
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

  # A translated sidebar group heading for the duration of the block.
  def with_group_translation(heading, key: :custom_properties)
    I18n.backend.store_translations(:en, crud_components: { admin: { groups: { key => heading } } })
    yield
  ensure
    I18n.backend.reload!
  end

  # Swap in a blank admin configuration (and a registry reading it) for the
  # duration of a test; #restore_admin_config! puts the app's own back.
  def reset_admin_config!
    @original_admin_config ||= CrudComponents::Admin.config
    swap_admin_config(CrudComponents::Admin::Configuration.new)
  end

  def restore_admin_config!
    swap_admin_config(@original_admin_config) if @original_admin_config
    @original_admin_config = nil
  end

  def swap_admin_config(config)
    CrudComponents::Admin.instance_variable_set(:@config, config)
    CrudComponents::Admin.instance_variable_set(:@registry, nil)
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
