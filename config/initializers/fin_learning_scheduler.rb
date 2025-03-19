# Skip in test environment
if defined?(Rails::Server) && !Rails.env.test?
  Rails.application.config.after_initialize do
    # Schedule the Fin learning job to run weekly
    FinLearningJob.set(cron: "0 0 * * 0").perform_later # Sunday at midnight

    Rails.logger.info "Scheduled weekly Fin learning job"
  end
end
