# frozen_string_literal: true

class MailDeliveryMessage
  def initialize(delivery)
    @delivery = delivery
    @payload = delivery.payload
  end

  def build
    case @delivery.kind
    when 'devise' then devise_message
    when 'invitation' then invitation_message
    end
  end

  private

  def devise_message
    user = User.find_by(id: @delivery.user_id)
    notification = @payload.fetch('notification')
    return unless user&.status == 'active'
    return unless MailDelivery::DEVISE_NOTIFICATIONS.include?(notification)
    return unless current_devise_token?(user)

    Devise.mailer.public_send(notification, user, *devise_arguments)
  end

  # :reek:FeatureEnvy -- Deserialized mailer options must regain symbol keys for Devise.
  def devise_arguments
    @payload.fetch('args').map { |arg| arg.is_a?(Hash) ? arg.symbolize_keys : arg }
  end

  def current_devise_token?(user)
    case @payload.fetch('notification')
    when 'confirmation_instructions'
      confirmation_token_matches?(user) && confirmation_current?(user)
    when 'reset_password_instructions'
      token_matches?(user, :reset_password_token) && user.reset_password_period_valid?
    when 'unlock_instructions'
      token_matches?(user, :unlock_token)
    else
      true
    end
  end

  # :reek:FeatureEnvy -- Devise owns the storage format; the dispatcher only checks freshness.
  def token_matches?(user, column)
    token = @payload.fetch('args').first
    expected = Devise.token_generator.digest(user.class, column, token)
    stored = user.public_send(column)
    stored.present? && ActiveSupport::SecurityUtils.secure_compare(stored, expected)
  end

  def confirmation_token_matches?(user)
    token = @payload.fetch('args').first.to_s
    stored = user.confirmation_token.to_s
    # Devise 5 stores raw confirmation tokens; earlier versions used a digest.
    stored.present? && (ActiveSupport::SecurityUtils.secure_compare(stored, token) ||
      token_matches?(user, :confirmation_token))
  end

  def confirmation_current?(user)
    period = user.class.confirm_within
    sent_at = user.confirmation_sent_at
    (user.unconfirmed_email.present? || !user.confirmed?) &&
      (period.nil? || (sent_at.present? && sent_at >= period.ago))
  end

  def invitation_message
    invitation = Invitation.includes(:team).find_by(id: @payload.fetch('invitation_id'))
    token = @payload.fetch('token')
    return unless invitation&.pending? && invitation.token_matches?(token)
    return unless invitation.team.active? && inviter_authorized?(invitation)

    InvitationMailer.invitation(invitation, token)
  end

  def inviter_authorized?(invitation)
    inviter_id = invitation.invited_by_id
    return false unless User.exists?(id: inviter_id, status: 'active')

    member = invitation.team.active_members.find_by(user_id: inviter_id)
    member&.role == 'owner' || (member&.role == 'admin' && %w[member viewer].include?(invitation.role))
  end
end
