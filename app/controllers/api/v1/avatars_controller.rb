# frozen_string_literal: true

module API
  module V1
    class AvatarsController < TeamContextController
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
