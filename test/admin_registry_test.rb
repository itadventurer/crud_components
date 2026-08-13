require_relative 'test_helper'

# Named (not anonymous) models, so discovery can resolve them back by name.
class AdminOptedOutModel < ApplicationRecord
  self.table_name = 'reviews'
  include CrudComponents::Model
  crud_structure { admin false }
end

class AdminReadOnlyModel < ApplicationRecord
  self.table_name = 'reviews'
  include CrudComponents::Model
  crud_structure do
    admin group: 'Reporting', label: 'Read-only things', actions: %i[index show]
  end
end

class AdminScopedModel < ApplicationRecord
  self.table_name = 'books'
  include CrudComponents::Model
  crud_structure do
    admin actions: %i[index new], scope: -> { where(active: true) }
    fieldset :admin, %i[title slug]
  end
end

class AdminRegistryTest < ActiveSupport::TestCase
  def setup
    CrudComponents::Admin.reset!
  end

  def teardown
    CrudComponents::Admin.reset!
  end

  def registry = CrudComponents::Admin.registry

  def names = registry.entries.map(&:name)

  # ── discovery ────────────────────────────────────────────────────────────
  test "registers the application's models" do
    assert_includes names, 'Book'
    assert_includes names, 'Publisher'
    assert_includes names, 'Author'
  end

  test 'skips framework internals' do
    assert_empty names.grep(/\AActiveStorage::/)
    assert_empty names.grep(/\AActionText::/)
    assert_empty names.grep(/HABTM_/)
  end

  test 'skips abstract classes' do
    assert_not_includes names, 'ApplicationRecord'
    assert_not_includes names, 'ActiveRecord::Base'
  end

  test 'skips STI subclasses but keeps their base class' do
    assert_includes names, 'Document'
    assert_not_includes names, 'Manual'
  end

  test 'skips a model that opted out' do
    assert_not_includes names, 'AdminOptedOutModel'
  end

  test 'discovery does not consult the database' do
    Object.const_set(:AdminNotMigratedModel, Class.new(ApplicationRecord) do
      self.table_name = 'not_migrated_yet'
      include CrudComponents::Model
    end)

    assert_includes names, 'AdminNotMigratedModel'
  ensure
    Object.send(:remove_const, :AdminNotMigratedModel)
  end

  test 'skips anonymous models' do
    define_model(name: 'GhostModel')

    assert_not_includes names, 'GhostModel'
  end

  # ── configuration ────────────────────────────────────────────────────────
  test 'except drops a model by name' do
    CrudComponents::Admin.configure { |config| config.except = %w[Review] }

    assert_not_includes names, 'Review'
    assert_includes names, 'Book'
  end

  test 'except accepts the class itself' do
    CrudComponents::Admin.configure { |config| config.except = [Review] }

    assert_not_includes names, 'Review'
  end

  test 'only registers exactly those models, in that order' do
    CrudComponents::Admin.configure { |config| config.only = %w[Publisher Book] }

    assert_equal %w[Publisher Book], names
  end

  test 'only still honours a model that opted out' do
    CrudComponents::Admin.configure { |config| config.only = %w[Book AdminOptedOutModel] }

    assert_equal %w[Book], names
  end

  test 'only ignores a name that is not a model' do
    CrudComponents::Admin.configure { |config| config.only = %w[Book NoSuchModel String] }

    assert_equal %w[Book], names
  end

  test 'configure rebuilds the registry' do
    assert_includes names, 'Review'
    CrudComponents::Admin.configure { |config| config.except = %w[Review] }

    assert_not_includes names, 'Review'
  end

  # ── entries ──────────────────────────────────────────────────────────────
  test 'an undeclared model gets every action' do
    entry = registry['Author']

    assert_equal CrudComponents::Admin::Entry::ALL_ACTIONS, entry.actions
    assert_not entry.read_only?
  end

  test 'declared actions are honoured and stay in RESTful order' do
    entry = registry['AdminReadOnlyModel']

    assert_equal %i[index show], entry.actions
    assert entry.read_only?
    assert entry.allows?(:index)
    assert_not entry.allows?(:destroy)
  end

  test 'new implies create and edit implies update' do
    entry = registry['AdminScopedModel']

    assert_equal %i[index new create], entry.actions
  end

  test 'the route key and param key come from the model and its identify_by' do
    entry = registry['Book']

    assert_equal 'books', entry.route_key
    assert_equal 'book', entry.singular_route_key
    assert_equal :slug, entry.param_key
  end

  test 'a model without identify_by is keyed by id' do
    assert_equal :id, registry['Author'].param_key
  end

  test 'the label defaults to the model name and can be declared' do
    assert_equal 'Read-only things', registry['AdminReadOnlyModel'].label
    assert_equal Author.model_name.human(count: 2), registry['Author'].label
  end

  test 'the icon comes from the structure' do
    assert_equal 'book', registry['Book'].icon
    assert_equal 'building', registry['Publisher'].icon
  end

  test 'a declared group wins over the namespace' do
    assert_equal 'Reporting', registry['AdminReadOnlyModel'].group
    assert_nil registry['Book'].group
  end

  test 'the scope narrows the base relation' do
    entry = registry['AdminScopedModel']

    assert_equal Book.where(active: true).to_sql, entry.scope.to_sql
  end

  test 'the scope defaults to everything' do
    assert_equal Author.all.to_sql, registry['Author'].scope.to_sql
  end

  test 'an admin fieldset is picked up when declared' do
    assert_equal :admin, registry['AdminScopedModel'].fieldset
    assert_nil registry['Book'].fieldset
  end

  # ── lookup and grouping ──────────────────────────────────────────────────
  test 'lookup works by class and by name' do
    assert_equal registry['Book'], registry[Book]
    assert registry.registered?(Book)
    assert_not registry.registered?('NoSuchModel')
  end

  test 'groups are ordered by the configured order, then alphabetically' do
    CrudComponents::Admin.configure do |config|
      config.only = %w[Book AdminReadOnlyModel]
      config.groups = %w[Reporting]
    end

    assert_equal ['Reporting', nil], registry.groups.map(&:first)
  end

  test 'reload! drops the resolved entries' do
    first = registry.entries

    assert_same first, registry.entries
    assert_not_same first, registry.reload!.entries
  end
end
