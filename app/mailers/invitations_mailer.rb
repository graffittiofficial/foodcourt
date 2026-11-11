class InvitationsMailer < ApplicationMailer
  def invite(invitation, token)
    @invitation = invitation
    @invitation_url = invitation_url(token: token)
    mail subject: "You’ve been invited to manage a Foodcourt restaurant", to: invitation.email_address
  end
end
