# frozen_string_literal: true

module Users
  class ConfirmationsController < Devise::ConfirmationsController
    protected

    def after_confirmation_path_for(_resource_name, _resource)
      return invitation_acceptance_path if session[:pending_invitation_token].present?

      user_signed_in? ? account_path : new_user_session_path
    end
  end
end
