require 'test_helper'

# "Filter what you see" for a has_many column: the inline filter row matches the
# children's label — the names shown in the list — so an owner is kept when at
# least one of its children matches. Mirrors the belongs_to label filter; the
# guard is the target's label being a real column (a block label has nothing to
# match, see presence_filter_test).
class HasManyFilterTest < ActiveSupport::TestCase
  include CrudTestHelpers

  def setup
    @tor = Publisher.create!(name: 'Tor', slug: 'tor')
    @ace = Publisher.create!(name: 'Ace', slug: 'ace')
    @empty = Publisher.create!(name: 'Empty House', slug: 'empty')

    Book.create!(title: 'Dune', slug: 'dune', genre: :scifi, publisher: @tor)
    Book.create!(title: 'Dune Messiah', slug: 'dune-messiah', genre: :scifi, publisher: @tor)
    Book.create!(title: 'Foundation', slug: 'foundation', genre: :scifi, publisher: @ace)
  end

  def books_field = structure_of(Publisher).field(:books)

  def filtered(value)
    CrudComponents::Query.new(Publisher, { 'books' => value }, fieldset: :index).apply(Publisher.all)
  end

  test 'a has_many with a column-labelled target filters by that label as text' do
    assert books_field.filterable?
    assert_equal :text, books_field.filter_control
  end

  test 'keeps owners with a matching child, drops the rest' do
    assert_equal [@ace], filtered('Foundation').to_a
    assert_equal [@tor], filtered('messiah').to_a   # case-insensitive contains
    assert_empty filtered('Neuromancer').to_a
  end

  test 'an owner is returned once even when several children match' do
    assert_equal [@tor], filtered('Dune').to_a      # both Tor books match → DISTINCT
  end

  test 'a publisher with no books never matches a non-empty query' do
    refute_includes filtered('Dune').to_a, @empty
  end

  test 'a blank query is inert (the row is not filtered)' do
    assert_equal Publisher.count, filtered('').count
  end
end
