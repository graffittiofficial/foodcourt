class ReportDelivery < ApplicationRecord
  belongs_to :report
  belongs_to :user

  validates :user_id, uniqueness: { scope: :report_id }
end
