require "test_helper"

class ReportScheduleRunnerJobTest < ActiveJob::TestCase
  setup do
    @organization = create_organization
    @organization.update!(time_zone: "America/New_York")
    @restaurant = create_restaurant(name: "Scheduled Restaurant", organization: @organization)
    @staff = create_staff(email_address: "scheduled-staff@example.test", restaurants: [ @restaurant ])
  end

  test "queues separate reports for scheduled categories and advances the next run" do
    zone = ActiveSupport::TimeZone[@organization.time_zone]
    due_at = zone.local(Time.current.in_time_zone(zone).year, Time.current.in_time_zone(zone).month,
      Time.current.in_time_zone(zone).day, 0)
    schedule = ReportSchedule.create!(
      organization: @organization,
      restaurant: @restaurant,
      user: @staff,
      cadence: "daily",
      run_at: Time.zone.parse("00:00"),
      next_run_at: due_at,
      report_schedule_categories: [
        ReportScheduleCategory.new(category: "finance"),
        ReportScheduleCategory.new(category: "operations")
      ],
      report_schedule_recipients: [ ReportScheduleRecipient.new(user: @staff) ]
    )

    assert_enqueued_jobs 2, only: GenerateReportJob do
      ReportScheduleRunnerJob.perform_now
    end

    reports = schedule.reports.order(:category)
    assert_equal %w[finance operations], reports.pluck(:category)
    assert_equal [ due_at.to_date - 1 ], reports.pluck(:start_date).uniq
    assert_equal [ due_at.to_date - 1 ], reports.pluck(:end_date).uniq
    assert_operator schedule.reload.next_run_at, :>, Time.current
    assert_equal [ @staff.id ], reports.first.report_deliveries.pluck(:user_id)
  end
end
