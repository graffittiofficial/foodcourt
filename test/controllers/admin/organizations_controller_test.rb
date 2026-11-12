require "test_helper"

class Admin::OrganizationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = AdminAccount.create!(email_address: "platform-organizations@example.test", password: "password")
    sign_in_as(@admin)
  end

  test "platform admins can search organizations and create an organization with its first admin invitation" do
    matching = create_organization(name: "Matching Organization")
    create_organization(name: "Other Organization")

    get admin_organizations_path, params: { q: "matching" }

    assert_response :success
    assert_select "h3", text: matching.name
    assert_select "h3", text: "Other Organization", count: 0

    assert_difference [ "Organization.count", "Invitation.count" ], 1 do
      post admin_organizations_path, params: {
        organization: { name: "New Organization", admin_email_address: "first-admin@example.test" }
      }
    end

    organization = Organization.find_by!(name: "New Organization")
    invitation = organization.invitations.sole
    assert_equal "organization_admin", invitation.role
    assert_equal @admin, invitation.invited_by_admin
    assert_redirected_to admin_organizations_path
  end

  test "invalid first-admin invitation rolls back organization creation" do
    assert_no_difference "Organization.count" do
      post admin_organizations_path, params: {
        organization: { name: "No Admin Organization", admin_email_address: "" }
      }
    end

    assert_response :unprocessable_entity
    assert_select '[role="alert"]'
  end

  test "platform admins can delete an unused organization but receive an error when it has restaurants" do
    unused = create_organization(name: "Unused Organization")
    protected = create_organization(name: "Protected Organization")
    create_restaurant(name: "Protected Restaurant", organization: protected)

    delete admin_organization_path(unused)
    assert_redirected_to admin_organizations_path
    assert_not Organization.exists?(unused.id)

    delete admin_organization_path(protected)
    assert_redirected_to admin_organizations_path
    assert Organization.exists?(protected.id)
    assert_match "restaurant", flash[:alert]
  end

  test "platform admins can resend and revoke their own organization invitations" do
    organization = create_organization(name: "Invitation Organization")
    invitation = organization.invitations.create!(
      email_address: "resend-admin@example.test",
      role: :organization_admin,
      invited_by_admin: @admin
    )
    old_digest = invitation.token_digest

    patch resend_admin_invitation_path(invitation)
    assert_redirected_to admin_organizations_path
    assert_not_equal old_digest, invitation.reload.token_digest

    delete admin_invitation_path(invitation)
    assert_redirected_to admin_organizations_path
    assert invitation.reload.revoked_at
  end
end
