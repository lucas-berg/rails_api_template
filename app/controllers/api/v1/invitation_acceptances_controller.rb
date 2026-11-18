# frozen_string_literal: true

module API
  module V1
    class InvitationAcceptancesController < SaasController
      def create
        token = params.require(:token)
        invitation = Invitation.find_by!(token_digest: Digest::SHA256.hexdigest(token.to_s))
        authorize invitation, :accept?
        member = Invitations::Accept.call(actor: current_user, token:,
                                          request_id: request.request_id)
        render_data(SaasPresenter.member(member))
      end
    end
  end
end
