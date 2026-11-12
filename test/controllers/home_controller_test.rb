require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "public visitors can search restaurants" do
    matching = create_restaurant(name: "Searchable Bistro")
    create_restaurant(name: "Other Bistro")

    get root_path, params: { q: "searchable" }

    assert_response :success
    assert_select "h2", text: matching.name
    assert_select "h2", text: "Other Bistro", count: 0
  end

  test "account types are sent to their appropriate workspace" do
    admin = AdminAccount.create!(email_address: "home-admin@example.test", password: "password")
    sign_in_as(admin)
    get root_path
    assert_redirected_to admin_root_path

    sign_out
    organization_admin = User.create!(email_address: "home-org-admin@example.test", password: "password")
    organization = create_organization(name: "Home Organization")
    OrganizationMembership.create!(organization: organization, user: organization_admin)
    sign_in_as(organization_admin, select_restaurant: false)
    get root_path
    assert_redirected_to organizations_path

    sign_out
    staff = create_staff(email_address: "home-staff@example.test", restaurants: [ create_restaurant(name: "Home Staff Restaurant") ])
    sign_in_as(staff)
    get root_path
    assert_redirected_to staff_dashboard_path

    sign_out
    driver = User.create!(name: "Home Driver", email_address: "home-driver@example.test", password: "password", role: :driver)
    sign_in_as(driver)
    get root_path
    assert_redirected_to driver_root_path
  end
end
