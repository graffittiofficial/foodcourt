class ReportsMailer < ApplicationMailer
  def completed(delivery)
    @report = delivery.report
    @report_url = Rails.application.routes.url_helpers.report_url(
      @report,
      host: Rails.application.config.action_mailer.default_url_options.fetch(:host)
    )
    attachments[@report.filename] = @report.file.download

    mail(to: delivery.user.email_address, subject: "Your Foodcourt report is ready")
  end
end
