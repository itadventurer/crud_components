require 'test_helper'

# Name-gated smart renderers: a column named email/url/website/link renders as a
# link by default. Gated on the name (not the value), so it's predictable.
class SemanticRenderersTest < ActiveSupport::TestCase
  test 'SemanticRenderer maps email/url-ish names, leaves the rest alone' do
    r = ->(name) { CrudComponents::SemanticRenderer.renderer_for(name) }
    assert_equal :email, r.call('email')
    assert_equal :email, r.call('work_email')
    assert_equal :url, r.call('url')
    assert_equal :url, r.call('website')
    assert_equal :url, r.call('link')
    assert_nil r.call('name')
    assert_nil r.call('description')   # not auto-linked just because it may hold a URL
  end

  test 'a string column named email/url gets the smart renderer; others stay :string' do
    renderer = ->(model, col) { CrudComponents::Structure.for(model).field(col).renderer }
    assert_equal :email, renderer.call(Author, :email)
    assert_equal :string, renderer.call(Author, :name)
  end

  test 'as: still overrides the name-based default' do
    forced = CrudComponents::Fields::StringField.new(:email, Author, { as: :string }, {})
    assert_equal :string, forced.renderer
  end
end

class SemanticRenderersIntegrationTest < ActionDispatch::IntegrationTest
  test 'a column named email renders as a mailto link (zero-config Author table)' do
    Author.create!(name: 'Linkme', email: 'link@me.example')
    get authors_path
    assert_response :success
    assert_select "a[href='mailto:link@me.example']", text: /link@me\.example/
  end
end
