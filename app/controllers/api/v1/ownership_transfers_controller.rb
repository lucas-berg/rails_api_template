# frozen_string_literal: true

module API
  module V1
    class OwnershipTransfersController < TeamContextController
      def create
        member = Members::TransferOwnership.new(**operation_options).call(params.require(:member_id))
        render_data(SaasPresenter.member(member))
      end
    end
  end
end
