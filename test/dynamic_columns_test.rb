require 'test_helper'

# Dynamic columns (CrudComponents::DynamicColumn / Fields::DynamicField) and the
# per-user column picker. Unit specs drive the field + the Collection presenter
# directly; the integration class drives the dummy app's /custom_fields and
# /columns pages exactly the way a no-JS browser would.
class DynamicColumnsTest < ActiveSupport::TestCase
  # A minimal can?-shaped view with request params, enough to build a Collection
  # without ActionView (we only assert on field selection, not rendered HTML).
  def view(params: {}, admin: true)
    request = Struct.new(:query_parameters, :path).new(params, '/x')
    view = Object.new
    view.define_singleton_method(:request) { request }
    view.define_singleton_method(:can?) { |*| admin }
    view
  end

  def collection(params: {}, admin: true, **opts)
    CrudComponents::Presenters::Collection.new(
      view: view(params: params, admin: admin), records: Book.all, fieldset: :index, **opts
    )
  end

  def color = CrudComponents::DynamicColumn.new(:color, label: 'Color') { |r, _| "c#{r.id}" }

  # ── the field ──────────────────────────────────────────────────────────────
  test 'a dynamic column resolves its value from the resolver block + preload cache' do
    column = CrudComponents::DynamicColumn.new(:weight, as: :number,
                                               preload: ->(records) { records.to_h { |r| [r.id, r.id * 10] } }) do |record, loaded|
      loaded[record.id]
    end
    book = Book.create!(title: 'W', slug: 'dc-weight', price: 1)
    field = column.to_field(Book).preload!([book])

    assert_equal book.id * 10, field.value(book)
    assert_equal :number, field.renderer(book)   # explicit as:
    assert_nil field.column                       # no backing DB column
  end

  test 'renderer is inferred from the value type when no as: is given' do
    book = Book.create!(title: 'I', slug: 'dc-infer', price: 1)
    assert_equal :boolean, CrudComponents::DynamicColumn.new(:flag) { |_r| true }.to_field(Book).renderer(book)
    assert_equal :date, CrudComponents::DynamicColumn.new(:on) { |_r| Date.today }.to_field(Book).renderer(book)
    assert_equal :string, CrudComponents::DynamicColumn.new(:txt) { |_r| 'x' }.to_field(Book).renderer(book)
  end

  test 'filter/sort are off unless the column supplies the facet (keeps the query whitelist tight)' do
    plain = CrudComponents::DynamicColumn.new(:c) { |_r| 1 }.to_field(Book)
    assert_not plain.filterable?
    assert_not plain.sortable?

    rich = CrudComponents::DynamicColumn.new(:c, filter: ->(s, _v) { s }, sort: ->(s, _d) { s }).to_field(Book)
    assert rich.filterable?
    assert rich.sortable?
  end

  # ── the presenter: selection + ordering ──────────────────────────────────────
  test 'dynamic columns are appended to the permitted column set' do
    names = collection(extra_columns: [color]).available_fields.map(&:name)
    assert_includes names, :color
    assert_equal :color, names.last
  end

  test '?cols= limits and orders the visible columns' do
    fields = collection(params: { 'cols' => %w[color title] }, extra_columns: [color]).fields
    assert_equal %i[color title], fields.map(&:name)
  end

  test 'an unknown ?cols= name is ignored, not rendered' do
    fields = collection(params: { 'cols' => %w[nope title] }).fields
    assert_equal %i[title], fields.map(&:name)
  end

  test 'visible: is the default selection; ?cols= overrides it' do
    assert_equal %i[title color], collection(extra_columns: [color], visible: %i[title color]).fields.map(&:name)
    assert_equal %i[color],
                 collection(params: { 'cols' => %w[color] }, extra_columns: [color], visible: %i[title]).fields.map(&:name)
  end

  test 'column_visible? reflects the current selection' do
    c = collection(params: { 'cols' => %w[title] }, extra_columns: [color])
    assert c.column_visible?(c.available_fields.find { |f| f.name == :title })
    assert_not c.column_visible?(c.available_fields.find { |f| f.name == :color })
  end

  # ── security: a hidden column stays hidden, however ?cols= is forged ──────────
  test 'a permission-gated dynamic column never appears, even when ?cols= names it' do
    gated = CrudComponents::DynamicColumn.new(:secret, if: -> { false }) { |_r| 's' }

    assert_not_includes collection(extra_columns: [gated]).available_fields.map(&:name), :secret
    # forged param can only hide/reorder permitted columns — never reveal this one
    assert_equal %i[color], collection(params: { 'cols' => %w[secret color] },
                                       extra_columns: [color, gated]).fields.map(&:name)
  end

  test 'a manage-gated dynamic column follows the ability like a declared if: field' do
    gated = CrudComponents::DynamicColumn.new(:cost, if: :manage) { |_r| 9 }
    assert_includes collection(extra_columns: [gated], admin: true).available_fields.map(&:name), :cost
    assert_not_includes collection(extra_columns: [gated], admin: false).available_fields.map(&:name), :cost
  end

  # ── controller helper + reuse in the record presenter ────────────────────────
  test 'CrudComponents.selected_columns extracts the picker selection from params' do
    assert_nil CrudComponents.selected_columns({})
    assert_equal %w[title price], CrudComponents.selected_columns({ 'cols' => %w[title price] })
    assert_equal %w[title], CrudComponents.selected_columns({ 'books_cols' => %w[title] }, param_prefix: :books)
    assert_nil CrudComponents.selected_columns({ 'cols' => ['', nil] })  # empty submit → nil

    yielded = nil
    CrudComponents.selected_columns({ 'cols' => %w[a b] }) { |cols| yielded = cols }
    assert_equal %w[a b], yielded
    CrudComponents.selected_columns({}) { |_cols| flunk 'block must not run when nothing was submitted' }
  end

  test 'crud_record (the Record presenter) honors visible: and ?cols=, intersected with permitted fields' do
    book = Book.create!(title: 'R', slug: 'rec-vis', price: 1)
    base = CrudComponents::Presenters::Record.new(view: view, record: book, visible: %i[price title])
    assert_equal %i[price title], base.fields.map(&:name)   # visible: default, in order

    picked = CrudComponents::Presenters::Record.new(view: view(params: { 'cols' => %w[title] }),
                                                    record: book, visible: %i[price title])
    assert_equal %i[title], picked.fields.map(&:name)       # ?cols= overrides the default
  end

  test 'crud_record renders dynamic columns as extra rows (extra_columns:)' do
    book = Book.create!(title: 'Rec', slug: 'rec-extra', price: 1)
    column = CrudComponents::DynamicColumn.new(:shelf, label: 'Shelf',
                                               preload: ->(records) { records.to_h { |r| [r.id, 'A1'] } }) do |record, loaded|
      loaded[record.id]
    end
    presenter = CrudComponents::Presenters::Record.new(view: view, record: book, extra_columns: [column])

    assert_includes presenter.available_fields.map(&:name), :shelf
    shelf = presenter.fields.find { |f| f.name == :shelf }
    assert_equal 'A1', shelf.value(book)   # batch-loaded on [record] and resolved
  end

  test 'a dynamic/computed column header uses its label: instead of the humanized slug' do
    column = CrudComponents::DynamicColumn.new(:shelf_no, label: 'Bookshelf')
    field = column.to_field(Book)

    assert_equal 'Bookshelf', field.human_name    # not the humanized "Shelf no"
    assert_equal 'Bookshelf', field.picker_label  # the picker agrees with the header
  end

  # ── custom column headers + header actions (issue #4) ─────────────────────────
  test 'a plain dynamic column has no custom header (layout keeps human_name + sort)' do
    field = color.to_field(Book)
    assert_not field.custom_header?
    assert_not collection(extra_columns: [color]).custom_header?(field)
  end

  test 'header: and header_actions: flow from the column onto its field' do
    action = CrudComponents::Action.new(:send_all, method: :post) { '/send' }
    column = CrudComponents::DynamicColumn.new(:mail, label: 'Mail',
                                               header: -> { 'X' }, header_actions: [action])
    field = column.to_field(Book)

    assert field.custom_header?
    assert_equal [action], field.header_actions
    assert_kind_of Proc, field.header
  end

  test 'column_header renders a String header verbatim and evaluates a block in the view' do
    string_col = CrudComponents::DynamicColumn.new(:s, header: '<b>Hi</b>'.html_safe) { |_r| 1 }
    block_col  = CrudComponents::DynamicColumn.new(:b, header: -> { upcase_me }) { |_r| 1 }

    v = view
    v.define_singleton_method(:upcase_me) { 'FROM-VIEW' }
    col = CrudComponents::Presenters::Collection.new(view: v, records: Book.all, fieldset: :index,
                                                     extra_columns: [string_col, block_col])

    s_field = col.available_fields.find { |f| f.name == :s }
    b_field = col.available_fields.find { |f| f.name == :b }
    assert_equal '<b>Hi</b>', col.column_header(s_field)        # String passes through as-is
    assert_equal 'FROM-VIEW', col.column_header(b_field)        # block runs in view context
  end

  test 'column_header_actions builds a collection-kind Actions presenter, nil when none' do
    action = CrudComponents::Action.new(:send_all, method: :post) { '/send' }
    with    = CrudComponents::DynamicColumn.new(:m, header_actions: [action]) { |_r| 1 }
    without = CrudComponents::DynamicColumn.new(:n, header: -> { 'h' }) { |_r| 1 }

    col = collection(extra_columns: [with, without])
    with_field    = col.available_fields.find { |f| f.name == :m }
    without_field = col.available_fields.find { |f| f.name == :n }

    actions = col.column_header_actions(with_field)
    assert_equal :collection, actions.kind                     # acts on the column, not a row
    assert_nil col.column_header_actions(without_field)        # header but no actions
  end
end

# End-to-end through the dummy app's playground pages, JavaScript-free.
class DynamicColumnsIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @shelf  = PropertyDefinition.create!(key: 'shelf',  label: 'Shelf',  flavor: 'string')
    @weight = PropertyDefinition.create!(key: 'weight', label: 'Weight', flavor: 'number', unit: 'g')
    @alpha = Book.create!(title: 'Alpha', slug: 'dc-alpha', price: 1)
    @beta  = Book.create!(title: 'Beta',  slug: 'dc-beta',  price: 2)
    PropertyValue.create!(property_definition: @shelf,  subject: @alpha, value: 'A1')
    PropertyValue.create!(property_definition: @shelf,  subject: @beta,  value: 'B2')
    PropertyValue.create!(property_definition: @weight, subject: @alpha, value: '300')
    PropertyValue.create!(property_definition: @weight, subject: @beta,  value: '900')
  end

  test 'dynamic columns render with type-aware formatting' do
    get '/custom_fields'
    assert_response :success
    assert_select 'th', text: /Shelf/
    assert_select 'td', text: /A1/
    assert_match(/300.* g/, response.body)   # number flavor + unit
  end

  test 'a dynamic column filters via a plain GET param' do
    get '/custom_fields', params: { shelf: 'A1' }
    assert_select 'td', text: /A1/
    assert_select 'td', { text: /B2/, count: 0 }
  end

  test 'a dynamic column sorts via plain GET params' do
    get '/custom_fields', params: { sort: 'weight', dir: 'desc' }
    assert_response :success
    assert response.body.index('Beta') < response.body.index('Alpha'), 'desc weight: 900 (Beta) before 300 (Alpha)'
  end

  test 'the column picker limits the visible columns via ?cols=' do
    get '/columns', params: { cols: %w[shelf title] }
    assert_response :success
    # Assert on the sortable header links (the picker's labels are <span>s, so
    # scope to <th> <a> to avoid matching the picker list).
    assert_select 'thead th a', text: /Shelf/
    assert_select 'thead th a', { text: /Genre/, count: 0 }   # dropped by the selection
  end

  test 'the picker renders a checkbox per available column, pre-ticked for the current view' do
    get '/columns', params: { cols: %w[title] }
    assert_select 'input[type=checkbox][name="cols[]"][value=title][checked]'
    assert_select 'input[type=checkbox][name="cols[]"][value=shelf]:not([checked])'
  end

  test 'the picker is a gear in the table header, not a toolbar button' do
    get '/columns'
    assert_select 'thead details.crud-column-picker summary i[class*=gear]'   # gear, in the header
    assert_select '.crud-toolbar-cell details.crud-column-picker', count: 0   # not in the toolbar
  end

  test 'the standalone picker drives a detail view via ?cols=' do
    book = Book.create!(title: 'Solo', slug: 'solo-detail', price: 7)
    get book_path(book)
    assert_select 'details.crud-column-picker'                 # the standalone gear renders
    assert_select 'dt', text: /Title/
    assert_select 'dt', text: /Price/

    get book_path(book), params: { cols: %w[title] }
    assert_select 'dt', text: /Title/
    assert_select 'dt', { text: /Price/, count: 0 }            # crud_record narrowed to the pick
  end

  # ── custom column headers + header actions (issue #4) ─────────────────────────
  test 'a dynamic column renders a custom header link in its <th>' do
    get '/column_headers'
    assert_response :success
    # The header block is a link_to, so the Shelf column header is an <a>, not
    # plain text (and not a sort link — these columns are display-only).
    assert_select 'thead th a', text: /Shelf/
  end

  test 'a :post header action renders as a POST form (button_to), not a GET link' do
    get '/column_headers'
    assert_response :success
    # button_to → a form posting to the action path with the column key.
    assert_select "form[action='#{touch_all_column_headers_path(key: 'shelf')}'][method=post]"
    assert_select "form[action='#{touch_all_column_headers_path(key: 'shelf')}'] button[type=submit]"
    # …and never a GET link to that path.
    assert_select "a[href='#{touch_all_column_headers_path(key: 'shelf')}']", count: 0
  end

  test 'a render: cell block can read the preload:-ed value (passed as the 2nd arg)' do
    get '/column_headers'
    assert_response :success
    # The render: block built `tag:<value>` from the value it now receives.
    assert_select 'span.shelf-tag', text: 'tag:A1'
    assert_select 'span.shelf-tag', text: 'tag:B2'
  end

  test 'dynamic columns batch-load: a fixed number of value queries, independent of row count' do
    8.times { |i| Book.create!(title: "Bulk #{i}", slug: "dc-bulk-#{i}", price: 1) }
    selects = []
    callback = lambda do |_name, _start, _finish, _id, payload|
      selects << payload[:sql] if payload[:sql].to_s.match?(/SELECT.*property_values/i)
    end
    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') { get '/custom_fields' }

    # No filter/sort here, so the only property_values reads are the per-column
    # preloads — one each, never one per book.
    assert_operator selects.size, :<=, PropertyDefinition.count + 1,
                    "expected ≤ #{PropertyDefinition.count + 1} property_values queries, got #{selects.size}"
  end
end
