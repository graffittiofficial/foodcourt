class ReportScheduleCategory < ApplicationRecord
  belongs_to :report_schedule

  validates :category, inclusion: { in: Report::CATEGORIES.values }
  validates :category, uniqueness: { scope: :report_schedule_id }
end
