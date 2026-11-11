class ReportScheduleRecipient < ApplicationRecord
  belongs_to :report_schedule
  belongs_to :user

  validates :user_id, uniqueness: { scope: :report_schedule_id }
end
