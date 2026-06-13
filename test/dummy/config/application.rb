require_relative 'boot'

require 'rails'
require 'active_record/railtie'
require 'active_storage/engine'
require 'action_controller/railtie'
require 'action_view/railtie'

require 'crud_components'
require 'kaminari' # playground only: powers the pagination demo (PaginationController)

module Dummy
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f
    config.root = File.expand_path('..', __dir__)
    config.eager_load = false
    config.hosts.clear
    config.secret_key_base = 'dummy-secret-key-base-for-the-crud-components-playground'
    config.consider_all_requests_local = true
    config.active_storage.service = :local
    config.active_record.timestamped_migrations = false
    config.action_dispatch.show_exceptions = :rescuable if Rails.env.test?
  end
end
