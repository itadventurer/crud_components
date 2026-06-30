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

  test 'delegation: association name alone searches the target label' do
    # :book reaches Book's label (title), the name shown in the cell — not its
    # other columns, and not a further hop into Book's own search_in.
    assert_equal [@review], apply(Review.all, [:book], 'hobbit').to_a
    assert_empty apply(Review.all, [:book], 'tor').to_a,
                 'label-only: the book\'s publisher is not reached through :book'
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

  test 'CrudComponents.where_like applies safe ILIKE to any relation (e.g. a subquery)' do
    found = CrudComponents.where_like(Book.where(slug: 'hobbit'), :title, 'hob').to_a
    assert_equal [@hobbit], found
    # composes onto a pre-scoped relation rather than replacing it
    assert_empty CrudComponents.where_like(Book.where(slug: 'dispossessed'), :title, 'hob').to_a
    # and escapes wildcards like the rest of the machinery
    assert_empty CrudComponents.where_like(Book.all, :title, '____').to_a
  end

  test 'a backslash is escaped as a literal, not a LIKE escape character' do
    winpath = Book.create!(title: 'C:\\Users', slug: 'winpath')
    assert_equal [winpath], apply(Book.all, :title, '\\').to_a
    assert_empty apply(Book.all, :title, '\\%').to_a   # backslash does not escape the %
  end

  test 'a joined match returns each row once' do
    le = Author.create!(name: 'Leann')
    li = Author.create!(name: 'Liam')
    book = Book.create!(title: 'Two Ls', slug: 'two-ls', authors: [le, li])
    found = apply(Book.all, { authors: :name }, 'l').to_a   # matches both authors
    assert_equal 1, found.count { |b| b == book }, 'row not duplicated by the join'
  end

  # The join (and the row multiplication it causes) is de-duplicated with an id
  # subquery, not SELECT DISTINCT — DISTINCT would compare every selected column
  # and blow up on a non-comparable one (e.g. a json column on the scope). So an
  # own-column spec is a plain WHERE, and a joined spec filters by an id IN (…).
  test 'a joined spec dedupes via an id subquery, not DISTINCT' do
    own = apply(Book.all, :title, 'x').to_sql
    refute_match(/DISTINCT/i, own)
    refute_match(/SELECT/i, own.sub(/\ASELECT/, ''))   # only the outer SELECT, no subquery

    joined = apply(Book.all, { publisher: :name }, 'x').to_sql
    refute_match(/DISTINCT/i, joined)
    assert_match(/"books"\."id" IN \(SELECT/i, joined)
  end

  # Regression for #28: a bare association delegates to the target's label
  # only, so a secret column on the target is never reached by free-text search.
  test 'delegation does not reach the target columns behind its label' do
    @hobbit.update!(internal_token: 'sekrit')
    assert_empty apply(Review.all, [:book], 'sekrit').to_a, 'token column not reachable through :book'
    assert_equal [@review], apply(Review.all, [:book], 'hobbit').to_a, 'the label (title) still matches'
  end
end
