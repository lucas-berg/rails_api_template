# frozen_string_literal: true

module Users
  class ApplicationController < ::ApplicationController
    include API::Concerns::ActAsAPIRequest

    respond_to :json, :html

    private

    def process_action(...)
      # Devise prepends authentication callbacks, so isolate the session before the callback chain starts.
      use_stateless_session if devise_controller? && resource_name == :user && request.format.json?
      super
    end
  end
end
