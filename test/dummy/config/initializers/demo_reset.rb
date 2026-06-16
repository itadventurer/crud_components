# Live-demo only (enabled with DEMO_RESET=1): wipe + reseed the database every
# few minutes so anything visitors do reverts on its own. Self-contained — a
# background thread, no external cron. The DB is ephemeral SQLite, so a restart
# also resets it; this just keeps a long-running machine fresh.
if ENV['DEMO_RESET'].present? && !defined?(Rails::Console) && $PROGRAM_NAME.exclude?('rake')
  interval = Integer(ENV.fetch('DEMO_RESET_SECONDS', 600))

  Rails.application.config.after_initialize do
    Thread.new do
      loop do
        sleep interval
        begin
          ActiveRecord::Base.connection_pool.with_connection do
            load Rails.root.join('db/seeds.rb')
          end
          Rails.logger.info('[demo_reset] reseeded')
        rescue StandardError => e
          Rails.logger.error("[demo_reset] #{e.class}: #{e.message}")
        end
      end
    end
  end
end
