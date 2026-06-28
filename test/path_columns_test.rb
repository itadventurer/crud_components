require 'test_helper'

# Path columns: a dotted field name (publisher.name, authors.email) that reaches
# through associations. Single-valued (belongs_to/has_one) vs list (has_many/habtm),
# the two structural limits, and end-to-end through the picker page.
class PathColumnsTest < ActiveSupport::TestCase
  def field(path, model = Book) = CrudComponents::Fields::PathField.new(path.to_sym, model)
  def view = @view ||= ActionView::Base.empty

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

  # ── delegation to the target model's field (override > target > default) ──────
  test 'a single-valued path inherits the target field renderer AND its options' do
    price = CrudComponents::Fields::PathField.new(:'book.price', Review)
    assert_equal :number, price.renderer            # Book.price is `as: :number`
    assert_equal '€', price.renderer_options[:unit] # …with unit/digits carried through
    assert_equal 2, price.renderer_options[:digits]
  end

  test 'the path column overrides the target — as: and own options win' do
    forced = CrudComponents::Fields::PathField.new(:'book.price', Review, { as: :string })
    assert_equal :string, forced.renderer           # as: beats the target's :number

    own = CrudComponents::Fields::PathField.new(:'book.price', Review, { unit: '$' })
    assert_equal :number, own.renderer
    assert_equal '$', own.renderer_options[:unit]    # own option overrides the target's '€'
    assert_equal 2, own.renderer_options[:digits]    # …while inheriting the rest
  end

  test 'a single-valued scalar path delegates the filter control to the target field' do
    assert_equal :date_range, field('publisher.founded_on').filter_control
    genre = CrudComponents::Fields::PathField.new(:'book.genre', Review)
    assert_equal :select, genre.filter_control       # enum target → select
    assert_includes genre.filter_choices.map(&:last), 'scifi'
    assert_equal 'Scifi', genre.human_value('scifi') # humanized like the Book table
  end

  test 'a non-scalar / collection path keeps contains-match (no delegation)' do
    assert_equal :text, field('authors.email').filter_control   # habtm list → text
    assert_nil field('authors.email').filter_choices
  end

  test 'a delegated date path filters as a range through the association' do
    in_range  = field('publisher.founded_on').apply_filter(Book.all, geq: '1979-01-01', leq: '1981-12-31')
    out_range = field('publisher.founded_on').apply_filter(Book.all, geq: '1990-01-01')
    assert_includes in_range, @book
    assert_not_includes out_range, @book
  end

  test 'a path to the target label field renders a link (block), not a plain cell' do
    name = field('publisher.name')
    assert name.send(:link_to_target?)
    assert_kind_of Proc, name.render_block      # the label-link renderer
    assert_nil name.renderer                    # …so the cell renders via the block
    # founded_on is not the label field — a plain delegated cell
    assert_not field('publisher.founded_on').send(:link_to_target?)
  end

  test 'a to-many path resolves to a list, renders joined, filters but does not sort by default' do
    mail = field('authors.email')
    assert mail.collection?
    assert_equal %w[ann@x.com bo@y.com], mail.value(@book)
    assert_equal 'Ann, Bo', field('authors.name').render_list(view, @book)   # plain join
    assert_not mail.sortable?            # no single value to order by
    assert mail.filterable?
    assert_equal [:authors], mail.eager_load
  end

  test 'a to-many path of emails renders each as a mailto link' do
    html = field('authors.email').render_list(view, @book)
    assert_includes html, 'href="mailto:ann@x.com"'
    assert_includes html, '>bo@y.com</a>'
  end

  test 'path columns group under their association; the header is a breadcrumb' do
    mail = field('authors.email')
    assert_equal 'Authors', mail.group_label       # picker heading
    assert_equal 'Email', mail.picker_label        # label within the group
    assert_equal 'Authors › Email', mail.human_name # table header (breadcrumb)
  end

  test 'a path filters through the association via the safe like-spec' do
    assert_includes field('authors.email').apply_filter(Book.all, value: 'ann@'), @book
    assert_not_includes field('authors.email').apply_filter(Book.all, value: 'nobody@'), @book
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
    assert_select 'th', text: /Authors.*Email/         # path-column header (breadcrumb)
    assert_select 'td', text: /ann@example.com/        # the list value
    assert_select 'td', text: /1980/                   # publisher.founded_on (a date)
  end

  test 'a path column is pickable like any other via ?cols=' do
    get '/columns', params: { cols: ['title', 'authors.email'] }
    assert_select 'td', text: /ann@example.com/
    assert_select 'thead th a', { text: /Genre/, count: 0 }   # narrowed away
  end

  test 'the picker groups every column by its source model (Pipedrive-style)' do
    get '/columns'
    # group headers are model names — own columns under Book, path/association
    # columns under the model they reach (Publisher, Author)
    assert_select 'li.crud-column-picker-group', text: /Book/
    assert_select 'li.crud-column-picker-group', text: /Publisher/
    assert_select 'li.crud-column-picker-group', text: /Author/
    # the Publisher group header carries the model icon
    assert_select 'li.crud-column-picker-group i.bi-building'
    # each row also tags its model on the right
    assert_select 'span.crud-column-picker-model', text: 'Publisher'
  end

  test 'a path to the target label field renders an icon + link to the record' do
    get '/columns'
    assert_response :success
    # publisher.name → a link to the publisher's show, badged with its model icon
    assert_select "td a[href=?]", publisher_path(@pub) do
      assert_select 'i.bi-building'   # Publisher declares icon 'building'
      assert_select 'span', text: 'Tor'
    end
  end
end
