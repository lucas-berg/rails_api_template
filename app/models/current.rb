# frozen_string_literal: true

class Current < ActiveSupport::CurrentAttributes
  attribute :user, :team, :request_id
end
