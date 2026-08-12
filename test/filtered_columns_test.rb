require_relative 'test_helper'

# Columns the application already keeps out of its logs are never printed,
# never reach SQL and never reach a form.
class FilteredColumnsTest < ActiveSupport::TestCase
  def setup
    @book = Book.create!(title: 'The Hobbit', slug: 'hobbit', active: true,
                         internal_token: 'tok-visible', distributor_secret: 's3cret')
  end

  def teardown
    CrudComponents.config.filtered_columns = nil
    rebuild_structure(Book)
  end

  def field(name) = structure_of(Book).field(name)

  # ── which columns count ──────────────────────────────────────────────────
  test 'a column matching the list is filtered' do
    assert field(:distributor_secret).filtered?
  end

  test 'an ordinary column is not' do
    assert_not field(:title).filtered?
    assert_not field(:price).filtered?
  end

  test 'an email column is not filtered, whatever Rails does with its logs' do
    assert_not structure_of(Author).field(:email).filtered?
  end

  test 'filtered: false opts a matching column out' do
    assert_not field(:internal_token).filtered?
  end

  test 'filtered: true opts a non-matching column in' do
    model = define_model { attribute :subtitle, filtered: true }

    assert structure_of(model).field(:subtitle).filtered?
  end

  test 'an empty list switches the whole rule off' do
    CrudComponents.config.filtered_columns = []
    rebuild_structure(Book)

    assert_not structure_of(Book).field(:distributor_secret).filtered?
  end

  # ── what it does ─────────────────────────────────────────────────────────
  test 'a filtered column is neither filterable nor sortable' do
    assert_not field(:distributor_secret).filterable?
    assert_not field(:distributor_secret).sortable?
  end

  test 'a filtered column never reaches the query' do
    query = CrudComponents::Query.new(Book, { 'distributor_secret' => 's3cret' })

    assert_not_includes query.apply(Book.all).to_sql, 's3cret'
  end

  test 'a filtered column is not editable and not in the permit list' do
    assert_not field(:distributor_secret).editable?
    assert_not_includes CrudComponents.permitted_attributes(Book, ability: CrudTestHelpers::AllowAll.new),
                        :distributor_secret
  end

  test 'a filtered column is dropped from the search spec' do
    model = define_model(name: 'SearchableSecretBook') { search_in :title, :distributor_secret }
    spec = structure_of(model).permitted_search_spec(CrudComponents::PermissionContext.new(nil))

    assert_equal %i[title], spec
  end
end
