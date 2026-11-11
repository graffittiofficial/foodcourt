class Organization < ApplicationRecord
  TIME_ZONES = (ActiveSupport::TimeZone.all.map { |zone| zone.tzinfo.name } + [ "UTC" ]).uniq.freeze

  has_many :restaurants, dependent: :restrict_with_error
  has_many :organization_memberships, dependent: :delete_all
  has_many :organization_admins, through: :organization_memberships, source: :user
  has_many :invitations, dependent: :destroy
  has_many :report_schedules, dependent: :destroy

  validates :name, presence: true
  validates :time_zone, inclusion: { in: TIME_ZONES }
  after_update :reschedule_reports, if: :saved_change_to_time_zone?

  def active_admins
    organization_memberships.includes(:user)
  end

  private

  def reschedule_reports
    report_schedules.active.find_each do |schedule|
      schedule.update!(next_run_at: schedule.next_run_after(Time.current))
    end
  end
end
