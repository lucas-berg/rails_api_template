# frozen_string_literal: true

module Admin
  module ApplicationHelper
    def admin_navigation
      [['Overview', admin_root_path], ['Accounts', admin_users_path], ['Teams', admin_teams_path],
       ['Members', admin_members_path], ['Invitations', admin_invitations_path],
       ['API sessions', admin_auth_sessions_path], ['Mail deliveries', admin_mail_deliveries_path],
       ['Notifications', admin_notifications_path], ['Notification deliveries', admin_notification_deliveries_path],
       ['Audit history', admin_audit_events_path], ['Administrators', admin_admin_users_path]]
    end

    def admin_navigation_link(label, path)
      current_path = request.path
      selected = current_path == path || (path != admin_root_path && current_path.start_with?("#{path}/"))
      link_to label, path, class: ['admin-nav__link', ('is-current' if selected)],
                           aria: { current: ('page' if selected) }
    end

    def admin_status(value)
      status = value.to_s
      tone = case status
             when 'failed', 'suspended', 'removed' then 'danger'
             when 'active', 'sent', 'completed', 'super_admin' then 'success'
             when 'pending', 'sending' then 'pending'
             else 'neutral'
             end
      tag.span(status.humanize, class: "admin-badge admin-badge--#{tone}")
    end

    # Optional timestamps render a visible empty value without changing the UTC display contract.
    # :reek:ControlParameter
    def admin_time(value)
      value&.utc&.strftime('%Y-%m-%d %H:%M UTC') || '—'
    end

    def admin_page_path(page, filters:, per_page:)
      url_for(filters.merge(page:, per_page:))
    end
  end
end
