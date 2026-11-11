require "sidekiq/cron/job"

redis_url = if Rails.env.production?
  ENV.fetch("REDIS_URL")
else
  ENV.fetch("REDIS_URL", "redis://127.0.0.1:6379/0")
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url }
end

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }
  config.on(:startup) do
    Sidekiq::Cron::Job.create(
      name: "Run due report schedules",
      cron: "* * * * *",
      class: "ReportScheduleRunnerJob",
      queue: "default"
    )
    Sidekiq::Cron::Job.create(
      name: "Expire generated reports",
      cron: "0 3 * * *",
      class: "ExpireReportsJob",
      queue: "default"
    )
  end
end
