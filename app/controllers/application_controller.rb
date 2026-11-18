# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  protect_from_forgery with: :exception

  def access_denied(_exception)
    render plain: 'You do not have permission to perform this action.', status: :forbidden
  end
end
