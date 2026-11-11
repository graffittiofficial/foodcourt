require "test_helper"

class ReportScheduleTest < ActiveSupport::TestCase
  setup do
    @organization = create_organization
    @organization.update!(time_zone: "America/New_York")
    @restaurant = create_restaurant(name: "Schedule Restaurant", organization: @organization)
    @admin = User.create!(email_address: "schedule-admin@example.test", password: "password")
    OrganizationMembership.create!(organization: @organization, user: @admin)
  end

  test "weekly schedule runs Monday in the Organization time zone" do
    schedule = build_schedule(cadence: "weekly")
    next_run = schedule.next_run_after(Time.utc(2026, 10, 30, 13))

    assert_equal ActiveSupport::TimeZone["America/New_York"].local(2026, 11, 2, 8), next_run
  end

  test "daily schedule covers the previous local calendar day" do
    schedule = build_schedule(cadence: "daily")
    start_date, end_date = schedule.previous_period_for(Time.utc(2026, 11, 10, 13))

    assert_equal Date.new(2026, 11, 9), start_date
    assert_equal start_date, end_date
  end

  test "weekly schedule covers the previous Monday through Sunday" do
    schedule = build_schedule(cadence: "weekly")
    start_date, end_date = schedule.previous_period_for(Time.utc(2026, 11, 2, 13))

    assert_equal Date.new(2026, 10, 26), start_date
    assert_equal Date.new(2026, 11, 1), end_date
  end

  test "monthly schedule covers the previous complete calendar month" do
    schedule = build_schedule(cadence: "monthly")
    start_date, end_date = schedule.previous_period_for(Time.utc(2026, 11, 1, 13))

    assert_equal Date.new(2026, 10, 1), start_date
    assert_equal Date.new(2026, 10, 31), end_date
  end

  test "changing the Organization time zone recalculates active schedules" do
    schedule = build_schedule(cadence: "daily")
    schedule.report_schedule_categories.build(category: "finance")
    schedule.report_schedule_recipients.build(user: @admin)
    schedule.save!

    @organization.update!(time_zone: "America/Los_Angeles")

    assert_operator schedule.reload.next_run_at, :>, Time.current
    assert_equal 8, schedule.next_run_at.in_time_zone(@organization.time_zone).hour
  end

  private

  def build_schedule(cadence:)
    ReportSchedule.new(
      organization: @organization,
      restaurant: @restaurant,
      user: @admin,
      cadence: cadence,
      run_at: Time.zone.parse("08:00"),
      next_run_at: Time.current + 1.day
    )
  end
end
