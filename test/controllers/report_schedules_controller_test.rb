require "test_helper"

class ReportSchedulesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = create_organization
    @restaurant = create_restaurant(name: "Schedule Controller Restaurant", organization: @organization)
    @staff = create_staff(email_address: "schedule-controller@example.test", restaurants: [ @restaurant ])
  end

  test "restaurant staff can create, edit, pause, and resume a schedule in their scope" do
    sign_in_as(@staff)
    post report_schedules_path, params: schedule_params

    schedule = ReportSchedule.order(:id).last
    assert_redirected_to reports_path
    assert_equal @restaurant, schedule.restaurant
    assert_equal [ "finance" ], schedule.categories

    patch report_schedule_path(schedule), params: schedule_params.merge(
      categories: [ "operations" ],
      cadence: "weekly"
    )
    assert_redirected_to reports_path
    assert_equal "weekly", schedule.reload.cadence
    assert_equal [ "operations" ], schedule.categories

    patch pause_report_schedule_path(schedule)
    assert_not schedule.reload.active?

    patch resume_report_schedule_path(schedule)
    assert schedule.reload.active?
  end

  test "staff cannot add an email recipient outside the selected scope" do
    outsider = create_staff(email_address: "schedule-outsider@example.test", restaurants: [
      create_restaurant(name: "Out of scope")
    ])
    sign_in_as(@staff)
    assert_no_difference "ReportSchedule.count" do
      post report_schedules_path, params: schedule_params.merge(recipient_ids: [ outsider.id ])
    end

    assert_redirected_to reports_path
    assert_match "current access", flash[:alert]
  end

  test "invalid schedule times are rejected without creating a schedule" do
    sign_in_as(@staff)
    assert_no_difference "ReportSchedule.count" do
      post report_schedules_path, params: schedule_params.merge(run_at: "99:99")
    end

    assert_redirected_to reports_path
    assert_match "valid cadence and local run time", flash[:alert]
  end

  private

  def schedule_params
    {
      scope: "restaurant:#{@restaurant.id}",
      categories: [ "finance" ],
      cadence: "daily",
      run_at: "08:00",
      recipient_ids: [ @staff.id ]
    }
  end
end
