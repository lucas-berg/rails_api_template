# frozen_string_literal: true

module Admin
  class DashboardController < BaseController
    def show
      authorize(%i[admin dashboard], :show?)
      load_counts
      load_failures
      @audit_events = policy_scope([:admin, AuditEvent]).order(occurred_at: :desc, id: :desc).limit(8)
    end

    private

    def load_counts
      @user_count = policy_scope([:admin, User]).where(deleted_at: nil).count
      @team_count = policy_scope([:admin, Team]).where.not(status: 'deleted').count
    end

    def load_failures
      @failed_mail_count = policy_scope([:admin, MailDelivery]).where(status: 'failed').count
      @failed_notification_count = policy_scope([:admin, NotificationDelivery]).where(status: 'failed').count
    end
  end
end
