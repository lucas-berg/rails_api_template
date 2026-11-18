# frozen_string_literal: true

class InvitationMailer < ApplicationMailer
  def invitation(invitation, token)
    @team_name = invitation.team_name
    @expires_at = invitation.expires_at
    @accept_url = invitation_url(token)
    mail(to: invitation.normalized_email, subject: "Invitation to #{@team_name}")
  end

  private

  def invitation_url(token)
    base = ENV.fetch('INVITATION_ACCEPT_URL') { "#{Rails.configuration.x.public_url}/invitations/accept" }
    uri = URI.parse(base)
    uri.query = URI.encode_www_form(URI.decode_www_form(uri.query.to_s) + [['token', token]])
    uri.to_s
  end
end
