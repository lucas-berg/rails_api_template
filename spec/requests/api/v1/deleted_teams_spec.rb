# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Historical deleted team protection', openapi: false do
  let(:user) { create(:user) }
  let(:team) { Teams::Create.call(actor: user, attributes: { name: 'Legacy team' }) }

  %w[active deleted].each do |status|
    it "hides a team with a deleted marker even if its stored status is #{status}" do
      headers = auth_headers(user)
      # Legacy data can contain a contradictory status written outside model validation.
      # rubocop:disable-next Rails/SkipsModelValidations
      team.update_columns(status:, deleted_at: Time.current)

      expect(Pundit.policy!(user, team)).not_to be_show
      get '/api/v1/teams', headers: headers
      expect(json[:data].pluck(:id)).not_to include(team.id)
      get "/api/v1/teams/#{team.id}/members", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end
end
