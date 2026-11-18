# frozen_string_literal: true

module Admin
  class PasswordsController < Devise::PasswordsController
    layout 'admin'
    before_action :require_html

    protected

    def after_resetting_password_path_for(_resource)
      admin_user_signed_in? ? admin_root_path : new_admin_user_session_path
    end

    def after_sending_reset_password_instructions_path_for(_resource)
      new_admin_user_session_path
    end

    private

    def require_html
      head :not_acceptable unless request.format.html?
    end
  end
end
