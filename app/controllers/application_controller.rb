# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include RequestContext

  # Prevent CSRF attacks by raising an exception.
  protect_from_forgery with: :exception

  rescue_from Collaboration::Conflict do |exception|
    render plain: exception.message, status: :conflict
  end

  rescue_from Authorization::Forbidden, with: :access_denied

  def access_denied(_exception)
    render plain: 'You do not have permission to perform this action.', status: :forbidden
  end
end
