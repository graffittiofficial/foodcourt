require "test_helper"
require "stringio"

class GenerateReportJobTest < ActiveJob::TestCase
  setup do
    @organization = create_organization
    @restaurant = create_restaurant(name: "Job Restaurant", organization: @organization)
    @user = create_staff(email_address: "job-staff@example.test", restaurants: [ @restaurant ])
  end

  test "generates a CSV, marks the report complete, and queues delivery" do
    report = create_report

    assert_enqueued_with(job: DeliverReportEmailJob) do
      GenerateReportJob.perform_now(report.id)
    end

    assert report.reload.completed?
    assert report.file.attached?
    assert_equal 30.days.from_now.to_date, report.expires_at.to_date
  end

  test "does not generate a report after the requester loses access" do
    report = create_report
    @restaurant.restaurant_memberships.find_by!(user: @user).destroy!

    GenerateReportJob.perform_now(report.id)

    assert report.reload.failed?
    assert_not report.file.attached?
  end

  test "failed queueing is recorded on the report" do
    report = create_report

    with_rejected_enqueue do
      assert_not Reports::EnqueueGeneration.call(report)
    end

    assert report.reload.failed?
    assert_equal "The report could not be queued.", report.error_message
  end

  test "emails an attached CSV only while the recipient retains access" do
    report = create_report
    report.update!(status: :completed, completed_at: Time.current, expires_at: 30.days.from_now)
    report.file.attach(io: StringIO.new("Order ID\r\n"), filename: report.filename, content_type: "text/csv")
    delivery = report.report_deliveries.first

    assert_difference "ActionMailer::Base.deliveries.size", 1 do
      DeliverReportEmailJob.perform_now(delivery.id)
    end
    assert_equal Time.current.to_date, delivery.reload.emailed_at.to_date
    assert_equal "job-staff@example.test", ActionMailer::Base.deliveries.last.to.first
    assert_equal "text/csv", ActionMailer::Base.deliveries.last.attachments.first.mime_type

    second_delivery = report.report_deliveries.create!(user: create_staff(
      email_address: "removed-staff@example.test",
      restaurants: [ @restaurant ]
    ))
    RestaurantMembership.find_by!(user: second_delivery.user, restaurant: @restaurant).destroy!
    assert_no_difference "ActionMailer::Base.deliveries.size" do
      DeliverReportEmailJob.perform_now(second_delivery.id)
    end
    assert_nil second_delivery.reload.emailed_at
  end

  private

  def create_report
    Report.create!(
      requester: @user,
      organization: @organization,
      restaurant: @restaurant,
      category: "operations",
      start_date: Date.current - 1.day,
      end_date: Date.current
    ).tap do |report|
      report.report_deliveries.create!(user: @user)
    end
  end

  def with_rejected_enqueue
    original = GenerateReportJob.method(:perform_later)
    GenerateReportJob.define_singleton_method(:perform_later) { |_report_id| nil }
    yield
  ensure
    GenerateReportJob.define_singleton_method(:perform_later, original)
  end
end
