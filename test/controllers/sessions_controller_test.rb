require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = User.take }

  test "new" do
    get new_session_path
    assert_response :success
  end

  test "create with valid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "create with valid admin credentials" do
    admin = AdminAccount.create!(email_address: "admin@example.com", password: "password")

    post session_path, params: { email_address: admin.email_address, password: "password" }

    assert_redirected_to admin_root_path
    assert cookies[:session_id]
    assert_equal admin, admin.sessions.sole.account

    get admin_root_path
    assert_response :success
    assert_select "h1", "Dashboard"
  end

  test "create with invalid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "wrong" }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test "destroy" do
    sign_in_as(User.take)

    delete session_path

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end
end
