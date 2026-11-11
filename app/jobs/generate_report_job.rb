require "stringio"

class GenerateReportJob < ApplicationJob
  queue_as :reports

  def perform(report_id)
    report = Report.find(report_id)
    return if report.completed? || report.expired?

    unless report.accessible_by?(report.requester)
      report.update!(status: :failed, error_message: "The requester no longer has access to this report.")
      return
    end

    report.update!(status: :processing, error_message: nil)
    report.file.attach(
      io: StringIO.new(report.generate_csv),
      filename: report.filename,
      content_type: "text/csv"
    )
    report.update!(status: :completed, completed_at: Time.current, expires_at: 30.days.from_now)
    report.report_deliveries.find_each { |delivery| DeliverReportEmailJob.perform_later(delivery.id) }
  rescue StandardError => error
    Rails.logger.error("Report generation failed for report #{report_id}: #{error.class}: #{error.message}")
    report&.file&.purge
    report&.update!(status: :failed, error_message: "Report generation failed.")
    raise
  end
end
