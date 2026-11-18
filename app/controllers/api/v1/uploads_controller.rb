# frozen_string_literal: true

module API
  module V1
    class UploadsController < TeamContextController
      def create
        file = params.require(:file)
        document = Documents::Upload.new(**operation_options).call(file:)
        render_data(DocumentPresenter.call(document), status: :created)
      end

      def complete
        document = Documents::Complete.new(**operation_options).call(params[:id])
        render_data(DocumentPresenter.call(document), status: document.ready? ? :ok : :accepted)
      end
    end
  end
end
