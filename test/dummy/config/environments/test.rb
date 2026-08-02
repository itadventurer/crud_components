Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = false
  config.action_controller.allow_forgery_protection = false
  config.action_dispatch.show_exceptions = :rescuable
  config.active_storage.service = :local
  # Keeps ActiveStorage::AnalyzeJob off a background thread, where it would check
  # out its own DB connection and collide with fixture teardown.
  config.active_job.queue_adapter = :test
end
