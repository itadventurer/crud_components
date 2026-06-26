require 'test_helper'

class HelpersTest < ActiveSupport::TestCase
  def view = @view ||= Class.new { include CrudComponents::Helpers }.new

  def tag_view
    @tag_view ||= Class.new do
      include ActionView::Helpers::TagHelper
      include CrudComponents::Helpers
    end.new
  end

  test 'crud_model_icon_name resolves a model from a record, class or relation' do
    pub = Publisher.create!(name: 'Tor', slug: 'tor-icon')
    assert_equal 'building', view.crud_model_icon_name(pub)           # record (explicit icon)
    assert_equal 'building', view.crud_model_icon_name(Publisher)     # class
    assert_equal 'building', view.crud_model_icon_name(Publisher.all) # relation
    assert_equal 'book', view.crud_model_icon_name(Book)              # name-based guess
    assert_nil view.crud_model_icon_name(Manual)                      # unmapped, undeclared → nil
  ensure
    pub&.destroy
  end

  test 'crud_model_icon builds the <i> tag (prefix + name), nil when no icon' do
    html = tag_view.crud_model_icon(Publisher, class: 'me-1')
    assert_includes html, 'bi bi-building'
    assert_includes html, 'me-1'
    assert_includes html, 'aria-hidden="true"'
    assert_nil tag_view.crud_model_icon(Manual)   # no icon → no markup
  end

  # #3: an association column can re-title the associated record per context.
  test 'crud_association_label uses a per-column label: callable, else the default label' do
    pub = Publisher.create!(name: 'Tor', slug: 'tor-assoc-label')
    field = Struct.new(:options)
    with_label = field.new({ label: ->(p) { "P:#{p.name}" } })
    no_label   = field.new({})
    assert_equal 'P:Tor', view.crud_association_label(with_label, pub)
    assert_equal 'Tor',   view.crud_association_label(no_label, pub)   # default == crud_label
  ensure
    pub&.destroy
  end

  test 'crud_file_icon maps a known extension via config.file_icons, else the fallback' do
    assert_equal 'filetype-pdf', view.crud_file_icon('report.PDF')   # case-insensitive, known
    assert_equal 'filetype-md',  view.crud_file_icon('README.md')
    assert_equal 'filetype-yml', view.crud_file_icon('config.yaml')  # full-name map handles the alias
    assert_equal 'file-earmark-zip', view.crud_file_icon('a.zip')    # …and the non-filetype glyph
    assert_equal 'file-earmark-text', view.crud_file_icon('mystery.xyz')  # unmapped → fallback
    assert_equal 'file-earmark-text', view.crud_file_icon('noext')
  end

  test 'crud_file_icon honors config (the map and the fallback)' do
    cfg = CrudComponents.config
    icons, fallback = cfg.file_icons, cfg.file_fallback_icon
    cfg.file_icons = { 'md' => 'ext-md' }
    cfg.file_fallback_icon = 'file'

    assert_equal 'ext-md', view.crud_file_icon('readme.md')
    assert_equal 'file', view.crud_file_icon('a.pdf')   # pdf no longer mapped
  ensure
    cfg.file_icons = icons
    cfg.file_fallback_icon = fallback
  end

  test 'bundled_css ships the column-picker float styles' do
    css = CrudComponents.bundled_css
    assert_includes css, '.crud-column-picker-menu'
    assert_includes css, 'position: absolute'
  end

  test 'crud_components_styles inlines the stylesheet as a <style> tag' do
    v = Class.new do
      include ActionView::Helpers::TagHelper
      include CrudComponents::Helpers
    end.new
    html = v.crud_components_styles
    assert_includes html, '<style'
    assert_includes html, 'crud-column-picker-menu'
  end
end
