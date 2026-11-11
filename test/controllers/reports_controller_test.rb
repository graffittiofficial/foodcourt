require "test_helper"

class ReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = create_organization
    @restaurant = create_restaurant(name: "Reports Restaurant", organization: @organization)
    @staff = create_staff(email_address: "reports-staff@example.test", restaurants: [ @restaurant ])
  end

  test "staff can request multiple report categories for an authorized Restaurant" do
    sign_in_as(@staff)
    assert_enqueued_jobs 2, only: GenerateReportJob do
      post reports_path, params: {
        scope: "restaurant:#{@restaurant.id}",
        categories: %w[finance operations],
        start_date: "2026-10-01",
        end_date: "2026-10-31"
      }
    end

    assert_redirected_to reports_path
    reports = Report.where(requester: @staff).order(:category)
    assert_equal %w[finance operations], reports.pluck(:category)
    assert_equal [ @staff.id ], reports.first.report_deliveries.pluck(:user_id)
  end

  test "staff can view the shared Reports area" do
    sign_in_as(@staff)

    get reports_path

    assert_response :success
    assert_select "h1", "Reports"
  end

  test "restaurant staff cannot request an Organization-wide report" do
    sign_in_as(@staff)
    assert_no_difference "Report.count" do
      post reports_path, params: {
        scope: "organization:#{@organization.id}",
        categories: [ "finance" ],
        start_date: "2026-10-01",
        end_date: "2026-10-31"
      }
    end

    assert_response :not_found
  end

  test "on-demand date ranges cannot exceed one year" do
    sign_in_as(@staff)
    assert_no_difference "Report.count" do
      post reports_path, params: {
        scope: "restaurant:#{@restaurant.id}",
        categories: [ "finance" ],
        start_date: "2024-01-01",
        end_date: "2026-10-31"
      }
    end

    assert_response :unprocessable_entity
    assert_match "within one year", response.body
  end

  test "a user without current access cannot download a report" do
    report = Report.create!(
      requester: @staff,
      organization: @organization,
      restaurant: @restaurant,
      category: "operations",
      status: "completed",
      start_date: Date.current - 1.day,
      end_date: Date.current,
      expires_at: 30.days.from_now
    )
    outsider = create_staff(email_address: "outside@example.test", restaurants: [
      create_restaurant(name: "Other Restaurant")
    ])
    sign_in_as(outsider)

    get download_report_path(report)

    assert_response :not_found
  end
end
