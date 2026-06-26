require 'test_helper'

class HelpersTest < ActiveSupport::TestCase
  def view = @view ||= Class.new { include CrudComponents::Helpers }.new

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
