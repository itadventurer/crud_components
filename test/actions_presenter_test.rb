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
end
