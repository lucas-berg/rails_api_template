# frozen_string_literal: true

module Admin
  class AdminUsersController < BaseController
    before_action :load_administrator, only: %i[show edit update]

    def index
      authorize([:admin, AdminUser], :index?)
      @filters = params.permit(q: {}).to_h
      @search = policy_scope([:admin, AdminUser]).ransack!(params[:q])
      @admin_users = paginate(@search.result)
    end

    def show
      authorize([:admin, @admin_user], :show?)
    end

    def new
      @admin_user = AdminUser.new
      authorize([:admin, @admin_user], :create?)
    end

    def edit
      authorize([:admin, @admin_user], :update?)
    end

    def create
      @admin_user = AdminUser.new
      authorize([:admin, @admin_user], :create?)
      assign_administrator
      persist_administrator
      redirect_to admin_admin_user_path(@admin_user), notice: I18n.t('admin.messages.created')
    rescue ActiveRecord::RecordInvalid
      render :new, status: :unprocessable_content
    end

    def update
      authorize([:admin, @admin_user], :update?)
      @admin_user.with_lock do
        assign_administrator
        persist_administrator
      end
      redirect_to admin_admin_user_path(@admin_user), notice: I18n.t('admin.messages.updated')
    rescue ActiveRecord::RecordInvalid
      render :edit, status: :unprocessable_content
    end

    private

    def load_administrator
      @admin_user = policy_scope([:admin, AdminUser]).find(params.expect(:id))
    end

    # A blank edit password means keep the existing credential; nonblank input is validated by Devise.
    # :reek:FeatureEnvy
    def administrator_params
      # Role-only edits are valid; expect would reject the empty permitted credential set.
      values = params.require(:admin_user).permit(:email, :password, :password_confirmation) # rubocop:disable Rails/StrongParametersExpect
      values = values.except(:password, :password_confirmation) if values[:password].blank?
      values
    end

    def assign_administrator
      @admin_user.assign_attributes(administrator_params)
      submitted = params.require(:admin_user)
      @admin_user.role = submitted[:role] if submitted.key?(:role)
    end

    def persist_administrator
      reason = params.require(:admin_user).require(:operation_reason)
      AdminUser.transaction do
        @admin_user.save!
        AuditEvent.record!(actor: current_admin_user, action: "admin_user.#{action_name}", target: @admin_user,
                           request_id: request.request_id, reason:, metadata: { role: @admin_user.role })
      end
    end
  end
end
