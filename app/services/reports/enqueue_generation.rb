module Reports
  class EnqueueGeneration
    def self.call(report)
      job = GenerateReportJob.perform_later(report.id)
      return true if job&.successfully_enqueued?

      fail_report(report, "The report could not be queued.")
      false
    rescue StandardError => error
      Rails.logger.error("Could not enqueue report #{report.id}: #{error.class}: #{error.message}")
      fail_report(report, "The report could not be queued.")
      false
    end

    def self.fail_report(report, message)
      Rails.logger.error("Report #{report.id} failed before generation: #{message}")
      report.update!(status: :failed, error_message: message)
    end
    private_class_method :fail_report
  end
end
