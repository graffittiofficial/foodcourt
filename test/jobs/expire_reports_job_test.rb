require "test_helper"
require "stringio"

class ExpireReportsJobTest < ActiveJob::TestCase
  test "purges expired files and preserves the report history" do
    organization = create_organization
    restaurant = create_restaurant(name: "Expired Restaurant", organization: organization)
    user = create_staff(email_address: "expired-staff@example.test", restaurants: [ restaurant ])
    report = Report.create!(
      requester: user,
      organization: organization,
      restaurant: restaurant,
      category: "operations",
      status: "completed",
      start_date: Date.current - 2.days,
      end_date: Date.current - 1.day,
      completed_at: 31.days.ago,
      expires_at: 1.minute.ago
    )
    report.file.attach(io: StringIO.new("report"), filename: report.filename, content_type: "text/csv")

    ExpireReportsJob.perform_now

    assert report.reload.expired?
    assert_not report.file.attached?
    assert Report.exists?(report.id)
  end
end
