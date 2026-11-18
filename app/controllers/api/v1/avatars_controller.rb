# frozen_string_literal: true

module API
  module V1
    class AvatarsController < TeamContextController
      def show
        document = @team.documents.find_by(id: current_user.avatar_document_id)
        document = nil unless document&.ready? && document.image?
        authorize!(:read, document) if document
        render_data(document ? DocumentPresenter.call(document) : nil)
      end

      def update
        attributes = attributes_for(:avatar, [:document_id])
        id = attributes.fetch(:document_id) { raise ActionController::ParameterMissing, :document_id }
        document = Documents::AssignAvatar.new(**operation_options).call(id)
        render_data(DocumentPresenter.call(document))
      end

      def destroy
        Documents::AssignAvatar.new(**operation_options).clear
        head :no_content
      end
    end
  end
end
