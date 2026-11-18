# frozen_string_literal: true

module Admin
  class UsersController < BaseController
    before_action :load_user, only: %i[show suspend restore]

    def index
      authorize([:admin, User], :index?)
      @filters = params.permit(q: {}).to_h
      @search = policy_scope([:admin, User]).ransack!(params[:q])
      @users = paginate(@search.result)
    end

    def show
      authorize([:admin, @user], :show?)
    end

    def suspend
      authorize([:admin, @user], :suspend?)
      change_status('suspended')
    end

    def restore
      authorize([:admin, @user], :restore?)
      change_status('active')
    end

    private

    def load_user
      @user = policy_scope([:admin, User]).find(params.expect(:id))
    end

    def change_status(status)
      Platform::ChangeStatus.new(actor: current_admin_user, target: @user, request_id: request.request_id)
                            .call(status:, reason: params.require(:reason))
      redirect_to admin_user_path(@user), notice: I18n.t('admin.messages.account_updated')
    end
  end
end
