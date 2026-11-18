# frozen_string_literal: true

module Invitations
  class Operation < Collaboration::Operation
    private

    # The service coordinates token rotation and the transactional mail intent.
    # :reek:FeatureEnvy
    def issue!(invitation)
      RateLimits.check_invitation!(team.id)
      token = SecureRandom.urlsafe_base64(32)
      invitation.assign_attributes(token_digest: Digest::SHA256.hexdigest(token), expires_at: 7.days.from_now)
      invitation.save!
      MailDelivery.enqueue_invitation(invitation, token)
    end
  end
end
