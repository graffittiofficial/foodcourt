class ReportScheduleRunnerJob < ApplicationJob
  def perform
    ReportSchedule.where(active: true).where(next_run_at: ..Time.current).find_each do |schedule|
      schedule.with_lock do
        next unless schedule.active? && schedule.next_run_at <= Time.current

        unless schedule.manageable_by?(schedule.user)
          Rails.logger.warn("Disabling report schedule #{schedule.id}: owner no longer has access.")
          schedule.update!(active: false)
          next
        end

        run_at = schedule.next_run_at
        start_date, end_date = schedule.previous_period_for(run_at)
        recipient_ids = schedule.recipients.select do |recipient|
          Reports::Access.can_access_scope?(
            recipient,
            organization: schedule.organization,
            restaurant: schedule.restaurant
          )
        end.map(&:id)

        schedule.categories.each do |category|
          report = schedule.reports.create!(
            requester: schedule.user,
            organization: schedule.organization,
            restaurant: schedule.restaurant,
            category: category,
            status: :queued,
            start_date: start_date,
            end_date: end_date
          )
          recipient_ids.each { |user_id| report.report_deliveries.create!(user_id: user_id) }
          Reports::EnqueueGeneration.call(report)
        end

        schedule.update!(next_run_at: schedule.next_run_after(run_at))
      end
    end
  end
end
