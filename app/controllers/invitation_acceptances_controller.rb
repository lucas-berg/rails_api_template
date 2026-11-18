# frozen_string_literal: true

class InvitationAcceptancesController < ApplicationController
  before_action :authenticate_user!, only: :create

  rescue_from Authorization::Forbidden, Collaboration::Conflict do |exception|
    status = exception.is_a?(Authorization::Forbidden) ? :forbidden : :conflict
    render plain: exception.message, status:
  end

  def show
    remember_token
    return unless user_signed_in?

    @invitation = Invitation.find_by!(token_digest: Digest::SHA256.hexdigest(session[:pending_invitation_token].to_s))
    head :forbidden unless matching_recipient?
  end

  def create
    accept_invitation
    session.delete(:pending_invitation_token)
    redirect_to account_path, notice: I18n.t('saas.invitation.accepted'), status: :see_other
  end

  private

  def accept_invitation
    Invitations::Accept.call(actor: current_user, token: session[:pending_invitation_token],
                             request_id: request.request_id)
  end

  def remember_token
    token = params[:token]
    session[:pending_invitation_token] = token if token.is_a?(String) && token.length <= 128
  end

  def matching_recipient?
    current_user.confirmed? && current_user.email == @invitation.normalized_email
  end
end
