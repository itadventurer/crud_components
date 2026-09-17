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
  test 'a secret is neither filtered, sorted nor searched' do
    field = structure.field(:api_token)

    assert_predicate field, :secret?
    assert_not_predicate field, :filterable?
    assert_not_predicate field, :sortable?
    assert_nil field.search_spec_entry
    assert_predicate structure.field(:signing_key), :multiline?
  end

  test 'the implicit fieldset leaves secrets out of display and keeps them in forms' do
    display = structure.fieldset_fields(structure.default_fieldset).map(&:name)
    form = structure.fieldset_fields(structure.default_fieldset, form: true).map(&:name)

    assert_not_includes display, :api_token
    assert_not_includes display, :signing_key
    assert_includes form, :api_token
    assert_includes form, :signing_key
  end

  test 'a filter param naming a secret is inert' do
    query = CrudComponents::Query.new(Publisher, { 'api_token' => 'nope' }, fieldset: :default)

    assert_equal [@tor], query.apply(Publisher.all).to_a
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

    assert_includes structure_of(model).fieldset_fields(structure_of(model).form_fieldset, form: true).map(&:name),
                    :api_token
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

    assert_includes html, 'Set'
    assert_not_includes html, TOKEN
  end

  # ── JSON ───────────────────────────────────────────────────────────────────
  test 'JSON leaves secrets out' do
    json = @tor.to_json

    assert_not_includes json, TOKEN
    assert_not_includes json, 'signing_key'
    assert_not_includes @tor.as_json(except: [:slug]).keys, 'api_token'
    assert_includes @tor.as_json.keys, 'name'
  end
end

class SecretAttributesIntegrationTest < ActionDispatch::IntegrationTest
  TOKEN = SecretAttributesTest::TOKEN
  KEY = SecretAttributesTest::KEY

  def setup
    @tor = Publisher.create!(name: 'Tor Books', slug: 'tor-books', api_token: TOKEN, signing_key: KEY)
  end

  def secrets_in_body? = response.body.include?(TOKEN) || response.body.include?('BEGIN KEY')

  test 'the app pages never show a secret' do
    [publishers_path, publisher_path(@tor), '/admin/publishers', '/admin/publishers/tor-books'].each do |path|
      get path

      assert_response :success
      assert_not secrets_in_body?
    end
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

  test 'a secret named as a filter or sort param in the admin changes nothing' do
    get '/admin/publishers', params: { api_token: 'nope', sort: 'api_token' }

    assert_response :success
    assert_select 'td', text: /Tor Books/
  end
end
