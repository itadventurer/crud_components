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

  test 'custom renderer partial from the host app wins' do
    get reviews_path
    assert_match '★★★★', response.body
  end

  test 'has_many renders a truncated list with +n more' do
    5.times { |i| @hobbit.reviews.create!(rating: 3, reviewer_name: "R#{i}", body: 'ok') }
    get books_path(view: 'catalog')
    assert_match 'more', response.body
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

  test 'a model without routes gets no broken buttons' do
    # Authors have only an index route — no show/edit/destroy/new.
    get authors_path
    assert_select 'a[href*="/authors/"]', count: 0
    assert_select 'form[action*="/authors/"]', count: 0
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
end
