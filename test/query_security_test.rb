require 'test_helper'

# The security model as executable spec. The uniform rule: a param is applied
# iff it names a filterable field of the fieldset in play that the current
# user may see (or q/sort/dir/page/per). Everything else never reaches SQL.
class QuerySecurityTest < ActiveSupport::TestCase
  def setup
    @tor = Publisher.create!(name: 'Tor Books', slug: 'tor-books')
    @ace = Publisher.create!(name: 'Ace', slug: 'ace')

    @le_guin = Author.create!(name: 'Ursula K. Le Guin', email: 'ursula@example.com')
    @tolkien = Author.create!(name: 'J. R. R. Tolkien', email: 'jrr@example.com')

    @hobbit = Book.create!(title: 'The Hobbit', slug: 'hobbit', price: 15, purchase_price: 6,
                           genre: :fiction, active: true, published_on: Date.new(1937, 9, 21),
                           publisher: @tor, authors: [@tolkien], pages: 310,
                           blurb: 'Dragons and dwarves.', internal_token: 'sekrit')
    @dispossessed = Book.create!(title: 'The Dispossessed', slug: 'dispossessed', price: 12,
                                 purchase_price: 5, genre: :scifi, active: false,
                                 published_on: Date.new(1974, 5, 1), publisher: @ace,
                                 authors: [@le_guin], pages: 387, blurb: 'An ambiguous utopia.')
    @ruby = Book.create!(title: '100% Ruby', slug: 'percent-ruby', price: 39.9, genre: :nonfiction,
                         active: true, published_on: Date.new(2020, 1, 1), pages: 250)
  end

  def query(params, fieldset: :catalog, **options)
    CrudComponents::Query.new(Book, params, fieldset: fieldset, **options)
  end

  def apply(params, **options)
    query(params, **options).apply(Book.all)
  end

  # ── 1. whitelist by construction ──────────────────────────────────────────
  test 'params that name nothing filterable are inert' do
    assert_equal 3, apply({ 'magic_token' => 'x', 'cloud_init' => 'y' }).count
  end

  test 'a real column outside the fieldset is inert' do
    # internal_token exists on books and is string-filterable by type,
    # but no fieldset shows it — filter only what you can see.
    assert_equal 3, apply({ 'internal_token' => 'sekrit' }).count
  end

  test 'fieldset-bound: the same param filters in one fieldset, is inert in another' do
    assert_equal 1, apply({ 'genre' => 'scifi' }, fieldset: :catalog).count
    assert_equal 3, apply({ 'genre' => 'scifi' }, fieldset: :compact).count
  end

  test 'filters: extends the filterable set beyond visible columns' do
    assert_equal [@hobbit], apply({ 'blurb' => 'dragons' }).to_a
  end

  test 'non-scalar param values are ignored' do
    assert_equal 3, apply({ 'title' => { 'evil' => 'hash' } }).count
    assert_equal 3, apply({ 'title' => %w[evil array] }).count
  end

  # ── 2. permissions come first ─────────────────────────────────────────────
  test 'permission-gated fields are unfilterable without an ability' do
    assert_equal 3, apply({ 'purchase_price_geq' => '1' }).count
  end

  test 'permission-gated fields filter with a granting ability' do
    scoped = apply({ 'purchase_price_geq' => '6' }, ability: CrudTestHelpers::AllowAll.new)
    assert_equal [@hobbit], scoped.to_a
  end

  test 'a denying ability keeps gated fields inert' do
    assert_equal 3, apply({ 'purchase_price_geq' => '1' }, ability: CrudTestHelpers::DenyAll.new).count
  end

  # ── 3. no injection through sort/dir ──────────────────────────────────────
  test 'sorts by whitelisted fields with direction' do
    titles = apply({ 'sort' => 'title', 'dir' => 'desc' }).pluck(:title)
    assert_equal ['The Hobbit', 'The Dispossessed', '100% Ruby'], titles
  end

  test 'sort injection produces no ORDER BY at all' do
    sql = apply({ 'sort' => 'title; DROP TABLE books' }).to_sql
    refute_match(/ORDER BY/i, sql)
    refute_match(/DROP/i, sql)
  end

  test 'invalid dir falls back to asc' do
    titles = apply({ 'sort' => 'title', 'dir' => 'evil; --' }).pluck(:title)
    assert_equal ['100% Ruby', 'The Dispossessed', 'The Hobbit'], titles
  end

  test 'sorting is bound to the fieldset too' do
    sql = apply({ 'sort' => 'title' }, fieldset: :compact).to_sql
    assert_match(/ORDER BY/i, sql)
    sql = apply({ 'sort' => 'genre' }, fieldset: :compact).to_sql
    refute_match(/ORDER BY/i, sql, 'genre is not visible in :compact')
  end

  test 'a belongs_to sorts by the target label via a join' do
    sql = apply({ 'sort' => 'publisher', 'dir' => 'asc' }).to_sql
    assert_match(/ORDER BY.*publishers/i, sql)
    ordered = apply({ 'sort' => 'publisher', 'dir' => 'asc' }).to_a
    # Ace < Tor Books → the Ace book precedes the Tor book
    assert_operator ordered.index(@dispossessed), :<, ordered.index(@hobbit)
  end

  test 'a computed field without a sort facet is unsortable' do
    refute_match(/ORDER BY/i, apply({ 'sort' => 'shop_margin' }).to_sql)
  end

  test 'a sort facet makes a computed field sortable' do
    assert_match(/ORDER BY/i, apply({ 'sort' => 'author_names' }).to_sql)
  end

  # ── 4. no injection through values ────────────────────────────────────────
  test 'text filters match case-insensitively and partially' do
    assert_equal [@hobbit], apply({ 'title' => 'hobbit' }).to_a
  end

  test 'LIKE wildcards are escaped: a lone % matches literally, not everything' do
    assert_equal [@ruby], apply({ 'title' => '%' }).to_a
    assert_empty apply({ 'title' => '___________' }).to_a
  end

  test 'a backslash in the value is escaped, not treated as a LIKE escape char' do
    winpath = Book.create!(title: 'C:\\Windows guide', slug: 'winpath', genre: :nonfiction)
    assert_equal [winpath], apply({ 'title' => '\\' }).to_a          # literal backslash only
    assert_equal [winpath], apply({ 'title' => 'C:\\Win' }).to_a     # backslash mid-pattern
    assert_empty apply({ 'title' => '\\%' }).to_a                    # not a wildcard escape
  end

  test 'non-finite numeric values are ignored, never reaching SQL' do
    %w[Infinity -Infinity NaN].each do |bad|
      assert_equal 3, apply({ 'price_geq' => bad }).count, bad
      assert_equal 3, apply({ 'price' => bad }).count, bad
    end
  end

  test 'numeric exact accepts scientific and negative notation' do
    @ruby.update!(price: 100)
    assert_includes apply({ 'price' => '1e2' }).to_a, @ruby
    Book.create!(title: 'Owed', slug: 'owed', price: -5, genre: :fiction)
    assert_equal 1, apply({ 'price_leq' => '-1' }).count
  end

  test 'boolean filters accept the documented short forms and reject the rest' do
    { 't' => 2, '1' => 2, 'on' => 2, 'yes' => 2,
      'f' => 1, '0' => 1, 'off' => 1, 'no' => 1 }.each do |value, count|
      assert_equal count, apply({ 'active' => value }).count, value
    end
    ['2', ' true', 'yes please', '1.0', ''].each do |bad|
      assert_equal 3, apply({ 'active' => bad }).count, bad.inspect
    end
  end

  test 'enum values are validated; invalid ones leave the scope unchanged' do
    assert_equal [@dispossessed], apply({ 'genre' => 'scifi' }).to_a
    assert_equal 3, apply({ 'genre' => 'evil-value' }).count
    assert_equal 3, apply({ 'genre' => '0; DROP TABLE books' }).count
  end

  test 'booleans are cast and validated' do
    assert_equal [@dispossessed], apply({ 'active' => 'false' }).to_a
    assert_equal 2, apply({ 'active' => 'true' }).count
    assert_equal 3, apply({ 'active' => 'banana' }).count
  end

  test 'numeric ranges work; unparsable values are ignored' do
    assert_equal 1, apply({ 'price_geq' => '20' }).count
    assert_equal 2, apply({ 'price_leq' => '20' }).count
    assert_equal 3, apply({ 'price_geq' => 'abc' }).count
  end

  test 'numeric exact match' do
    assert_equal [@dispossessed], apply({ 'price' => '12' }).to_a
  end

  test 'date ranges; datetime ranges are whole-day-inclusive' do
    assert_equal [@ruby], apply({ 'published_on_geq' => '2000-01-01' }).to_a
    assert_equal 3, apply({ 'published_on_geq' => 'not-a-date' }).count
    # created_at is a datetime; everything was created today, so a leq of
    # today must include the whole day, not cut off at 00:00.
    assert_equal 3, apply({ 'created_at_leq' => Date.current.to_s }).count
  end

  test 'date exact match means that whole day' do
    assert_equal [@hobbit], apply({ 'published_on' => '1937-09-21' }).to_a
  end

  test 'datetime range bounds are whole-day-inclusive at the exact edge' do
    day = Date.new(2026, 2, 10)
    edge = Book.create!(title: 'Edge', slug: 'edge', genre: :fiction, created_at: day.end_of_day)
    over = Book.create!(title: 'Over', slug: 'over', genre: :fiction, created_at: (day + 1).beginning_of_day)

    leq = apply({ 'created_at_leq' => '2026-02-10' }).to_a
    assert_includes leq, edge           # 23:59:59 of the day is in
    refute_includes leq, over           # 00:00:00 next day is out

    geq = apply({ 'created_at_geq' => '2026-02-11' }).to_a
    assert_includes geq, over
    refute_includes geq, edge
  end

  # ── 5. identify_by resolution only ────────────────────────────────────────
  test 'belongs_to filters resolve via the declared identify_by column' do
    assert_equal [@hobbit], apply({ 'publisher' => 'tor-books' }).to_a
  end

  test 'belongs_to filters also accept free text over the target search_in' do
    assert_equal [@hobbit], apply({ 'publisher' => 'Tor Books' }).to_a
  end

  test 'raw ids do not resolve belongs_to when identify_by is not :id' do
    assert_empty apply({ 'publisher' => @tor.id.to_s }).to_a
  end

  # ── search ────────────────────────────────────────────────────────────────
  test 'q searches the search_in spec including delegation' do
    assert_equal [@hobbit], apply({ 'q' => 'hobbit' }).to_a
    assert_equal [@hobbit], apply({ 'q' => 'tor books' }).to_a, 'delegated through :publisher'
  end

  test 'computed fields filter through their like-spec facet' do
    assert_equal [@dispossessed], apply({ 'author_names' => 'le guin' }).to_a
  end

  # ── param_prefix ──────────────────────────────────────────────────────────
  test 'with a param_prefix only prefixed params are read' do
    assert_equal [@hobbit], apply({ 'books_title' => 'hobbit' }, param_prefix: :books).to_a
    assert_equal 3, apply({ 'title' => 'hobbit' }, param_prefix: :books).count
  end

  test 'param_prefix applies to sort and search too: prefixed wins, bare is ignored' do
    sql = apply({ 'books_sort' => 'title', 'sort' => 'genre' }, param_prefix: :books).to_sql
    assert_match(/ORDER BY.*title/i, sql)
    refute_match(/ORDER BY.*genre/i, sql)
    assert_equal [@hobbit], apply({ 'books_q' => 'tor books' }, param_prefix: :books).to_a
    assert_equal 3, apply({ 'q' => 'tor books' }, param_prefix: :books).count   # bare q ignored
  end

  # ── search vs. permissions ────────────────────────────────────────────────
  test 'q does not search a declared, permission-gated column' do
    model = define_model(name: 'GatedSearchBook') do
      search_in :title, :blurb
      attribute :blurb, if: :manage          # gated string column
    end
    only_in_blurb = model.create!(title: 'nothing here', slug: 'g1', blurb: 'zztreasure')

    deny = CrudComponents::Query.new(model, { 'q' => 'zztreasure' },
                                     ability: CrudTestHelpers::DenyAll.new)
    assert_empty deny.apply(model.where(id: only_in_blurb.id)).to_a, 'gated column unsearchable'

    allow = CrudComponents::Query.new(model, { 'q' => 'zztreasure' },
                                      ability: CrudTestHelpers::AllowAll.new)
    assert_equal [only_in_blurb], allow.apply(model.where(id: only_in_blurb.id)).to_a
  end

  # ── plumbing ──────────────────────────────────────────────────────────────
  test 'active? reflects whether any filter or search param is set' do
    assert query({ 'title' => 'x' }).active?
    assert query({ 'q' => 'x' }).active?
    refute query({ 'nonsense' => 'x' }).active?
    refute query({}).active?
  end

  # ── exposing the params it understands (filter_params / permitted_keys) ─────
  test 'permitted_keys lists every visible filter field with its bounds plus q/sort/dir' do
    keys = query({}).permitted_keys
    # a visible text field and its (unused-but-permitted) bounds
    assert_includes keys, 'title'
    assert_includes keys, 'title_geq'
    assert_includes keys, 'title_leq'
    # the reserved params the query reads
    assert_includes keys, 'q'
    assert_includes keys, 'sort'
    assert_includes keys, 'dir'
    # pagination is the host's, never the query's
    refute_includes keys, 'page'
    # only what's filterable in the fieldset — internal_token is not visible
    refute_includes keys, 'internal_token'
  end

  test 'permitted_keys is fieldset-bound and never names what you cannot see' do
    assert_includes query({}, fieldset: :catalog).permitted_keys, 'genre'
    refute_includes query({}, fieldset: :compact).permitted_keys, 'genre'
  end

  test 'permitted_keys respects a granting ability for gated fields' do
    refute_includes query({}).permitted_keys, 'purchase_price'
    granted = query({}, ability: CrudTestHelpers::AllowAll.new).permitted_keys
    assert_includes granted, 'purchase_price'
    assert_includes granted, 'purchase_price_geq'
  end

  test 'permitted_keys is enough to permit ActionController params the query then reads' do
    raw = ActionController::Parameters.new('title' => 'hobbit', 'evil' => 'x',
                                           'sort' => 'title', 'dir' => 'desc')
    permitted = raw.permit(*query({}).permitted_keys)
    assert_equal [@hobbit], apply(permitted).to_a
    refute permitted.key?('evil')
  end

  test 'filter_params keeps only present, understood params under their real names' do
    fp = query({ 'title' => 'hobbit', 'price_geq' => '10', 'price_leq' => '',
                 'sort' => 'title', 'evil' => 'x', 'page' => '3' }).filter_params
    assert_equal({ 'title' => 'hobbit', 'price_geq' => '10', 'sort' => 'title' }, fp)
  end

  test 'filter_params drops non-scalar values' do
    assert_empty query({ 'title' => { 'evil' => 'hash' } }).filter_params
  end

  test 'active_filters reads filter and search values by logical name, excluding sort/dir' do
    af = query({ 'title' => 'hobbit', 'price_geq' => '10', 'q' => 'dragons',
                 'sort' => 'title', 'dir' => 'desc' }).active_filters
    assert_equal({ 'title' => 'hobbit', 'price_geq' => '10', 'q' => 'dragons' }, af)
  end

  test 'a param_prefix flows through permitted_keys, filter_params and active_filters' do
    q = query({ 'books_title' => 'hobbit', 'title' => 'ignored', 'books_q' => 'x' },
              param_prefix: :books)
    assert_includes q.permitted_keys, 'books_title'
    assert_includes q.permitted_keys, 'books_q'
    refute_includes q.permitted_keys, 'title'
    assert_equal({ 'books_title' => 'hobbit', 'books_q' => 'x' }, q.filter_params)
    # active_filters keys are logical (unprefixed) for the chip UI
    assert_equal({ 'title' => 'hobbit', 'q' => 'x' }, q.active_filters)
  end

  test 'unknown fieldset raises' do
    assert_raises(CrudComponents::UnknownFieldsetError) { query({}, fieldset: :playgruond) }
  end
end
