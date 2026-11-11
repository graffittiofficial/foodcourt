class ReportSchedule < ApplicationRecord
  CADENCES = {
    daily: "daily",
    weekly: "weekly",
    monthly: "monthly"
  }.freeze

  belongs_to :organization
  belongs_to :restaurant, optional: true
  belongs_to :user
  has_many :report_schedule_categories, dependent: :destroy
  has_many :report_schedule_recipients, dependent: :destroy
  has_many :recipients, through: :report_schedule_recipients, source: :user
  has_many :reports, dependent: :nullify

  enum :cadence, CADENCES, validate: true

  scope :active, -> { where(active: true) }

  validates :run_at, :next_run_at, presence: true
  validate :restaurant_belongs_to_organization
  validate :has_valid_categories
  validate :has_valid_recipients

  def categories
    report_schedule_categories.pluck(:category)
  end

  def next_run_after(time)
    zone = ActiveSupport::TimeZone[organization.time_zone]
    local_time = time.in_time_zone(zone)
    hour = run_at.hour
    minute = run_at.min
    date = case cadence
    when "daily"
      local_time.to_date
    when "weekly"
      local_time.to_date + ((1 - local_time.wday) % 7)
    when "monthly"
      local_time.to_date.beginning_of_month
    else
      raise ArgumentError, "Unsupported report schedule cadence: #{cadence.inspect}"
    end

    candidate = zone.local(date.year, date.month, date.day, hour, minute)
    candidate = next_occurrence(candidate) while candidate <= local_time
    candidate
  end

  def previous_period_for(run_time)
    date = run_time.in_time_zone(organization.time_zone).to_date
    case cadence
    when "daily"
      [ date - 1.day, date - 1.day ]
    when "weekly"
      [ date - 7.days, date - 1.day ]
    when "monthly"
      previous_month = date - 1.month
      [ previous_month.beginning_of_month, previous_month.end_of_month ]
    else
      raise ArgumentError, "Unsupported report schedule cadence: #{cadence.inspect}"
    end
  end

  def manageable_by?(user)
    Reports::Access.can_access_scope?(user, organization: organization, restaurant: restaurant)
  end

  private

  def next_occurrence(candidate)
    case cadence
    when "daily"
      candidate + 1.day
    when "weekly"
      candidate + 1.week
    when "monthly"
      next_month = candidate.to_date + 1.month
      ActiveSupport::TimeZone[organization.time_zone].local(
        next_month.year, next_month.month, next_month.day, run_at.hour, run_at.min
      )
    else
      raise ArgumentError, "Unsupported report schedule cadence: #{cadence.inspect}"
    end
  end

  def restaurant_belongs_to_organization
    return unless restaurant && organization_id != restaurant.organization_id

    errors.add(:restaurant, "must belong to the selected Organization")
  end

  def has_valid_categories
    return if report_schedule_categories.any? { |selection| Report.categories.key?(selection.category) }

    errors.add(:base, "Select at least one valid report category.")
  end

  def has_valid_recipients
    return if report_schedule_recipients.any?

    errors.add(:base, "Select at least one email recipient.")
  end
end
