require "test_helper"

class InvitationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = create_organization(name: "Invite Group")
    @restaurant = create_restaurant(name: "Invite Restaurant", organization: @organization)
    @inviter = User.create!(email_address: "inviter@example.test", password: "password")
    OrganizationMembership.create!(organization: @organization, user: @inviter)
  end

  test "a new staff invitee creates a User and receives only assigned Restaurant access" do
    invitation = staff_invitation("new-staff@example.test", [ @restaurant ])

    get invitation_path(token: invitation.token)
    assert_response :success

    assert_difference([ "User.count", "RestaurantMembership.count" ], 1) do
      post accept_invitation_path(token: invitation.token), params: {
        user: { name: "New Staff", password: "password", password_confirmation: "password" }
      }
    end

    staff_user = User.find_by!(email_address: "new-staff@example.test")
    assert_equal [ @restaurant ], staff_user.restaurants.to_a
    assert staff_user.customer?
    assert invitation.reload.accepted_at
    assert_redirected_to staff_restaurants_path
  end

  test "an existing customer can accept a staff invite without a duplicate account" do
    customer = User.create!(email_address: "customer@example.test", password: "password")
    invitation = staff_invitation(customer.email_address, [ @restaurant ])
    sign_in_as(customer, select_restaurant: false)

    assert_no_difference("User.count") do
      post accept_invitation_path(token: invitation.token)
    end

    assert_includes customer.reload.restaurants, @restaurant
    assert_redirected_to staff_restaurants_path
  end

  test "an invite cannot be accepted by a signed-in account with a different email" do
    invitation = staff_invitation("intended@example.test", [ @restaurant ])
    other_user = User.create!(email_address: "other@example.test", password: "password")
    sign_in_as(other_user)

    post accept_invitation_path(token: invitation.token), params: {
      user: { name: "Wrong User", password: "password", password_confirmation: "password" }
    }

    assert_redirected_to root_path
    assert_not invitation.reload.accepted_at
    assert_not User.exists?(email_address: "intended@example.test")
  end

  test "expired and revoked invitations cannot be accepted" do
    expired = staff_invitation("expired@example.test", [ @restaurant ])
    expired.update!(expires_at: 1.day.ago)

    get invitation_path(token: expired.token)
    assert_response :gone

    revoked = staff_invitation("revoked@example.test", [ @restaurant ])
    revoked.revoke!
    get invitation_path(token: revoked.token)
    assert_response :gone
  end

  test "resending rotates the token and extends the expiry" do
    invitation = staff_invitation("resend@example.test", [ @restaurant ])
    old_token = invitation.token

    invitation.resend!

    assert_not_equal Digest::SHA256.hexdigest(old_token), invitation.reload.token_digest
    assert_operator invitation.expires_at, :>, 6.days.from_now
    get invitation_path(token: old_token)
    assert_response :not_found
  end

  private

  def staff_invitation(email_address, restaurants)
    invitation = @organization.invitations.new(
      email_address: email_address,
      role: :staff,
      invited_by_user: @inviter
    )
    restaurants.each { |restaurant| invitation.invitation_restaurants.build(restaurant: restaurant) }
    invitation.save!
    invitation
  end
end
