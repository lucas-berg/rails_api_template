# frozen_string_literal: true

module Admin
  class SessionsController < Devise::SessionsController
    layout 'admin'
    before_action :require_html

    protected

    def after_sign_in_path_for(_resource)
      admin_root_path
    end

    def after_sign_out_path_for(_resource)
      new_admin_user_session_path
    end

    private

    def require_html
      head :not_acceptable unless request.format.html?
    end
  end
end
