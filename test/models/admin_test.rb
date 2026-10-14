require "test_helper"

class AdminTest < ActiveSupport::TestCase
  test "normalizes email addresses" do
    admin = AdminAccount.new(email_address: " ADMIN@EXAMPLE.COM ", password: "password")

    assert_equal "admin@example.com", admin.email_address
  end

  test "requires unique email addresses" do
    AdminAccount.create!(email_address: "admin@example.com", password: "password")
    duplicate = AdminAccount.new(email_address: "ADMIN@example.com", password: "password")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email_address], "has already been taken"
  end

  test "admin sessions are associated with the admin account" do
    admin = AdminAccount.create!(email_address: "admin@example.com", password: "password")

    assert_equal admin, admin.sessions.create!.account
  end
end
