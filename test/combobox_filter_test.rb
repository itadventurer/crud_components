# frozen_string_literal: true

require 'test_helper'

# A belongs_to filter offers the targets occurring in the list (its base
# scope), never more than the ability may see, and switches to a combobox
# with suggestions from the same page once there are many of them.
class ComboboxFilterTest < ActiveSupport::TestCase
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

  def with_config(**values)
    originals = values.keys.index_with { |key| CrudComponents.config.public_send(key) }
    values.each { |key, value| CrudComponents.config.public_send(:"#{key}=", value) }
    yield
  ensure
    originals.each { |key, value| CrudComponents.config.public_send(:"#{key}=", value) }
  end

  # ── choices come from the base scope ──────────────────────────────────────
  test 'choices are the targets occurring in the list, not every target' do
    assert_equal [['Ace', 'ace'], ['Tor Books', 'tor-books']], publisher_field.filter_choices(query)
  end

  test 'a nested list offers only the targets of its own rows' do
    assert_equal [['Tor Books', 'tor-books']], publisher_field.filter_choices(query(base: @tolkien.books))
    assert_equal [%w[Ace ace]], publisher_field.filter_choices(query(base: Book.where(id: @dispossessed)))
  end

  test 'the field\'s own filter, search and sort do not shrink its choices' do
    q = query({ 'publisher' => 'tor-books', 'q' => 'hobbit', 'sort' => 'title' })

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
    assert_equal :select, field.filter_control(q)
  end

  test 'a query that has seen no scope offers every target the ability may see' do
    q = CrudComponents::Query.new(Book, {}, fieldset: :catalog)

    assert_equal %w[ace orbit tor-books], publisher_field.filter_choices(q).map(&:last)
  end

  # ── select or combobox ────────────────────────────────────────────────────
  test 'the control is a select up to combobox_threshold choices, a combobox above' do
    with_config(combobox_threshold: 1) do
      assert_equal :combobox, publisher_field.filter_control(query)
      assert_equal :select, publisher_field.filter_control(query(base: @tolkien.books))
    end
    with_config(combobox_threshold: 2) do
      assert_equal :select, publisher_field.filter_control(query)
    end
  end

  test 'the threshold counts only what the ability may see' do
    with_config(combobox_threshold: 1) do
      assert_equal :select, publisher_field.filter_control(query(ability: CrudTestHelpers::ScopingAbility.new(@tor)))
    end
  end

  test 'a path column delegating to a scalar target is unaffected' do
    founded = structure_of(Book).field(:'publisher.founded_on')

    assert_equal :date_range, founded.filter_control(query)
  end

  # ── suggestions ───────────────────────────────────────────────────────────
  test 'suggestions match the label and stay within the base scope' do
    assert_equal [['Tor Books', 'tor-books']], publisher_field.filter_suggestions(query, 'o')
    assert_equal [['Ace', 'ace'], ['Tor Books', 'tor-books']], publisher_field.filter_suggestions(query, '')
    assert_empty publisher_field.filter_suggestions(query(base: @tolkien.books), 'ace')
  end

  test 'suggestions never name what the ability hides' do
    q = query(ability: CrudTestHelpers::ScopingAbility.new(@ace))

    assert_equal [%w[Ace ace]], publisher_field.filter_suggestions(q, '')
    assert_empty publisher_field.filter_suggestions(q, 'tor')
  end

  test 'suggestions stop at combobox_suggestions' do
    25.times do |i|
      Book.create!(title: "Book #{i}", slug: "book-#{i}",
                   publisher: Publisher.create!(name: format('Imprint %02d', i), slug: "imprint-#{i}"))
    end

    with_config(combobox_suggestions: 20) do
      found = publisher_field.filter_suggestions(query, 'imprint')

      assert_equal 20, found.size
      assert_equal 'Imprint 00', found.first.first
    end
  end

  test 'suggestions escape LIKE wildcards' do
    assert_empty publisher_field.filter_suggestions(query, '%')
  end

  test 'a block label is matched in Ruby' do
    with_block_label(Publisher, ->(publisher) { "#{publisher.name} (#{publisher.slug})" }) do
      field = CrudComponents::Fields::BelongsToField.new(:publisher, Book)

      assert_equal ['Tor Books (tor-books)'], field.filter_suggestions(query, 'TOR-').map(&:first)
    end
  end

  test 'the current value is shown by its label, if it is one of the choices' do
    assert_equal 'Tor Books', publisher_field.filter_value_label(query, 'tor-books')
    assert_nil publisher_field.filter_value_label(query, 'orbit')
    assert_nil publisher_field.filter_value_label(query, 'tor')
    assert_nil publisher_field.filter_value_label(query(ability: CrudTestHelpers::ScopingAbility.new(@ace)),
                                                  'tor-books')
  end

  # ── which requests may ask ────────────────────────────────────────────────
  test 'a suggestion request resolves only to a visible, filterable association' do
    name, field, term = query({ 'crud_choices' => 'publisher', 'crud_term' => 'to' }).choices_request

    assert_equal ['publisher', publisher_field, 'to'], [name, field, term]
    assert_nil query.choices_request
    assert_nil query({ 'crud_choices' => 'title' }).choices_request[1] # not an association
    assert_nil query({ 'crud_choices' => 'internal_token' }).choices_request[1] # not in the fieldset
    assert_nil query({ 'crud_choices' => 'nope' }).choices_request[1]
    assert_nil query({ 'crud_choices' => %w[publisher] }).choices_request
  end

  test 'a hidden association answers no suggestion request' do
    model = book_model { attribute :publisher, if: :manage }
    params = { 'crud_choices' => 'publisher' }

    denied = CrudComponents::Query.new(model, params, ability: CrudTestHelpers::DenyAll.new)
    allowed = CrudComponents::Query.new(model, params, ability: CrudTestHelpers::AllowAll.new)

    assert_nil denied.choices_request[1]
    assert_equal :publisher, allowed.choices_request[1].name
  end

  test 'an association with a filter block answers no suggestion request' do
    model = book_model do
      attribute(:publisher) { filter { |scope, value| scope.where(publisher_id: value) } }
    end

    assert_nil CrudComponents::Query.new(model, { 'crud_choices' => 'publisher' }).choices_request[1]
  end

  test 'the suggestion params follow the param_prefix' do
    q = query({ 'books_crud_choices' => 'publisher', 'crud_choices' => 'nope' }, param_prefix: :books)

    assert_equal 'publisher', q.choices_request.first
  end
end

# The same, through the playground: the page answers its own combobox.
class ComboboxFilterIntegrationTest < ActionDispatch::IntegrationTest
  def setup
    @tor = Publisher.create!(name: 'Tor Books', slug: 'tor-books')
    @ace = Publisher.create!(name: 'Ace', slug: 'ace')
    @tolkien = Author.create!(name: 'J. R. R. Tolkien', email: 'jrr@example.com')
    @hobbit = Book.create!(title: 'The Hobbit', slug: 'hobbit', publisher: @tor, authors: [@tolkien])
    @silmarillion = Book.create!(title: 'The Silmarillion', slug: 'silmarillion', publisher: @tor)
    @dispossessed = Book.create!(title: 'The Dispossessed', slug: 'dispossessed', publisher: @ace)
    @original = CrudComponents.config.combobox_threshold
  end

  def teardown
    CrudComponents.config.combobox_threshold = @original
  end

  def filter_select = 'tr.crud-filter-row select[name="publisher"]'

  test 'a nested index offers only its own publishers' do
    get author_books_path(@tolkien)

    assert_select "#{filter_select} option", text: 'Tor Books'
    assert_select "#{filter_select} option", text: 'Ace', count: 0
  end

  test 'filtering by a publisher keeps the other one on offer' do
    get books_path(publisher: 'ace')

    assert_select 'td', text: 'The Hobbit', count: 0
    assert_select "#{filter_select} option", text: 'Tor Books'
    assert_select "#{filter_select} option[selected]", text: 'Ace'
  end

  test 'above the threshold the filter is a combobox, a plain text input underneath' do
    CrudComponents.config.combobox_threshold = 1
    get books_path(publisher: 'tor-books')

    assert_select filter_select, count: 0
    assert_select 'tr.crud-filter-row div[data-controller="crud-combobox"]' do |(combobox)|
      assert_equal 'crud_choices', combobox['data-crud-combobox-choices-param-value']
      assert_equal 'publisher', combobox['data-crud-combobox-field-value']
      assert_equal 'Tor Books', combobox['data-crud-combobox-label-value']
      assert_equal 'crud_filter_books', combobox['data-crud-combobox-source-value']
      assert_equal '/books?publisher=tor-books', combobox['data-crud-combobox-url-value']
      assert_select 'input[type="search"][name="publisher"][value="tor-books"]'
      assert_select 'ul[role="listbox"][hidden]'
    end
  end

  test 'the page answers a suggestion request with the matches only' do
    get books_path(crud_choices: 'publisher', crud_term: 'tor')

    assert_response :success
    assert_select 'table', count: 0
    assert_select 'ul[data-crud-choices="publisher"][data-crud-choices-source="crud_filter_books"] li', count: 1 do
      assert_select 'li[data-value="tor-books"]', text: 'Tor Books'
    end
  end

  test 'suggestions for a nested index stay inside it' do
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

  test 'a field that offers no suggestions gets an empty answer' do
    %w[title purchase_price reviews nope].each do |name|
      get books_path(crud_choices: name, crud_term: 'o')

      assert_select "ul[data-crud-choices=\"#{name}\"] li", count: 0
      assert_select 'table', count: 0
    end
  end

  test 'a prefixed collection answers only its own suggestion requests' do
    get dashboard_path(books_crud_choices: 'publisher')

    assert_select 'ul[data-crud-choices="books_publisher"] li', count: 2
    assert_select 'ul[data-crud-choices]', count: 1 # the reviews collection renders its table
    assert_select 'table', count: 1
  end

  test 'the playground serves the shipped combobox controller' do
    get stimulus_controller_path('crud_combobox_controller')

    assert_response :success
    assert_match(/aria-activedescendant/, response.body)
    get stimulus_controller_path('initializer')

    assert_response :not_found
  end
end
