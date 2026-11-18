# frozen_string_literal: true

module Admin
  class TeamsController < BaseController
    before_action :load_team, only: %i[show suspend restore]

    def index
      authorize([:admin, Team], :index?)
      @filters = params.permit(q: {}).to_h
      @search = policy_scope([:admin, Team]).ransack!(params[:q])
      @teams = paginate(@search.result)
    end

    def show
      authorize([:admin, @team], :show?)
    end

    def suspend
      authorize([:admin, @team], :suspend?)
      change_status('suspended')
    end

    def restore
      authorize([:admin, @team], :restore?)
      change_status('active')
    end

    private

    def load_team
      @team = policy_scope([:admin, Team]).find(params.expect(:id))
    end

    def change_status(status)
      Platform::ChangeStatus.new(actor: current_admin_user, target: @team, request_id: request.request_id)
                            .call(status:, reason: params.require(:reason))
      redirect_to admin_team_path(@team), notice: I18n.t('admin.messages.team_updated')
    end
  end
end
