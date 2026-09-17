# frozen_string_literal: true

require 'test_helper'

# A belongs_to filter is a value list: the targets occurring in the list (its
# base scope), never more than the ability may see, several at once, "not
# set" among them — and searchable on the same page when there are many.
class ValueFilterTest < ActiveSupport::TestCase
  NULL = CrudComponents::NULL_FILTER_VALUE

  def setup
    @tor = Publisher.create!(name: 'Tor Books', slug: 'tor-books')
    @ace = Publisher.create!(name: 'Ace', slug: 'ace')
    @orbit = Publisher.create!(name: 'Orbit', slug: 'orbit') # publishes nothing
    @tolkien = Author.create!(name: 'J. R. R. Tolkien', email: 'jrr@example.com')
    @hobbit = Book.create!(title: 'The Hobbit', slug: 'hobbit', publisher: @tor, authors: [@tolkien])
    @dispossessed = Book.create!(title: 'The Dispossessed', slug: 'dispossessed', publisher: @ace)
    @unpublished = Book.create!(title: 'Draft', slug: 'draft')
  end

  def query(params = {}, base: Book.all, **)
    CrudComponents::Query.new(Book, params, fieldset: :catalog, **).tap { |q| q.apply(base) }
  end

  def titles(params) = query(params).apply(Book.all).pluck(:slug).sort

  def publisher_field = structure_of(Book).field(:publisher)

  def book_model(&)
    model = define_model
    model.belongs_to :publisher, optional: true
    model.crud_structure(&)
    model
  end

  def with_block_label(model, block)
    original = model.instance_variable_get(:@_crud_structure_block)
    model.reset_crud_structure!
    model.crud_structure { label(&block) }
    yield
  ensure
    model.instance_variable_set(:@_crud_structure_block, original)
    model.instance_variable_set(:@_crud_structure, nil)
  end

  # ── several values, IN, and NULL ──────────────────────────────────────────
  test 'an array param filters by several identify_by values' do
    assert_equal %w[dispossessed hobbit], titles('publisher' => %w[tor-books ace])
    assert_equal %w[hobbit], titles('publisher' => ['tor-books', ''])
  end

  test 'an array matches exactly, not by label' do
    assert_empty titles('publisher' => %w[tor])
  end

  test '"not set" combines with values' do
    assert_equal %w[draft], titles('publisher' => [NULL])
    assert_equal %w[draft hobbit], titles('publisher' => [NULL, 'tor-books'])
  end

  test 'a single value still works, by identify_by or by label' do
    assert_equal %w[hobbit], titles('publisher' => 'tor-books')
    assert_equal %w[hobbit], titles('publisher' => 'tor')
    assert_equal %w[draft], titles('publisher' => NULL)
  end

  test 'arrays of blanks or non-strings apply no filter' do
    assert_equal 3, titles('publisher' => ['', '']).size
    assert_equal 3, titles('publisher' => [{ 'x' => 'y' }]).size
    assert_equal 3, titles('publisher' => { 'x' => 'tor-books' }).size
  end

  test 'fields that take one value ignore an array' do
    assert_equal 3, titles('title' => %w[hobbit]).size
    assert_equal 3, titles('genre' => %w[fiction]).size
  end

  test 'the query reports, keeps and permits the values' do
    q = query({ 'publisher' => ['tor-books', '', 'ace'], 'title' => %w[x] })

    assert_equal %w[tor-books ace], q.values('publisher')
    assert_equal %w[tor-books], query({ 'publisher' => 'tor-books' }).values('publisher')
    assert_equal({ 'publisher' => %w[tor-books ace] }, q.active_filters)
    assert_equal({ 'publisher' => %w[tor-books ace] }, q.filter_params)
    assert_equal({ 'publisher' => [] }, q.permitted_keys.last)
    assert_includes q.permitted_keys, 'publisher'

    permitted = ActionController::Parameters.new('publisher' => %w[a b], 'title' => %w[x])
                                            .permit(*q.permitted_keys)

    assert_equal({ 'publisher' => %w[a b] }, permitted.to_h)
  end

  test 'a nullable foreign key offers "not set"' do
    assert_predicate publisher_field, :filter_includes_null?
    assert_not CrudComponents::Fields::BelongsToField.new(:property_definition, PropertyValue).filter_includes_null?
  end

  # ── choices come from the base scope ──────────────────────────────────────
  test 'choices are the targets occurring in the list, not every target' do
    assert_equal [%w[Ace ace], ['Tor Books', 'tor-books']], publisher_field.filter_choices(query)
  end

  test 'a nested list offers only the targets of its own rows' do
    assert_equal [['Tor Books', 'tor-books']], publisher_field.filter_choices(query(base: @tolkien.books))
    assert_equal [%w[Ace ace]], publisher_field.filter_choices(query(base: Book.where(id: @dispossessed)))
  end

  test 'the field\'s own filter, search and sort do not shrink its choices' do
    q = query({ 'publisher' => %w[tor-books], 'q' => 'hobbit', 'sort' => 'title' })

    assert_equal 1, q.apply(Book.all).count
    assert_equal %w[ace tor-books], publisher_field.filter_choices(q).map(&:last)
  end

  test 'ordering and pagination of the base scope do not matter' do
    q = query(base: Book.order(:title).limit(1).offset(1))

    assert_equal %w[ace tor-books], publisher_field.filter_choices(q).map(&:last)
  end

  test 'the ability still limits the choices' do
    q = query(ability: CrudTestHelpers::ScopingAbility.new(@tor, @orbit))

    assert_equal [['Tor Books', 'tor-books']], publisher_field.filter_choices(q)
  end

  test 'a declared choices: callable narrows within the base scope' do
    model = book_model { attribute :publisher, choices: ->(scope) { scope.where.not(slug: 'ace') } }
    field = structure_of(model).field(:publisher)
    q = CrudComponents::Query.new(model, {}, base_scope: model.all)

    assert_equal [['Tor Books', 'tor-books']], field.filter_choices(q)
    assert_equal [[['Tor Books', 'tor-books']], 1], field.filter_values(q)
  end

  test 'a query that has seen no scope offers every target the ability may see' do
    q = CrudComponents::Query.new(Book, {}, fieldset: :catalog)

    assert_equal %w[ace orbit tor-books], publisher_field.filter_choices(q).map(&:last)
  end

  test 'a path column delegating to a scalar target is unaffected' do
    assert_equal :date_range, structure_of(Book).field(:'publisher.founded_on').filter_control
  end

  # ── the inline list and the search ────────────────────────────────────────
  test 'the page lists up to the inline limit, plus the selected values, with the total' do
    25.times do |i|
      Book.create!(title: "Book #{i}", slug: "book-#{i}",
                   publisher: Publisher.create!(name: format('Imprint %02d', i), slug: "imprint-#{i}"))
    end

    values, total = publisher_field.filter_values(query, selected: %w[imprint-24 tor-books], limit: 20)

    assert_equal 27, total
    assert_equal 22, values.size
    assert_equal ['Ace', 'Imprint 00'], values.first(2).map(&:first)
    assert_includes values, ['Imprint 24', 'imprint-24']
    assert_includes values, ['Tor Books', 'tor-books']
  end

  test 'selected values outside the choices are not listed' do
    values, = publisher_field.filter_values(query(base: @tolkien.books), selected: %w[ace orbit])

    assert_equal [['Tor Books', 'tor-books']], values
  end

  test 'a search matches the label and stays within the base scope' do
    assert_equal [[['Tor Books', 'tor-books']], 1], publisher_field.filter_values(query, term: 'o')
    assert_equal [[], 0], publisher_field.filter_values(query(base: @tolkien.books), term: 'ace')
  end

  test 'a search never names what the ability hides' do
    q = query(ability: CrudTestHelpers::ScopingAbility.new(@ace))

    assert_equal [[%w[Ace ace]], 1], publisher_field.filter_values(q)
    assert_equal [[], 0], publisher_field.filter_values(q, term: 'tor')
    assert_equal [[%w[Ace ace]], 1], publisher_field.filter_values(q, selected: %w[tor-books])
  end

  test 'a search escapes LIKE wildcards' do
    assert_equal [[], 0], publisher_field.filter_values(query, term: '%')
  end

  test 'a block label is matched in Ruby' do
    with_block_label(Publisher, ->(publisher) { "#{publisher.name} (#{publisher.slug})" }) do
      field = CrudComponents::Fields::BelongsToField.new(:publisher, Book)
      values, total = field.filter_values(query, term: 'TOR-')

      assert_equal ['Tor Books (tor-books)'], values.map(&:first)
      assert_equal 1, total
    end
  end

  # ── which requests may search ─────────────────────────────────────────────
  test 'a search request resolves only to a visible, filterable association' do
    name, field, term = query({ 'crud_choices' => 'publisher', 'crud_term' => 'to' }).choices_request

    assert_equal ['publisher', publisher_field, 'to'], [name, field, term]
    assert_nil query.choices_request
    assert_nil query({ 'crud_choices' => 'title' }).choices_request[1]          # not an association
    assert_nil query({ 'crud_choices' => 'internal_token' }).choices_request[1] # not in the fieldset
    assert_nil query({ 'crud_choices' => 'nope' }).choices_request[1]
    assert_nil query({ 'crud_choices' => %w[publisher] }).choices_request
  end

  test 'a hidden association answers no search request' do
    model = book_model { attribute :publisher, if: :manage }
    params = { 'crud_choices' => 'publisher' }

    denied = CrudComponents::Query.new(model, params, ability: CrudTestHelpers::DenyAll.new)
    allowed = CrudComponents::Query.new(model, params, ability: CrudTestHelpers::AllowAll.new)

    assert_nil denied.choices_request[1]
    assert_equal :publisher, allowed.choices_request[1].name
  end

  test 'an association with a filter block answers no search request and takes one value' do
    model = book_model do
      attribute(:publisher) { filter { |scope, value| scope.where(publisher_id: value) } }
    end
    field = structure_of(model).field(:publisher)

    assert_nil CrudComponents::Query.new(model, { 'crud_choices' => 'publisher' }).choices_request[1]
    assert_not field.multi_value_filter?
    assert_equal :text, field.filter_control
  end

  test 'the search params follow the param_prefix' do
    q = query({ 'books_crud_choices' => 'publisher', 'crud_choices' => 'nope' }, param_prefix: :books)

    assert_equal 'publisher', q.choices_request.first
  end
end

# The same, through the playground: a plain multiple select, and the page
# answers its own searches.
class ValueFilterIntegrationTest < ActionDispatch::IntegrationTest
  def setup
    @tor = Publisher.create!(name: 'Tor Books', slug: 'tor-books')
    @ace = Publisher.create!(name: 'Ace', slug: 'ace')
    @tolkien = Author.create!(name: 'J. R. R. Tolkien', email: 'jrr@example.com')
    @hobbit = Book.create!(title: 'The Hobbit', slug: 'hobbit', publisher: @tor, authors: [@tolkien])
    @silmarillion = Book.create!(title: 'The Silmarillion', slug: 'silmarillion', publisher: @tor)
    @dispossessed = Book.create!(title: 'The Dispossessed', slug: 'dispossessed', publisher: @ace)
    @draft = Book.create!(title: 'Draft', slug: 'draft')
    @original_limit = CrudComponents.config.value_filter_inline_limit
  end

  def teardown
    CrudComponents.config.value_filter_inline_limit = @original_limit
  end

  def filter_select = 'tr.crud-filter-row select[name="publisher[]"][multiple]'
  def control = 'tr.crud-filter-row div[data-controller="crud-value-filter"]'

  test 'the filter is a multiple select of the values in the list, "not set" first' do
    get books_path

    assert_select "#{filter_select} option", count: 3
    assert_select "#{filter_select} option:first-child[value=?]", CrudComponents::NULL_FILTER_VALUE, text: '(empty)'
    assert_select control do |(div)|
      assert_equal 'publisher', div['data-crud-value-filter-field-value']
      assert_equal 'crud_choices', div['data-crud-value-filter-choices-param-value']
      assert_equal 'crud_filter_books', div['data-crud-value-filter-source-value']
      assert_equal '3', div['data-crud-value-filter-total-value']
      assert_equal 'false', div['data-crud-value-filter-remote-value']
      assert_equal '/books', div['data-crud-value-filter-url-value']
    end
  end

  test 'a nested index offers only its own publishers' do
    get author_books_path(@tolkien)

    assert_select "#{filter_select} option", text: 'Tor Books'
    assert_select "#{filter_select} option", text: 'Ace', count: 0
  end

  test 'several values and "not set" filter together and stay selected' do
    get books_path(publisher: ['ace', CrudComponents::NULL_FILTER_VALUE])

    assert_select 'td', text: 'The Hobbit', count: 0
    assert_select 'td', text: 'The Dispossessed'
    assert_select 'td', text: 'Draft'
    assert_select "#{filter_select} option[selected]", count: 2
    assert_select "#{filter_select} option:not([selected])", text: 'Tor Books'
  end

  test 'an old single-value link still filters and selects' do
    get books_path(publisher: 'tor-books')

    assert_select 'td', text: 'The Dispossessed', count: 0
    assert_select "#{filter_select} option[selected]", text: 'Tor Books'
  end

  test 'a hand-built query with a pager takes the values too' do
    get pagination_path(publisher: %w[tor-books ace])

    assert_response :success
    assert_select 'td', text: 'Draft', count: 0
    assert_select 'td', text: 'The Hobbit'
  end

  test 'above the inline limit the page lists the first values plus the selected ones' do
    CrudComponents.config.value_filter_inline_limit = 1
    get books_path(publisher: %w[tor-books])

    assert_select "#{filter_select} option", count: 3 # (empty), Ace, Tor Books (selected)
    assert_select control do |(div)|
      assert_equal 'true', div['data-crud-value-filter-remote-value']
      assert_equal '3', div['data-crud-value-filter-total-value']
    end
  end

  test 'the page answers a search request with the matches only' do
    get books_path(crud_choices: 'publisher', crud_term: 'tor')

    assert_response :success
    assert_select 'table', count: 0
    assert_select 'ul[data-crud-choices="publisher"][data-crud-choices-source="crud_filter_books"]' do |(list)|
      assert_equal '1', list['data-crud-choices-total']
      assert_select 'li', count: 1
      assert_select 'li[data-value="tor-books"]', text: 'Tor Books'
    end
  end

  test 'a search answer stops at the inline limit and reports the total' do
    CrudComponents.config.value_filter_inline_limit = 1
    get books_path(crud_choices: 'publisher', crud_term: '')

    assert_select 'ul[data-crud-choices-source="crud_filter_books"][data-crud-choices-total="2"] li', count: 1
  end

  test 'a search for a nested index stays inside it' do
    get author_books_path(@tolkien, crud_choices: 'publisher', crud_term: '')

    assert_select 'ul[data-crud-choices="publisher"][data-crud-choices-source="crud_filter_books"] li', count: 1
    assert_select 'ul[data-crud-choices="publisher"][data-crud-choices-source="filter"] li', count: 1
    assert_select 'li[data-value="ace"]', count: 0
  end

  test 'the standalone filter form answers too, narrowed by the scope it is given' do
    get publisher_books_path(@ace, crud_choices: 'publisher')

    assert_select 'ul[data-crud-choices="publisher"][data-crud-choices-source="filter"] li[data-value="ace"]'
    assert_select 'ul[data-crud-choices="publisher"] li[data-value="tor-books"]', count: 0
  end

  test 'a field that is not searchable gets an empty answer' do
    %w[title purchase_price reviews nope].each do |name|
      get books_path(crud_choices: name, crud_term: 'o')

      assert_select "ul[data-crud-choices=\"#{name}\"] li", count: 0
      assert_select 'table', count: 0
    end
  end

  test 'a prefixed collection answers only its own search requests' do
    get dashboard_path(books_crud_choices: 'publisher')

    assert_select 'ul[data-crud-choices="books_publisher"] li', count: 2
    assert_select 'ul[data-crud-choices]', count: 1 # the reviews collection renders its table
    assert_select 'table', count: 1
  end

  test 'the admin, which loads no Stimulus, gets the same multiple select and filters by it' do
    post '/toggle_admin'
    get '/admin/books', params: { publisher: %w[ace] }

    assert_response :success
    assert_select 'select[name="publisher[]"][multiple] option[selected]', text: 'Ace'
    assert_select 'td', text: 'The Dispossessed'
    assert_select 'td', text: 'The Hobbit', count: 0
  end

  test 'the playground serves the shipped value filter controller' do
    get stimulus_controller_path('crud_value_filter_controller')

    assert_response :success
    assert_match(/aria-haspopup/, response.body)
    get stimulus_controller_path('initializer')

    assert_response :not_found
  end
end
