require 'test_helper'
require 'open3'

# The Gemfile brings ruby-vips, but the native libvips is optional — the demo
# image ships without it. Booting the dummy app there must degrade to variant-
# less attachments, not raise.
class MissingLibvipsBootTest < ActiveSupport::TestCase
  test 'the dummy app boots without the native libvips' do
    stub = File.expand_path('support/no_libvips.rb', __dir__)
    environment = File.expand_path('dummy/config/environment.rb', __dir__)

    output, status = Open3.capture2e(
      { 'RAILS_ENV' => 'test' },
      RbConfig.ruby, '-r', stub, '-e', "require #{environment.dump}"
    )

    assert_predicate status, :success?, "booting without libvips failed:\n#{output}"
  end
end
