# frozen_string_literal: true

require 'test_helper'

# `secret: true`: written through forms, never rendered back. The dummy
# Publisher declares a string `api_token` and a text `signing_key`.
class SecretAttributesTest < ActiveSupport::TestCase
  TOKEN = 'tok-3f9a1c'
  KEY = "-----BEGIN KEY-----\nabc\ndef\n-----END KEY-----"

  def setup
    @tor = Publisher.create!(name: 'Tor Books', slug: 'tor-books', api_token: TOKEN, signing_key: KEY)
  end

  def structure = CrudComponents::Structure.for(Publisher)

  # ── the field ──────────────────────────────────────────────────────────────
  test 'a secret filters and sorts by presence and is never searched' do
    field = structure.field(:api_token)

    assert_predicate field, :secret?
    assert_predicate field, :filterable?
    assert_equal :presence, field.filter_control
    assert_predicate field, :sortable?
    assert_nil field.search_spec_entry
    assert_not_includes structure.search_in_spec, :api_token
    assert_predicate structure.field(:signing_key), :multiline?
  end

  test 'the implicit fieldset lists secrets on display and form surfaces alike' do
    names = structure.fieldset_fields(structure.default_fieldset).map(&:name)

    assert_includes names, :api_token
    assert_includes names, :signing_key
  end

  test 'the presence filter splits set from not set, a value filter does nothing' do
    blank = Publisher.create!(name: 'Orbit', slug: 'orbit', api_token: '')
    Publisher.where(id: blank.id).update_all(api_token: '') # rubocop:disable Rails/SkipsModelValidations
    unset = Publisher.create!(name: 'Baen', slug: 'baen')
    filter = ->(value) { CrudComponents::Query.new(Publisher, { 'api_token' => value }).apply(Publisher.all) }

    assert_equal [@tor], filter.call('present').to_a
    assert_equal [blank, unset].sort_by(&:id), filter.call('absent').order(:id).to_a
    assert_equal 3, filter.call(TOKEN).count
    assert_not_includes filter.call('present').to_sql, TOKEN
  end

  test 'sorting by a secret orders by presence, never by value' do
    later = Publisher.create!(name: 'Ace', slug: 'ace', api_token: 'aaa-first-by-value')
    unset = Publisher.create!(name: 'Baen', slug: 'baen')
    sorted = lambda do |dir|
      CrudComponents::Query.new(Publisher, { 'sort' => 'api_token', 'dir' => dir }).apply(Publisher.all)
    end

    assert_equal unset, sorted.call('asc').first
    assert_equal [@tor, later].to_set, sorted.call('desc').first(2).to_set
    assert_match(/CASE WHEN/, sorted.call('asc').to_sql)
    assert_no_match(/ORDER BY "publishers"\."api_token"/, sorted.call('asc').to_sql)
  end

  test 'a filter or sort block on a secret is rejected, false is fine' do
    %i[filter sort].each do |facet|
      model = define_model(table: 'publishers') { attribute(:api_token, secret: true) { send(facet) { |s, _| s } } }
      error = assert_raises(CrudComponents::DefinitionError) { structure_of(model) }
      assert_match(/presence only/, error.message)
    end
    model = define_model(table: 'publishers') { attribute(:api_token, secret: true) { filter false } }

    assert_not_predicate structure_of(model).field(:api_token), :filterable?
  end

  test 'search_in cannot name a secret' do
    model = define_model(table: 'publishers') do
      attribute :api_token, secret: true
      search_in :name, :api_token
    end

    assert_raises(CrudComponents::DefinitionError) { structure_of(model) }
  end

  test 'the permit list carries the value and the remove box' do
    list = CrudComponents.permitted_attributes(Publisher, action: :update)

    assert_includes list, :api_token
    assert_includes list, :remove_api_token
    assert_includes list, :signing_key
    assert_includes list, :remove_signing_key
  end

  test 'a model without a form fieldset still offers its secrets in the form' do
    model = define_model(table: 'publishers') { attribute :api_token, secret: true }

    assert_includes structure_of(model).fieldset_fields(structure_of(model).form_fieldset).map(&:name), :api_token
    assert_includes CrudComponents.permitted_attributes(model), :remove_api_token
  end

  test 'a secret string column is not taken for the label' do
    model = define_model(table: 'reviews') { attribute :reviewer_name, secret: true }

    assert_nil structure_of(model).label_field_name
  end

  # ── writing ────────────────────────────────────────────────────────────────
  test 'an empty value keeps what is stored' do
    @tor.update!(api_token: '', signing_key: '')

    assert_equal TOKEN, @tor.reload.api_token
    assert_equal KEY, @tor.signing_key
  end

  test 'remove_<name> clears the stored value' do
    @tor.update!(api_token: '', remove_api_token: '1', remove_signing_key: '0')

    assert_nil @tor.reload.api_token
    assert_equal KEY, @tor.signing_key
  end

  test 'a new value wins over the remove box' do
    @tor.update!(api_token: 'fresh', remove_api_token: '1')

    assert_equal 'fresh', @tor.reload.api_token
  end

  test 'the remove box is answered only for secrets' do
    assert_respond_to @tor, :remove_api_token=
    assert_not @tor.remove_api_token
    assert_not_respond_to @tor, :remove_name=
    assert_raises(ActiveModel::UnknownAttributeError) { @tor.update(remove_name: '1') }
  end

  test 'the remove box does not outlive the save' do
    @tor.update!(remove_api_token: '1')
    @tor.update!(api_token: 'again')

    assert_equal 'again', @tor.reload.api_token
    assert_not @tor.remove_api_token
  end

  test 'a display fieldset that names a secret shows only whether it is set' do
    view = ApplicationController.new.tap { |c| c.request = ActionDispatch::TestRequest.create }.view_context
    model = define_model(table: 'publishers', name: 'Publisher') do
      attribute :api_token, secret: true
      fieldset :credentials, %i[name api_token]
    end
    record = model.find(@tor.id)
    html = view.crud_record(record, fieldset: :credentials)

    assert_includes html, 'aria-label="Set"'
    assert_not_includes html, TOKEN
    html = view.crud_record(model.create!(name: 'Baen', slug: 'baen'), fieldset: :credentials)

    assert_includes html, 'aria-label="Not set"'
  end

  # ── JSON ───────────────────────────────────────────────────────────────────
  test 'JSON leaves secrets out, presence included' do
    json = @tor.to_json

    assert_not_includes json, TOKEN
    assert_not_includes json, 'signing_key'
    assert_not_includes @tor.as_json(except: [:slug]).keys, 'api_token'
    assert_includes @tor.as_json.keys, 'name'
    assert_empty @tor.as_json.keys.grep(/api_token|signing_key/)
  end
end

class SecretAttributesIntegrationTest < ActionDispatch::IntegrationTest
  TOKEN = SecretAttributesTest::TOKEN
  KEY = SecretAttributesTest::KEY

  def setup
    @tor = Publisher.create!(name: 'Tor Books', slug: 'tor-books', api_token: TOKEN, signing_key: KEY)
  end

  def secrets_in_body? = response.body.include?(TOKEN) || response.body.include?('BEGIN KEY')

  test 'the app pages show whether a secret is set, never its value' do
    Publisher.create!(name: 'Baen', slug: 'baen')
    [publishers_path, publisher_path(@tor), '/admin/publishers', '/admin/publishers/tor-books'].each do |path|
      get path

      assert_response :success
      assert_not secrets_in_body?
      assert_select '[aria-label=Set]'
    end
    get '/admin/publishers'

    assert_select '[aria-label="Not set"]'
    assert_select 'select[name=api_token] option[value=present]', text: 'Set'
  end

  test 'the admin sorts and filters by presence' do
    Publisher.create!(name: 'Baen', slug: 'baen')
    get '/admin/publishers', params: { api_token: 'absent' }

    assert_select 'td', text: /Baen/
    assert_select 'td', text: /Tor Books/, count: 0

    get '/admin/publishers', params: { sort: 'api_token', dir: 'desc' }

    assert_response :success
    assert_operator response.body.index('Tor Books'), :<, response.body.index('Baen')
  end

  test 'the edit form starts empty and says a value is stored' do
    get edit_publisher_path(@tor)

    assert_response :success
    assert_not secrets_in_body?
    assert_select "input[type=password][name='publisher[api_token]'][autocomplete=new-password][value='']"
    assert_select "input[name='publisher[api_token]'][spellcheck=false]"
    assert_select "textarea[name='publisher[signing_key]'][autocomplete=new-password]", text: ''
    assert_select "input[type=checkbox][name='publisher[remove_api_token]']"
    assert_select '.form-text, .hint', text: /A value is stored/, count: 2
  end

  test 'a form for a publisher without a token offers no remove box' do
    @tor.update!(remove_api_token: '1', remove_signing_key: '1')
    get edit_publisher_path(@tor)

    assert_select "input[name='publisher[remove_api_token]'][type=checkbox]", count: 0
    assert_select '.form-text, .hint', text: /No value stored/, count: 2
  end

  test 'saving the form untouched keeps the secrets, the box clears one, a pasted key keeps its lines' do
    patch publisher_path(@tor), params: { publisher: { name: 'Tor', api_token: '', signing_key: '' } }

    assert_equal [TOKEN, KEY], @tor.reload.values_at(:api_token, :signing_key)

    new_key = "line one\r\nline two\r\n"
    patch publisher_path(@tor), params: { publisher: { api_token: '', remove_api_token: '1', signing_key: new_key } }

    assert_nil @tor.reload.api_token
    assert_equal new_key, @tor.signing_key
  end

  test 'the admin edit form behaves the same' do
    get '/admin/publishers/tor-books/edit'

    assert_response :success
    assert_not secrets_in_body?
    assert_select "input[type=password][name='publisher[api_token]'][value='']"

    patch '/admin/publishers/tor-books', params: { publisher: { name: 'Tor', api_token: '', signing_key: '' } }

    assert_equal [TOKEN, KEY], @tor.reload.values_at(:api_token, :signing_key)

    patch '/admin/publishers/tor-books', params: { publisher: { signing_key: '', remove_signing_key: '1' } }

    assert_nil @tor.reload.signing_key
    assert_equal TOKEN, @tor.api_token
  end

  test 'a secret value as a filter param in the admin changes nothing' do
    get '/admin/publishers', params: { api_token: TOKEN }

    assert_response :success
    assert_select 'td', text: /Tor Books/
  end
end
