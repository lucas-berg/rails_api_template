# frozen_string_literal: true

module API
  module V1
    class DeletionRequestsController < SaasController
      def show
        record = own_request
        authorize record, :show?
        render_data(record.presentation)
      end

      def create
        subject = deletion_subject
        authorize subject, :request_deletion?
        record = Deletions::Request.call(
          actor: current_user, subject:,
          password: params.require(:current_password), request_id: request.request_id
        )
        response.set_header('Location', "/api/v1/deletion_requests/#{record.id}")
        render_data(record.presentation, status: :accepted)
      end

      def destroy
        record = own_request
        authorize record, :cancel?
        record = Deletions::Cancel.call(actor: current_user, deletion: record,
                                        password: params.require(:current_password), request_id: request.request_id)
        render_data(record.presentation)
      end

      private

      def deletion_subject
        return current_user unless params[:team_id]

        policy_scope(Team).find(params.expect(:team_id))
      end

      def own_request
        policy_scope(DeletionRequest).find(params.expect(:id))
      end
    end
  end
end
