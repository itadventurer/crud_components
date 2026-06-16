Rails.application.configure do
  # Minimal production config for the deployed live demo (the app is otherwise a
  # test fixture). application.rb already clears config.hosts and sets a
  # throwaway secret_key_base, so nothing else is needed to boot.
  config.eager_load = true
  config.consider_all_requests_local = false   # override application.rb: no backtrace pages in public
  config.active_storage.service = :local

  # Log to stdout for containers.
  config.logger = ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new($stdout))
  config.log_level = ENV.fetch('LOG_LEVEL', 'info')

  config.assume_ssl = true     # behind a TLS-terminating ingress
  config.force_ssl = false     # …which already handles TLS, so don't redirect-loop
end
