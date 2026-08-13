require_relative 'test_helper'

# The mounted engine, end to end through the dummy app: routes drawn from the
# registry, one controller behind all of them, the gate in front.
class AdminEngineTest < ActionDispatch::IntegrationTest
  def setup
    @tor = Publisher.create!(name: 'Tor Books', slug: 'tor-books')
    @tolkien = Author.create!(name: 'J. R. R. Tolkien', email: 'jrr@example.com')
    @hobbit = Book.create!(title: 'The Hobbit', slug: 'hobbit', price: 15, genre: :fiction,
                           active: true, publisher: @tor, authors: [@tolkien])
    @dispossessed = Book.create!(title: 'The Dispossessed', slug: 'dispossessed', price: 12,
                                 genre: :scifi, active: false, publisher: @tor)
  end

  # A blank configuration for the duration of the block — the routes are already
  # drawn, so only the gate changes.
  def with_admin_config
    reset_admin_config!
    CrudComponents::Admin.config.parent_controller = 'ApplicationController'
    yield CrudComponents::Admin.config
  ensure
    restore_admin_config!
  end

  # ── the gate ─────────────────────────────────────────────────────────────
  test 'an unconfigured gate refuses to serve anything' do
    with_admin_config do
      error = assert_raises(CrudComponents::Admin::UnauthorizedError) { get '/admin' }
      assert_match(/authorize_with/, error.message)
    end
  end

  test 'the gate runs in the controller and can turn a request away' do
    with_admin_config do |config|
      config.authorize_with { head :forbidden }
      get '/admin'

      assert_response :forbidden
    end
  end

  test 'a configured gate that lets the request through renders' do
    with_admin_config do |config|
      config.authorize_with { nil }
      get '/admin'

      assert_response :success
    end
  end

  # ── routes ───────────────────────────────────────────────────────────────
  test 'the dashboard links to every registered model' do
    get '/admin'

    assert_response :success
    assert_select "a[href='/admin/books']"
    assert_select "a[href='/admin/publishers']"
  end

  test 'an unregistered model has no route' do
    get '/admin/no_such_things'

    assert_response :not_found
  end

  test 'a read-only model has no write routes at all' do
    get '/admin/property_values'

    assert_response :success

    post '/admin/property_values'

    assert_response :not_found
  end

  # ── index ────────────────────────────────────────────────────────────────
  test 'the index renders the model through the usual collection view' do
    get '/admin/books'

    assert_response :success
    assert_select 'td', text: /The Hobbit/
    assert_select "a[href='/admin/books/hobbit']"
  end

  test 'the index filters and sorts from the URL like any other collection' do
    get '/admin/books?genre=scifi'

    assert_response :success
    assert_select 'td', text: /The Dispossessed/
    assert_select 'td', text: /The Hobbit/, count: 0
  end

  test 'the index searches' do
    get '/admin/books?q=Dispossessed'

    assert_response :success
    assert_select 'td', text: /The Dispossessed/
    assert_select 'td', text: /The Hobbit/, count: 0
  end

  # ── member ───────────────────────────────────────────────────────────────
  test 'a record is found by its identify_by value' do
    get '/admin/books/hobbit'

    assert_response :success
    assert_select 'dd', text: /The Hobbit/
  end

  test 'a record whose identify_by is the primary key is found by id' do
    get "/admin/authors/#{@tolkien.id}"

    assert_response :success
  end

  test 'an unknown record is a 404' do
    get '/admin/books/no-such-book'

    assert_response :not_found
  end

  # ── writes ───────────────────────────────────────────────────────────────
  test 'create saves the permitted attributes and redirects to the record' do
    assert_difference -> { Author.count } do
      post '/admin/authors', params: { author: { name: 'Ursula K. Le Guin', email: 'ursula@example.com' } }
    end

    author = Author.order(:id).last

    assert_redirected_to "/admin/authors/#{author.id}"
    assert_equal 'Ursula K. Le Guin', author.name
  end

  test 'an invalid create renders the form again' do
    assert_no_difference -> { Book.count } do
      post '/admin/books', params: { book: { title: '' } }
    end

    assert_response :unprocessable_entity
  end

  test 'update saves and redirects' do
    patch '/admin/books/hobbit', params: { book: { title: 'The Hobbit, revised' } }

    assert_redirected_to '/admin/books/hobbit'
    assert_equal 'The Hobbit, revised', @hobbit.reload.title
  end

  test 'destroy removes the record and returns to the index' do
    post '/toggle_admin'   # the playground ability withholds :destroy otherwise

    assert_difference -> { Author.count }, -1 do
      delete "/admin/authors/#{@tolkien.id}"
    end

    assert_redirected_to '/admin/authors'
  end

  # ── permissions ──────────────────────────────────────────────────────────
  test 'an action the ability withholds is refused even when posted directly' do
    delete "/admin/authors/#{@tolkien.id}"

    assert_response :forbidden
    assert Author.exists?(@tolkien.id)
  end

  test 'the action that runs is the one authorized, not the one that drew the button' do
    get '/admin/comments/new'

    assert_response :success

    post '/admin/comments', params: { comment: { body: 'Sneaked in.' } }

    assert_response :forbidden
  end

  test 'a column the ability hides stays hidden in the admin' do
    get '/admin/books'

    assert_response :success
    assert_select 'th', text: /Purchase price/, count: 0
  end
end
