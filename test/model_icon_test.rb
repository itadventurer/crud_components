require 'test_helper'

class ModelIconTest < ActiveSupport::TestCase
  def icon_of(model) = CrudComponents::Structure.for(model).icon

  test 'explicit icon declaration wins over the name-based map' do
    # Publisher declares `icon 'building'`; even if the map said otherwise, the
    # declaration is authoritative.
    CrudComponents.config.model_icons['publisher'] = 'shop'
    assert_equal 'building', icon_of(Publisher)
  ensure
    CrudComponents.config.model_icons['publisher'] = 'building'
  end

  test 'undeclared model gets the name-based guess (keyed by model_name.element)' do
    assert_equal 'book', icon_of(Book)        # 'book' => 'book'
    assert_equal 'person', icon_of(Author)    # 'author' => 'person' — a zero-config model
    assert_equal 'building', icon_of(define_model(name: 'Organization'))
  end

  test 'unmapped, undeclared model falls back to model_fallback_icon (nil by default)' do
    sprocket = define_model(name: 'Sprocket')
    assert_nil icon_of(sprocket)
    CrudComponents.config.model_fallback_icon = 'box'
    assert_equal 'box', icon_of(sprocket)
    assert_equal 'book', icon_of(Book), 'a mapped model ignores the fallback'
  ensure
    CrudComponents.config.model_fallback_icon = nil
  end

  test 'an app can register an icon for its own model via config' do
    CrudComponents.config.model_icons['sprocket'] = 'gear-wide'
    assert_equal 'gear-wide', icon_of(define_model(name: 'Sprocket'))
  ensure
    CrudComponents.config.model_icons.delete('sprocket')
  end

  test 'declaring icon twice raises' do
    error = assert_raises(CrudComponents::DefinitionError) do
      structure_of(define_model(name: 'Twice') { icon 'a'; icon 'b' })
    end
    assert_match(/icon declared twice/, error.message)
  end
end
