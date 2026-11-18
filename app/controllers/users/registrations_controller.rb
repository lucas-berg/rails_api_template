# frozen_string_literal: true

module Users
  class RegistrationsController < Devise::RegistrationsController
    def destroy
      respond_to do |format|
        format.json do
          render json: { errors: [{ code: 'account_deletion_unavailable',
                                    message: 'Account deletion is not available yet.' }],
                         request_id: request.request_id }, status: :conflict
        end
        format.html { render plain: 'Account deletion is not available yet.', status: :conflict }
      end
    end

    protected

    def after_sign_up_path_for(_resource)
      account_path
    end

    def after_inactive_sign_up_path_for(_resource)
      new_user_session_path
    end
  end
end
