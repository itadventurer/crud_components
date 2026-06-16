Rails.application.configure do
  config.enable_reloading = true
  config.eager_load = false
  config.consider_all_requests_local = true
  config.active_storage.service = :local

  # The deployed live demo runs this env with DEMO_RESET set (see
  # config/initializers/demo_reset.rb). Allow the host it's served on and stop
  # code reloading so the long-running reset thread is stable.
  if ENV['DEMO_RESET'].present?
    config.hosts.clear
    config.enable_reloading = false
  end
end
