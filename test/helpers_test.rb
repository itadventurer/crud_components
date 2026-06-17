require 'test_helper'

class HelpersTest < ActiveSupport::TestCase
  def view = @view ||= Class.new { include CrudComponents::Helpers }.new

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
end
