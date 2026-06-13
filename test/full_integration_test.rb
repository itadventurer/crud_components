require 'test_helper'

# End-to-end through the dummy app, JavaScript-free by construction: every
# assertion drives the UI exactly the way a no-JS browser would — plain GET
# requests with query params, plain form posts.
class FullIntegrationTest < ActionDispatch::IntegrationTest
  def setup
    @tor = Publisher.create!(name: 'Tor Books', slug: 'tor-books', founded_on: Date.new(1980, 1, 1))
    @ace = Publisher.create!(name: 'Ace', slug: 'ace')
    @tolkien = Author.create!(name: 'J. R. R. Tolkien', email: 'jrr@example.com')
    @hobbit = Book.create!(title: 'The Hobbit', slug: 'hobbit', price: 15, purchase_price: 6,
                           genre: :fiction, active: true, published_on: Date.new(1937, 9, 21),
                           publisher: @tor, authors: [@tolkien], pages: 310)
    @dispossessed = Book.create!(title: 'The Dispossessed', slug: 'dispossessed', price: 12,
                                 genre: :scifi, active: false, publisher: @ace)
    @review = Review.create!(book: @hobbit, rating: 4, reviewer_name: 'Ada', body: 'A classic.')
  end

  # ── zero config ───────────────────────────────────────────────────────────
  test 'a zero-config model renders a usable table' do
    get authors_path
    assert_response :success
    assert_select 'table'
    assert_select 'th', text: /Name/
    assert_select 'td', text: /Tolkien/
  end

  test 'a zero-config model filters and sorts via plain GET params' do
    Author.create!(name: 'Ursula K. Le Guin', email: 'ursula@example.com')
    get authors_path(name: 'tolkien')
    assert_select 'td', text: /Tolkien/
    assert_select 'td', { text: /Le Guin/, count: 0 }

    get authors_path(sort: 'name', dir: 'desc')
    assert_response :success
    assert response.body.index('Ursula') < response.body.index('J. R. R.'), 'desc order: U before J'
  end

  # ── cells ─────────────────────────────────────────────────────────────────
  test 'cells render type-aware: badge, currency options, boolean icon, links' do
    get books_path
    assert_select 'span.badge', text: /Fiction/
    assert_match(/15\.00 €/, response.body)
    assert_select 'span.text-success', text: '✓'
    assert_select "a[href='#{publisher_path(@tor)}']", text: 'Tor Books'
  end

  test 'the label cell links to the record' do
    get books_path
    assert_select "a[href='#{book_path(@hobbit)}']", text: 'The Hobbit'
  end

  test 'custom renderer partial from the host app wins and reflects the value' do
    @review.update!(rating: 4)
    Review.create!(book: @hobbit, rating: 2, reviewer_name: 'Bo', body: 'meh')
    get reviews_path
    assert_select 'span[title="4/5"]'   # the host-app _stars partial, tied to value
    assert_select 'span[title="2/5"]'
  end

  test 'has_many renders a truncated list with a +n more link' do
    5.times { |i| @hobbit.reviews.create!(rating: 3, reviewer_name: "R#{i}", body: 'ok') }
    get books_path(view: 'catalog')
    # the gem shows the first 3 then a real "+n more" link (here → /reviews?book=hobbit)
    assert_select "a[href*='/reviews?book=hobbit']", text: /\+\d+ more/
  end

  # ── filtering, sorting (no JS: plain GET) ─────────────────────────────────
  test 'the inline filter row binds inputs to the external form' do
    get books_path
    assert_select "form#crud_filter_books[method=get]"
    assert_select "input[name=title][form=crud_filter_books]"
    assert_select "select[name=genre][form=crud_filter_books]"
  end

  test 'filtering via GET params narrows the table' do
    get books_path(genre: 'scifi')
    assert_select 'td', text: /The Dispossessed/
    assert_select 'td', { text: /The Hobbit/, count: 0 }
  end

  test 'sort headers are plain links that toggle direction and keep filters' do
    get books_path(genre: 'fiction')
    assert_select "th a[href*='sort=title']"
    assert_select "th a[href*='genre=fiction']", { minimum: 1 }, 'sort links preserve filters'
  end

  test 'the standalone filter form has a real submit button and no autosubmit' do
    get books_path
    assert_select 'form.crud-filter-form button[type=submit]'
    assert_select 'form.crud-filter-form select[data-action]', count: 0
  end

  # ── permissions ───────────────────────────────────────────────────────────
  test 'permission-gated columns are hidden and unfilterable for non-admins' do
    get books_path(view: 'catalog')
    assert_select 'th', { text: /Purchase price/, count: 0 }

    # the param is inert, so both books stay visible
    get books_path(view: 'catalog', purchase_price_geq: '7')
    assert_select "tbody a[href='#{book_path(@hobbit)}']"
    assert_select "tbody a[href='#{book_path(@dispossessed)}']"
  end

  test 'permission-gated columns appear for admins' do
    post toggle_admin_path
    get books_path(view: 'catalog')
    assert_select 'th', text: /Purchase price/
  end

  test 'derived destroy action is permission-gated through can?' do
    get books_path
    assert_select "form[action='#{book_path(@hobbit)}']", count: 0

    post toggle_admin_path
    get books_path
    assert_select "form[action='#{book_path(@hobbit)}']"
  end

  # ── actions & routes ──────────────────────────────────────────────────────
  test 'derived actions resolve conventional routes; customs too' do
    get books_path
    assert_select "a[href='#{edit_book_path(@hobbit)}']"
    assert_select "a[href='#{preview_book_path(@hobbit)}']", { minimum: 1 }, 'custom member action'
    assert_select "a[href='#{new_book_path}']", { minimum: 1 }, 'collection action'
  end

  test 'an association collection prefers nested routes' do
    get publisher_books_path(@tor)
    assert_select "a[href='#{edit_publisher_book_path(@tor, @hobbit)}']"
  end

  test 'derived actions self-disable when their route is missing' do
    # Reviews have no :new route — the derived :new action is omitted, while
    # :edit (which does have a route) is rendered.
    get reviews_path
    assert_select "a[href*='/reviews/new']", count: 0
    assert_select "a[href='#{edit_review_path(@review)}']"
  end

  test 'destroy works end to end' do
    post toggle_admin_path
    assert_difference 'Review.count', -1 do
      delete review_path(@review)
    end
    follow_redirect!
    assert_response :success
  end

  # ── static collections and multi-collection pages ─────────────────────────
  test 'query: false renders a static table without filter row or sort links' do
    get book_path(@hobbit)
    assert_select 'h2', text: /Reviews/
    assert_select 'tr.crud-filter-row', count: 0
  end

  test 'param_prefix isolates two collections on one page' do
    get dashboard_path(books_title: 'hobbit')
    assert_select 'tbody td', text: /The Hobbit/
    assert_select 'tbody td', { text: /The Dispossessed/, count: 0 }
    assert_select 'tbody td', text: /Ada/, minimum: 1 # reviews table untouched

    get dashboard_path(reviews_sort: 'rating', books_title: 'hobbit')
    assert_response :success
  end

  # ── record page ───────────────────────────────────────────────────────────
  test 'the record page renders a definition list with actions' do
    get book_path(@hobbit)
    assert_select 'dl dt', text: 'Title'
    assert_select 'dl dd', text: /The Hobbit/
    assert_select "a[href='#{edit_book_path(@hobbit)}']", minimum: 1
  end

  test 'search works via plain ?q=' do
    get books_path(q: 'tor books')
    assert_select 'td', text: /The Hobbit/
    assert_select 'td', { text: /The Dispossessed/, count: 0 }
  end

  test 'the header has a global search box and books are searchable by author' do
    get books_path
    assert_select 'input[type=search][name=q]'
    get books_path(q: 'tolkien')        # delegates through :authors
    assert_select 'td', text: /The Hobbit/
    assert_select 'td', { text: /The Dispossessed/, count: 0 }
  end

  test 'a reset link appears in the filter row only when filtering' do
    get books_path
    assert_select 'tr.crud-filter-row a', { text: /Reset/, count: 0 }
    get books_path(genre: 'fiction')
    assert_select 'tr.crud-filter-row a', text: /Reset/
  end

  # ── click-to-filter ───────────────────────────────────────────────────────
  test 'enum badges link to a click-to-filter URL' do
    get books_path
    assert_select "a[href*='genre=fiction'] span.badge", text: /Fiction/
  end

  test 'click-to-filter respects param_prefix' do
    get dashboard_path
    assert_select "a[href*='books_genre=']"   # prefixed, not bare genre=
  end

  # ── auto association columns & has_many links ─────────────────────────────
  test 'a zero-config model auto-derives association columns' do
    get authors_path
    assert_select 'th', text: /Books/
  end

  test 'has_many +n more prefers the nested index' do
    6.times { |i| @tor.books.create!(title: "Extra #{i}", slug: "extra-#{i}") }
    get publisher_path(@tor)
    assert_select "a[href='#{publisher_books_path(@tor)}']"
  end

  test 'has_many +n more falls back to the filtered flat index (belongs_to inverse)' do
    5.times { |i| @hobbit.reviews.create!(rating: 3, reviewer_name: "R#{i}", body: 'x') }
    get books_path(view: 'catalog')
    # no nested book_reviews route, but Review belongs_to :book and filters by slug
    assert_select "a[href*='/reviews?book=hobbit']", text: /\+\d+ more/
  end

  test 'has_many +n more on a habtm uses the nested route, never a misleading filter param' do
    author = Author.create!(name: 'Prolific')
    4.times { |i| author.books << Book.create!(title: "B#{i}", slug: "habtm-b#{i}") }
    get authors_path
    assert_select "a[href='#{author_books_path(author)}']", text: /\+1 more/
    # the old behavior linked to /books?author=<id>, which silently showed everything
    assert_select "a[href*='/books?author=']", count: 0
  end

  test 'the nested author books index scopes to that author' do
    author = Author.create!(name: 'Scoped')
    hers = Book.create!(title: 'Hers Alone', slug: 'hers'); author.books << hers
    Book.create!(title: 'Not Hers', slug: 'not-hers')
    get author_books_path(author)
    assert_select 'td', text: /Hers Alone/
    assert_select 'td', { text: /Not Hers/, count: 0 }
  end

  # ── custom layout & custom collection action ──────────────────────────────
  test 'a host-app layout renders via as:' do
    get books_path(layout: 'cards')
    assert_select '.card.h-100'
  end

  test 'a custom collection action renders and resolves its route' do
    get books_path
    assert_select "a[href='#{import_books_path}']"
  end

  # ── forms ─────────────────────────────────────────────────────────────────
  test 'the derived edit form has type-appropriate inputs' do
    get edit_book_path(@hobbit)
    assert_select "input[name='book[title]']"
    assert_select "textarea[name='book[blurb]']"
    assert_select "select[name='book[publisher_id]']"
    assert_select "select[name='book[author_ids][]'][multiple][data-controller='crud-tokens']"  # habtm baseline + chip hook
    assert_select "input[name='book[cover]'][type=file]"
  end

  test 'editable: false renders read-only; editable: permission gates the input' do
    get edit_book_path(@hobbit)
    assert_select '.crud-form-readonly'                     # slug (and active, for non-admin)
    assert_select "input[name='book[active]']", count: 0    # not editable for non-admin
    assert_select "input[name='book[purchase_price]']", count: 0  # not even visible
    assert_select "label", { text: /Purchase price/, count: 0 }

    post toggle_admin_path
    get edit_book_path(@hobbit)
    assert_select "input[name='book[active]']"              # editable for admin
    assert_select "input[name='book[purchase_price]']"      # visible & editable for admin
  end

  test 'create through the derived form + permit list' do
    assert_difference 'Book.count', 1 do
      post books_path, params: { book: {
        title: 'A New Hope', slug: 'a-new-hope', price: '9.99', genre: 'scifi',
        publisher_id: @tor.id, author_ids: [@tolkien.id]
      } }
    end
    book = Book.find_by(slug: 'a-new-hope')
    assert_equal 'A New Hope', book.title
    assert_equal @tor, book.publisher
    assert_equal [@tolkien], book.authors
  end

  test 'the permit list blocks gated fields for non-admins on update' do
    patch book_path(@hobbit), params: { book: {
      title: 'Renamed', slug: 'hacked-slug', active: '0', purchase_price: '999'
    } }
    @hobbit.reload
    assert_equal 'Renamed', @hobbit.title              # editable field went through
    assert_equal 'hobbit', @hobbit.slug                # editable: false — untouched
    assert @hobbit.active, 'editable: :manage — non-admin cannot change it'
    assert_equal 6, @hobbit.purchase_price.to_i        # if: :manage — untouched
  end

  test 'an admin can update gated fields' do
    post toggle_admin_path
    patch book_path(@hobbit), params: { book: { active: '0', purchase_price: '4' } }
    @hobbit.reload
    refute @hobbit.active
    assert_equal 4, @hobbit.purchase_price.to_i
  end

  test 'forms work on a zero-config model' do
    get new_author_path
    assert_select "input[name='author[name]']"
    assert_difference 'Author.count', 1 do
      post authors_path, params: { author: { name: 'New Author', email: 'new@example.com' } }
    end
  end

  test 'publisher edit/update/create all work' do
    get edit_publisher_path(@tor)
    assert_select "input[name='publisher[name]']"
    patch publisher_path(@tor), params: { publisher: { name: 'Tor (renamed)' } }
    assert_equal 'Tor (renamed)', @tor.reload.name

    assert_difference 'Publisher.count', 1 do
      post publishers_path, params: { publisher: { name: 'New Press' } }
    end
    assert Publisher.find_by(slug: 'new-press'), 'slug auto-generated'
  end

  test 'a failed save re-renders the form: inline field errors, entered values kept' do
    patch book_path(@hobbit), params: { book: { title: '', price: '42' } }
    assert_response :unprocessable_entity
    assert_select '.invalid-feedback', text: /blank/i                    # simple_form's inline error
    assert_select "input[name='book[price]'][value='42']"                # entered value kept
    assert_equal 'The Hobbit', @hobbit.reload.title                       # not persisted
  end

  test 'base (whole-record) errors surface in the summary, not just the count' do
    post toggle_admin_path   # so `active` is editable
    patch book_path(@hobbit), params: { book: { price: '0', active: '1' } }
    assert_response :unprocessable_entity
    assert_select '.alert-danger li', text: /priced at 0 must be inactive/i
  end

  test 'a failed save on a zero-config model also shows errors' do
    post authors_path, params: { author: { name: '' } }
    assert_response :unprocessable_entity
    assert_select '.invalid-feedback', text: /blank/i
  end

  test 'review edit/update work, including the belongs_to select' do
    get edit_review_path(@review)
    assert_select "select[name='review[book_id]']"
    assert_select "input[name='review[reviewer_name]']"
    patch review_path(@review), params: { review: { rating: 2, reviewer_name: 'Renamed' } }
    @review.reload
    assert_equal 2, @review.rating
    assert_equal 'Renamed', @review.reviewer_name
  end
end
