class ExpireReportsJob < ApplicationJob
  def perform
    Report.completed.where(expires_at: ..Time.current).find_each do |report|
      report.file.purge if report.file.attached?
      report.update!(status: :expired)
    end
  end
end
