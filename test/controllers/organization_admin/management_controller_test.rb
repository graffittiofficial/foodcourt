require "test_helper"

class OrganizationAdmin::ManagementControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = create_organization(name: "Managed Organization")
    @restaurant = create_restaurant(name: "Managed Restaurant", organization: @organization)
    @outside_restaurant = create_restaurant(name: "Outside Restaurant")
    @admin = User.create!(email_address: "management-admin@example.test", password: "password")
    OrganizationMembership.create!(organization: @organization, user: @admin)
    sign_in_as(@admin, select_restaurant: false)
    patch switch_organizations_path, params: { organization_id: @organization.id }
  end

  test "organization admins can invite another admin and remove an existing admin membership" do
    existing_admin = User.create!(email_address: "existing-admin@example.test", password: "password")
    membership = OrganizationMembership.create!(organization: @organization, user: existing_admin)

    get organization_admin_admins_path
    assert_response :success
    assert_select "li", text: /#{Regexp.escape(existing_admin.email_address)}/

    assert_difference "Invitation.count", 1 do
      post organization_admin_admins_path, params: {
        admin: { email_address: "new-admin@example.test" }
      }
    end
    invitation = @organization.invitations.sole
    assert_equal "organization_admin", invitation.role
    assert_equal @admin, invitation.invited_by_user
    assert_redirected_to organization_admin_admins_path

    delete organization_admin_admin_path(membership)
    assert_redirected_to organization_admin_admins_path
    assert_not OrganizationMembership.exists?(membership.id)
  end

  test "staff invitations are limited to restaurants in the selected organization" do
    get organization_admin_staff_index_path
    assert_response :success

    assert_no_difference "Invitation.count" do
      post organization_admin_staff_index_path, params: {
        staff: { email_address: "outside-staff@example.test", restaurant_ids: [ @outside_restaurant.id ] }
      }
    end
    assert_response :unprocessable_entity
    assert_match "must all belong to this Organization", response.body

    assert_difference "Invitation.count", 1 do
      post organization_admin_staff_index_path, params: {
        staff: { email_address: "new-staff@example.test", restaurant_ids: [ @restaurant.id ] }
      }
    end
    invitation = @organization.invitations.sole
    assert_equal "staff", invitation.role
    assert_equal [ @restaurant ], invitation.restaurants.to_a
    assert_redirected_to organization_admin_staff_index_path

    staff = create_staff(email_address: "remove-staff@example.test", restaurants: [ @restaurant ])
    membership = staff.restaurant_memberships.sole
    delete organization_admin_staff_path(membership)
    assert_redirected_to organization_admin_staff_index_path
    assert_not RestaurantMembership.exists?(membership.id)
  end

  test "organization admins can edit their profile and invalid updates render errors" do
    get edit_organization_admin_profile_path
    assert_response :success
    assert_select "input[name='organization[name]']", value: @organization.name

    patch organization_admin_profile_path, params: {
      organization: { name: "Renamed Organization", time_zone: "UTC" }
    }
    assert_redirected_to organization_admin_root_path
    assert_equal "Renamed Organization", @organization.reload.name
    assert_equal "UTC", @organization.time_zone

    patch organization_admin_profile_path, params: {
      organization: { name: "", time_zone: "Invalid/Zone" }
    }
    assert_response :unprocessable_entity
    assert_select '[role="alert"]'
  end

  test "organization admins can resend and revoke invitations only within their organization" do
    invitation = @organization.invitations.create!(
      email_address: "resend-staff@example.test",
      role: :organization_admin,
      invited_by_user: @admin
    )
    old_digest = invitation.token_digest

    patch resend_organization_admin_invitation_path(invitation)
    assert_redirected_to organization_admin_root_path
    assert_not_equal old_digest, invitation.reload.token_digest

    delete organization_admin_invitation_path(invitation)
    assert_redirected_to organization_admin_root_path
    assert invitation.reload.revoked_at

    outside_invitation = @outside_restaurant.organization.invitations.create!(
      email_address: "outside-admin@example.test",
      role: :organization_admin,
      invited_by_user: @admin
    )
    delete organization_admin_invitation_path(outside_invitation)
    assert_response :not_found
  end
end
