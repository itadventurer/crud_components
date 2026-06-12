require 'test_helper'

class LikeSpecTest < ActiveSupport::TestCase
  def setup
    @tor = Publisher.create!(name: 'Tor Books', slug: 'tor-books')
    @ace = Publisher.create!(name: 'Ace', slug: 'ace')
    @dispossessed = Book.create!(title: 'The Dispossessed', slug: 'dispossessed', publisher: @ace)
    @hobbit = Book.create!(title: 'The Hobbit', subtitle: 'There and Back Again', slug: 'hobbit', publisher: @tor)
    @review = Review.create!(book: @hobbit, reviewer_name: 'Ada', body: 'A classic.', rating: 5)
  end

  def apply(scope, spec, value)
    CrudComponents::LikeSpec.apply(scope, spec, value)
  end

  test 'own column, case-insensitive contains' do
    assert_equal [@hobbit], apply(Book.all, :title, 'hobbit').to_a
  end

  test 'several own columns OR-combined' do
    assert_equal [@hobbit], apply(Book.all, %i[title subtitle], 'back again').to_a
  end

  test 'joined association with explicit columns' do
    assert_equal [@hobbit], apply(Book.all, { publisher: :name }, 'tor').to_a
  end

  test 'delegation: association name alone uses the target search_in' do
    # Review's spec includes :book; Book's spec includes :publisher (nested delegation)
    assert_equal [@review], apply(Review.all, [:book], 'hobbit').to_a
    assert_equal [@review], apply(Review.all, [:book], 'tor').to_a, 'two delegation hops'
  end

  test 'mixed spec' do
    found = apply(Book.all, [:title, { publisher: :name }], 'ace').to_a
    assert_equal [@dispossessed], found
  end

  test 'LIKE wildcards in the value are escaped' do
    with_percent = Book.create!(title: '100% Ruby', slug: 'percent')
    assert_equal [with_percent], apply(Book.all, :title, '%').to_a
    assert_empty apply(Book.all, :title, '_____________________________').to_a
  end

  test 'where_like is available on scopes handed to blocks' do
    scope = Book.all.extending(CrudComponents::WhereLike)
    assert_equal [@hobbit], scope.where_like({ publisher: :name }, 'tor').to_a
  end
end
