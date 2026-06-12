Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = false
  config.action_controller.allow_forgery_protection = false
  config.action_dispatch.show_exceptions = :rescuable
  config.active_storage.service = :local
end
