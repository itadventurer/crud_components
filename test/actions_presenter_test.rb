require 'test_helper'

# crud_actions takes a record (row actions) or a model class (collection
# actions). A relation is not a subject — collection actions are model-level,
# so the helper rejects a scope with a clear error.
class ActionsPresenterTest < ActiveSupport::TestCase
  def kind_for(subject)
    CrudComponents::Presenters::Actions.new(view: nil, subject: subject).kind
  end

  test 'a model class subject yields collection actions' do
    assert_equal :collection, kind_for(Book)
  end

  test 'a record subject yields row actions' do
    assert_equal :row, kind_for(Book.new)
  end

  test 'crud_actions rejects a relation with a helpful message' do
    view = Class.new do
      include CrudComponents::Helpers
    end.new

    error = assert_raises(ArgumentError) { view.crud_actions(Book.all) }
    assert_match(/not a relation/, error.message)
    assert_match(/Book/, error.message)
  end

  test 'derived action icons come from config.action_icons (overridable at render)' do
    edit = CrudComponents::Action.new(:edit, derived: true)
    assert_equal 'pencil', edit.icon                      # the shipped default

    icons = CrudComponents.config.action_icons.dup
    CrudComponents.config.action_icons[:edit] = 'pencil-fill'
    assert_equal 'pencil-fill', edit.icon                 # resolved against config, not frozen at build
  ensure
    CrudComponents.config.action_icons = icons
  end

  test 'an explicit icon: wins over config — including nil for no icon' do
    assert_equal 'star', CrudComponents::Action.new(:feature, icon: 'star').icon
    assert_nil CrudComponents::Action.new(:feature, icon: nil).icon  # explicitly none
    assert_nil CrudComponents::Action.new(:feature).icon             # custom action, no config entry
  end
end
