class DeliverReportEmailJob < ApplicationJob
  queue_as :mailers

  def perform(report_delivery_id)
    delivery = ReportDelivery.includes(:report, :user).find(report_delivery_id)
    return if delivery.emailed_at
    return unless delivery.report.downloadable? && delivery.report.accessible_by?(delivery.user)

    ReportsMailer.completed(delivery).deliver_now!
    delivery.update!(emailed_at: Time.current)
  end
end
