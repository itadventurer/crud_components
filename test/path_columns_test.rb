require 'test_helper'

# Path columns: a dotted field name (publisher.name, authors.email) that reaches
# through associations. Single-valued (belongs_to/has_one) vs list (has_many/habtm),
# the two structural limits, and end-to-end through the picker page.
class PathColumnsTest < ActiveSupport::TestCase
  def field(path, model = Book) = CrudComponents::Fields::PathField.new(path.to_sym, model)

  setup do
    @pub = Publisher.create!(name: 'Tor', slug: 'tor-path', founded_on: Date.new(1980, 1, 1))
    @ann = Author.create!(name: 'Ann', email: 'ann@x.com')
    @bo  = Author.create!(name: 'Bo',  email: 'bo@y.com')
    @book = Book.create!(title: 'P', slug: 'path-book', price: 1, publisher: @pub, authors: [@ann, @bo])
  end

  test 'a single-valued path renders the target attribute, type-aware and sortable' do
    name = field('publisher.name')
    assert_not name.collection?
    assert_equal 'Tor', name.value(@book)
    assert name.sortable?
    assert_equal [:publisher], name.eager_load
    assert_equal :date, field('publisher.founded_on').renderer(@book)   # date target → date renderer
  end

  test 'a to-many path resolves to a list, renders joined, filters but does not sort by default' do
    mail = field('authors.email')
    assert mail.collection?
    assert_equal %w[ann@x.com bo@y.com], mail.value(@book)
    assert_equal 'ann@x.com, bo@y.com', mail.list_text(@book)
    assert_not mail.sortable?            # no single value to order by
    assert mail.filterable?
    assert_equal [:authors], mail.eager_load
  end

  test 'a path filters through the association via the safe like-spec' do
    assert_includes field('authors.email').apply_filter(Book.all, exact: 'ann@'), @book
    assert_not_includes field('authors.email').apply_filter(Book.all, exact: 'nobody@'), @book
  end

  test 'habtm → one is allowed (one to-many hop, then to-one)' do
    # Reaching a single value off each member of a collection is fine.
    assert_nothing_raised { field('reviews.book_id', Book) } if Book.reflect_on_association(:reviews)
  end

  # ── the two limits ───────────────────────────────────────────────────────────
  test 'an invalid path segment raises a helpful error' do
    err = assert_raises(CrudComponents::DefinitionError) { field('title.foo') }
    assert_match(/not an association/, err.message)
  end

  test 'crossing more than one to-many association is rejected' do
    err = assert_raises(CrudComponents::DefinitionError) { field('books.authors.name', Publisher) }
    assert_match(/to-many/, err.message)
  end

  test 'a path deeper than config.max_path_depth is rejected' do
    original = CrudComponents.config.max_path_depth
    CrudComponents.config.max_path_depth = 0
    err = assert_raises(CrudComponents::DefinitionError) { field('publisher.name') }
    assert_match(/max_path_depth/, err.message)
  ensure
    CrudComponents.config.max_path_depth = original
  end

  test 'Structure resolves a dotted name to a PathField, usable in a fieldset' do
    assert_instance_of CrudComponents::Fields::PathField, structure_of(Book).field(:"authors.email")
  end
end

class PathColumnsIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @pub = Publisher.create!(name: 'Tor', slug: 'tor-pi', founded_on: Date.new(1980, 1, 1))
    @ann = Author.create!(name: 'Ann', email: 'ann@example.com')
    @book = Book.create!(title: 'Alpha', slug: 'pi-alpha', price: 1, publisher: @pub, authors: [@ann])
  end

  test 'the picker page renders path columns and their values' do
    get '/columns'
    assert_response :success
    assert_select 'th', text: /Authors · Email/        # path-column header
    assert_select 'td', text: /ann@example.com/        # the list value
    assert_select 'td', text: /1980/                   # publisher.founded_on (a date)
  end

  test 'a path column is pickable like any other via ?cols=' do
    get '/columns', params: { cols: ['title', 'authors.email'] }
    assert_select 'td', text: /ann@example.com/
    assert_select 'thead th a', { text: /Genre/, count: 0 }   # narrowed away
  end
end
