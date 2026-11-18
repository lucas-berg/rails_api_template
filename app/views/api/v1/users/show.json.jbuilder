# frozen_string_literal: true

json.user do
  json.partial! 'users/sessions/info', user: current_user
end
