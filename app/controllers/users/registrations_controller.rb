# frozen_string_literal: true

module Users
  class RegistrationsController < Devise::RegistrationsController
    def destroy
      deletion = request_deletion
      response.set_header('Location', "/api/v1/deletion_requests/#{deletion.id}")
      render_deletion_accepted(deletion)
    rescue Pundit::NotAuthorizedError => exception
      render_deletion_error(exception, 'forbidden', :forbidden)
    rescue Collaboration::Conflict => exception
      render_deletion_error(exception, exception.code, :conflict)
    rescue ActionController::ParameterMissing => exception
      render_deletion_error(exception, 'missing_parameter', :bad_request)
    end

    protected

    # Devise owns the update hook; refresh and authorize its supplied account under the row lock.
    # :reek:FeatureEnvy
    def update_resource(resource, attributes)
      resource.with_lock do
        unless resource.active_for_authentication?
          resource.errors.add(:base, 'This account is no longer active.')
          return false
        end

        super
      end
    end

    def after_sign_up_path_for(_resource)
      account_path
    end

    def after_inactive_sign_up_path_for(_resource)
      new_user_session_path
    end

    private

    def request_deletion
      Deletions::Request.call(actor: current_user, subject: current_user,
                              password: params.require(:current_password), request_id: request.request_id)
    end

    def render_deletion_accepted(deletion)
      respond_to do |format|
        format.json { render json: { data: deletion.presentation, meta: {} }, status: :accepted }
        format.html { render plain: 'Your account deletion has been scheduled.', status: :accepted }
      end
    end

    def render_deletion_error(exception, code, status)
      message = exception.message
      respond_to do |format|
        format.json { render json: { errors: [{ code:, message: }], request_id: request.request_id }, status: }
        format.html { render plain: message, status: }
      end
    end
  end
end
