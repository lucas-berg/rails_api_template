# frozen_string_literal: true

module API
  module V1
    class InvitationAcceptancesController < SaasController
      def create
        member = Invitations::Accept.call(actor: current_user, token: params.require(:token),
                                          request_id: request.request_id)
        render_data(SaasPresenter.member(member))
      end
    end
  end
end
