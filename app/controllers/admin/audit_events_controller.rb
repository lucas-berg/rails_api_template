# frozen_string_literal: true

module Admin
  class AuditEventsController < BaseController
    def index
      authorize([:admin, AuditEvent], :index?)
      @filters = params.permit(q: {}).to_h
      @search = policy_scope([:admin, AuditEvent]).ransack!(params[:q])
      @audit_events = paginate(@search.result)
    end

    def show
      @audit_event = policy_scope([:admin, AuditEvent]).find(params.expect(:id))
      authorize([:admin, @audit_event], :show?)
    end
  end
end
