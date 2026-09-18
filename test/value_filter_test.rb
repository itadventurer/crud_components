# frozen_string_literal: true

require 'test_helper'

# A belongs_to filter is a value list: the targets occurring in the list (its
# base scope), never more than the ability may see, several at once, with
# "not set" among them.
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
    assert_equal :values, field.filter_control(q)
  end

  test 'a query that has seen no scope offers every target the ability may see' do
    q = CrudComponents::Query.new(Book, {}, fieldset: :catalog)

    assert_equal %w[ace orbit tor-books], publisher_field.filter_choices(q).map(&:last)
  end

  test 'a path column delegating to a scalar target is unaffected' do
    assert_equal :date_range, structure_of(Book).field(:'publisher.founded_on').filter_control
  end

  # ── how many values the filter offers ────────────────────────────────────
  test 'beyond select_limit values the filter is the plain text filter' do
    original = CrudComponents.config.select_limit
    CrudComponents.config.select_limit = 2

    assert_equal :values, publisher_field.filter_control(query)
    CrudComponents.config.select_limit = 1

    assert_equal :text, publisher_field.filter_control(query)
    assert_equal :values, publisher_field.filter_control(query(base: @tolkien.books))
  ensure
    CrudComponents.config.select_limit = original
  end

  test 'the threshold counts the choices, not the targets' do
    original = CrudComponents.config.select_limit
    CrudComponents.config.select_limit = 2

    assert_equal :values, publisher_field.filter_control(query) # 2 of 3 publishers occur
    Book.create!(title: 'Elsewhere', slug: 'elsewhere', publisher: @orbit)

    assert_equal :text, publisher_field.filter_control(query)
  ensure
    CrudComponents.config.select_limit = original
  end

  # ── which fields take several values ──────────────────────────────────────
  test 'a hidden or non-association field takes no value list' do
    assert_not structure_of(Book).field(:title).multi_value_filter?
    assert_not structure_of(Book).field(:genre).multi_value_filter?
  end

  test 'an association with a filter block takes one value' do
    model = book_model do
      attribute(:publisher) { filter { |scope, value| scope.where(publisher_id: value) } }
    end
    field = structure_of(model).field(:publisher)

    assert_not field.multi_value_filter?
    assert_equal :text, field.filter_control
  end
end

# The same, through the playground: a plain multiple select.
class ValueFilterIntegrationTest < ActionDispatch::IntegrationTest
  def setup
    @original_limit = CrudComponents.config.select_limit
    @tor = Publisher.create!(name: 'Tor Books', slug: 'tor-books')
    @ace = Publisher.create!(name: 'Ace', slug: 'ace')
    @tolkien = Author.create!(name: 'J. R. R. Tolkien', email: 'jrr@example.com')
    @hobbit = Book.create!(title: 'The Hobbit', slug: 'hobbit', publisher: @tor, authors: [@tolkien])
    @silmarillion = Book.create!(title: 'The Silmarillion', slug: 'silmarillion', publisher: @tor)
    @dispossessed = Book.create!(title: 'The Dispossessed', slug: 'dispossessed', publisher: @ace)
    @draft = Book.create!(title: 'Draft', slug: 'draft')
  end

  def teardown
    CrudComponents.config.select_limit = @original_limit
  end

  def filter_select = 'tr.crud-filter-row select[name="publisher[]"][multiple]'
  def control = 'tr.crud-filter-row div[data-controller="crud-value-filter"]'

  test 'the filter is a multiple select of the values in the list, "not set" first' do
    get books_path

    assert_select "#{filter_select} option", count: 3
    assert_select "#{filter_select} option:first-child[value=?]", CrudComponents::NULL_FILTER_VALUE, text: '(empty)'
    assert_select control do |(div)|
      assert_equal 'Publisher', div['data-crud-value-filter-label-value']
      assert_equal 'true', div['data-crud-value-filter-autosubmit-value']
      assert_equal 'All', JSON.parse(div['data-crud-value-filter-texts-value'])['all']
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

  test 'beyond the threshold the filter row falls back to the text filter' do
    CrudComponents.config.select_limit = 1
    get books_path

    assert_select filter_select, count: 0
    assert_select control, count: 0
    assert_select 'tr.crud-filter-row input[type="search"][name="publisher"]'
  end

  test 'a prefixed collection filters by its own values' do
    get dashboard_path(books_publisher: %w[ace])

    assert_select 'select[name="books_publisher[]"][multiple] option[selected]', text: 'Ace'
    assert_select 'td', text: 'The Hobbit', count: 0
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
