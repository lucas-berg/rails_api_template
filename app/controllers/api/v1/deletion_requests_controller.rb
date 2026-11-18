# frozen_string_literal: true

module API
  module V1
    class DeletionRequestsController < SaasController
      def show
        render_data(own_request.presentation)
      end

      def create
        record = Deletions::Request.call(
          actor: current_user, subject: deletion_subject,
          password: params.require(:current_password), request_id: request.request_id
        )
        response.set_header('Location', "/api/v1/deletion_requests/#{record.id}")
        render_data(record.presentation, status: :accepted)
      end

      def destroy
        record = Deletions::Cancel.call(actor: current_user, deletion: own_request,
                                        password: params.require(:current_password), request_id: request.request_id)
        render_data(record.presentation)
      end

      private

      def deletion_subject
        return current_user unless params[:team_id]

        Authorization.team_scope(current_user).find(params.expect(:team_id))
      end

      def own_request
        DeletionRequest.where(requested_by: current_user).find(params.expect(:id))
      end
    end
  end
end
