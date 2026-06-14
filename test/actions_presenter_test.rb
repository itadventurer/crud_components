require 'test_helper'

# crud_actions accepts a relation (or model class) for collection actions and a
# record for row actions — mirroring crud_collection, which takes a relation so
# your authorization applies before the gem renders.
class ActionsPresenterTest < ActiveSupport::TestCase
  def kind_for(subject)
    CrudComponents::Presenters::Actions.new(view: nil, subject: subject).kind
  end

  test 'a relation subject yields collection actions' do
    assert_equal :collection, kind_for(Book.all)
    assert_equal :collection, kind_for(Book.where(active: true))
  end

  test 'a model class subject yields collection actions' do
    assert_equal :collection, kind_for(Book)
  end

  test 'a record subject yields row actions' do
    assert_equal :row, kind_for(Book.new)
  end
end
