require "test_helper"

class Admin::DriversControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = AdminAccount.create!(email_address: "driver-form-admin@example.test", password: "password")
    sign_in_as(@admin)
  end

  test "new Driver form renders for a Global Admin" do
    get new_admin_driver_path

    assert_response :success
    assert_select "form[action='#{admin_drivers_path}'][method='post']"
    assert_select "input[name='user[name]']"
    assert_select "input[name='user[email_address]']"
    assert_select "input[name='user[password]']"
    assert_select "input[name='user[password_confirmation]']"
  end

  test "Global Admin can create a Driver from the form" do
    assert_difference("User.driver.count", 1) do
      post admin_drivers_path, params: {
        user: {
          name: "New Driver",
          email_address: "new-driver@example.test",
          password: "password",
          password_confirmation: "password"
        }
      }
    end

    assert_redirected_to admin_drivers_path
    assert User.exists?(email_address: "new-driver@example.test", role: :driver)
  end
end
