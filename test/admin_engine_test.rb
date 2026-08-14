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
  test 'the default gate asks the ability, and turns away who it denies' do
    with_admin_config do
      get '/admin'

      assert_response :forbidden
    end
  end

  test 'the default gate lets in whoever the ability grants the action' do
    with_admin_config do
      post '/toggle_admin'
      get '/admin'

      assert_response :success
    end
  end

  test 'a gate block runs in the controller and can turn a request away' do
    with_admin_config do |config|
      config.auth_with { head :forbidden }
      get '/admin'

      assert_response :forbidden
    end
  end

  test 'a gate block that lets the request through renders' do
    with_admin_config do |config|
      config.auth_with { nil }
      get '/admin'

      assert_response :success
    end
  end

  test 'auth_with :none serves without asking anything' do
    with_admin_config do |config|
      config.auth_with :none
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

  # `if: :manage` on purchase_price is denied here; the admin's own action
  # (:index for this test) stands in for it — in the views too.
  test 'the admin action answers for a finer one the rendering asks about' do
    with_admin_config do |config|
      config.auth_with :cancan, action: :index
      get '/admin/books?fieldset=catalog'

      assert_response :success
      assert_select 'th', text: /Purchase price/
    end
  end

  # ── chrome ───────────────────────────────────────────────────────────────
  test 'every page carries the sidebar, with the current model marked' do
    get '/admin/books'

    assert_response :success
    assert_select '.crud-admin-nav a.active', text: /Book/
    assert_select ".crud-admin-nav a[href='/admin/publishers']"
    assert_select '.crud-admin-nav a.active', count: 1
  end

  test 'the sidebar groups models under their declared group' do
    get '/admin'

    assert_response :success
    assert_select '.crud-admin-nav', text: /Custom properties/
  end

  test 'the dashboard counts the records' do
    get '/admin'

    assert_response :success
    assert_select '.card', text: /Publisher\s*1/
  end

  test 'counts can be switched off' do
    with_admin_config do |config|
      config.auth_with :none
      config.counts = false
      get '/admin'

      assert_response :success
      assert_select '.card .badge', count: 0
    end
  end

  test 'a model the ability will not let you index is absent from the navigation' do
    get '/admin'

    assert_response :success
    assert_select "a[href='/admin/property_definitions']", count: 0

    post '/toggle_admin'
    get '/admin'

    assert_select "a[href='/admin/property_definitions']"
  end

  test 'the bundled shell brings its own Bootstrap' do
    get '/admin'

    assert_response :success
    assert_select "link[href*='bootstrap']", 2
  end

  test 'the admin renders in the host layout when configured to' do
    with_admin_config do |config|
      config.auth_with :none
      config.layout = 'host_chrome'
      get '/admin'

      assert_response :success
      assert_select '#host-chrome'
      assert_select '.crud-admin-nav', count: 0
    end
  end

  # ── show in app ──────────────────────────────────────────────────────────
  test 'a record links to the host application page for it' do
    get '/admin/books/hobbit'

    assert_response :success
    assert_select "a[href='/books/hobbit']"
  end

  test 'every row links to its host application page' do
    get '/admin/books'

    assert_response :success
    assert_select "a[href='/books/hobbit'][title=?]", 'Show in app'
  end

  test 'no host route means no link, not a broken one' do
    Comment.create!(commentable: @hobbit, body: 'No route to me.')
    get '/admin/comments'

    assert_response :success
    assert_select 'a[title=?]', 'Show in app', count: 0
  end

  test 'a declared app_path wins over the conventional route' do
    document = Document.create!(title: 'The Manual', body: 'Body.')
    get "/admin/documents/#{document.id}"

    assert_response :success
    assert_select "a[href=?]", "/documents##{ActionView::RecordIdentifier.dom_id(document)}"
  end

  # ── the way back ─────────────────────────────────────────────────────────
  test 'an application page can link into the admin' do
    get '/books/hobbit'

    assert_response :success
    assert_select "a[href='/admin/books/hobbit/edit']", text: 'Edit in admin'
  end

  test 'crud_admin_path is nil for an action the model does not offer' do
    value = PropertyValue.create!(property_definition: PropertyDefinition.create!(key: 'isbn', flavor: 'string'),
                                  subject: @hobbit, value: '123')

    assert_equal "/admin/property_values/#{value.id}", CrudComponents::Admin.path_for(value, :show)
    assert_nil CrudComponents::Admin.path_for(value, :edit)
    assert_nil CrudComponents::Admin.path_for(@hobbit, :no_such_action)
  end

  # ── nested indexes ───────────────────────────────────────────────────────
  test 'an owner has a nested index for each to-many association' do
    get "/admin/publishers/tor-books/books"

    assert_response :success
    assert_select 'td', text: /The Hobbit/
  end

  test "a nested index shows only the owner's records" do
    other = Publisher.create!(name: 'Ace', slug: 'ace')
    Book.create!(title: 'A Wizard of Earthsea', slug: 'earthsea', publisher: other)

    get '/admin/publishers/tor-books/books'

    assert_response :success
    assert_select 'td', text: /A Wizard of Earthsea/, count: 0
  end

  test 'a habtm association gets a nested index too' do
    get "/admin/authors/#{@tolkien.id}/books"

    assert_response :success
    assert_select 'td', text: /The Hobbit/
    assert_select 'td', text: /The Dispossessed/, count: 0
  end

  test 'an unknown owner is a 404' do
    get '/admin/publishers/no-such-publisher/books'

    assert_response :not_found
  end

  # ── bulk destroy ─────────────────────────────────────────────────────────
  test 'the ticked rows are deleted' do
    post '/toggle_admin'
    other = Author.create!(name: 'Ursula K. Le Guin', email: 'ursula@example.com')

    assert_difference -> { Author.count }, -2 do
      delete '/admin/authors/destroy_selected', params: { selected: [@tolkien.id, other.id] }
    end

    assert_redirected_to '/admin/authors'
  end

  test 'a bulk delete the ability forbids is refused' do
    assert_no_difference -> { Author.count } do
      delete '/admin/authors/destroy_selected', params: { selected: [@tolkien.id] }
    end

    assert_response :forbidden
  end

  test 'a read-only model has no bulk delete route' do
    delete '/admin/property_values/destroy_selected'

    assert_response :not_found
  end

  # ── delete confirmation ──────────────────────────────────────────────────
  test 'the delete button leads to a confirmation page, not straight to a DELETE' do
    post '/toggle_admin'
    get '/admin/books/hobbit'

    assert_response :success
    assert_select "a[href='/admin/books/hobbit/delete']"
  end

  test 'the confirmation page counts what goes with the record' do
    post '/toggle_admin'
    Review.create!(book: @hobbit, rating: 4, reviewer_name: 'Ada', body: 'A classic.')
    Review.create!(book: @hobbit, rating: 5, reviewer_name: 'Bob', body: 'Also good.')

    get '/admin/books/hobbit/delete'

    assert_response :success
    assert_select 'li', text: /2\s+Review/i
  end

  test 'the confirmation page says so when nothing else depends on the record' do
    post '/toggle_admin'
    get "/admin/authors/#{@tolkien.id}/delete"

    assert_response :success
    assert_select 'p', text: /Nothing else depends/
  end

  test 'the confirmation page posts the real DELETE' do
    post '/toggle_admin'
    get '/admin/books/hobbit/delete'

    assert_response :success
    assert_select "form[action='/admin/books/hobbit'] input[name=_method][value=delete]"
  end

  test 'a read-only model has no confirmation page either' do
    get '/admin/property_values/1/delete'

    assert_response :not_found
  end

  test 'the confirmation page is refused when the ability withholds destroy' do
    get '/admin/books/hobbit/delete'

    assert_response :forbidden
  end
end
