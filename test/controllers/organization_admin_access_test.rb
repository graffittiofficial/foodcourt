require "test_helper"

class OrganizationAdminAccessTest < ActionDispatch::IntegrationTest
  setup do
    @organization = create_organization(name: "Admin Group")
    @restaurant = create_restaurant(name: "Managed Restaurant", organization: @organization)
    @other_organization = create_organization(name: "Other Group")
    @other_restaurant = create_restaurant(name: "Outside Restaurant", organization: @other_organization)
    @admin = User.create!(email_address: "admin@example.test", password: "password")
    OrganizationMembership.create!(organization: @organization, user: @admin)
    RestaurantMembership.create!(restaurant: @other_restaurant, user: @admin)
    sign_in_as(@admin, select_restaurant: false)
  end

  test "Organization admin workflows and Restaurant selection stay inside the selected Organization" do
    patch switch_organizations_path, params: { organization_id: @organization.id }
    assert_redirected_to organization_admin_root_path

    get organization_admin_restaurants_path
    assert_response :success
    assert_select "h2", text: @restaurant.name
    assert_select "h2", text: @other_restaurant.name, count: 0

    get staff_restaurants_path
    assert_response :success
    assert_select "h2", text: @restaurant.name
    assert_select "h2", text: @other_restaurant.name, count: 0

    patch select_staff_restaurant_path(@restaurant)
    assert_redirected_to staff_dashboard_path
    get staff_dashboard_path
    assert_response :success

    patch select_staff_restaurant_path(@other_restaurant)
    assert_response :not_found
  end

  test "revoked Restaurant membership is rejected on the next protected request" do
    sign_out
    staff = create_staff(email_address: "restaurant-staff@example.test", restaurants: [ @restaurant ])
    sign_in_as_staff(staff, @restaurant)

    staff.restaurant_memberships.find_by!(restaurant: @restaurant).destroy!
    get staff_dashboard_path

    assert_response :forbidden
  end
end
