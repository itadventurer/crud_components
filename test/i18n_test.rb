# frozen_string_literal: true

require 'test_helper'

# The gem ships default strings (en + de) for its built-in UI, auto-loaded from
# the engine's config/locales. German is the discriminator: its values differ
# from the inline `default:` fallbacks, so a passing assertion proves the files
# actually loaded rather than falling back.
class I18nTest < ActiveSupport::TestCase
  test 'English defaults are shipped' do
    assert_equal 'Delete', I18n.t('crud_components.actions.destroy')
    assert_equal 'Not set', I18n.t('crud_components.filter.not_set')
    assert_equal 'Yes', I18n.t('crud_components.filter.yes')
  end

  test 'German translations are shipped and override the English defaults' do
    I18n.with_locale(:de) do
      assert_equal 'Löschen', I18n.t('crud_components.actions.destroy')
      assert_equal 'Bearbeiten', I18n.t('crud_components.actions.edit')
      assert_equal 'Nicht gesetzt', I18n.t('crud_components.filter.not_set')
      assert_equal 'Nein', I18n.t('crud_components.filter.no')
    end
  end

  test 'the admin chrome is translated too' do
    assert_equal 'Show in app', I18n.t('crud_components.admin.show_in_app')
    assert_equal '2 records deleted.', I18n.t('crud_components.admin.notices.destroyed_selected', count: 2)

    I18n.with_locale(:de) do
      assert_equal 'In der App ansehen', I18n.t('crud_components.admin.show_in_app')
      assert_equal '2 Datensätze gelöscht.', I18n.t('crud_components.admin.notices.destroyed_selected', count: 2)
    end
  end
end
