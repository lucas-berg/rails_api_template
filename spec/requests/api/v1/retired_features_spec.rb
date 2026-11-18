# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Retired file and export endpoints', openapi: false do
  [
    [:post, '/api/v1/teams/1/uploads'],
    [:post, '/api/v1/teams/1/uploads/1/complete'],
    [:get, '/api/v1/teams/1/files'],
    [:get, '/api/v1/teams/1/files/1'],
    [:delete, '/api/v1/teams/1/files/1'],
    [:get, '/api/v1/teams/1/files/1/download'],
    [:get, '/api/v1/teams/1/files/1/preview'],
    [:get, '/api/v1/teams/1/avatar'],
    [:patch, '/api/v1/teams/1/avatar'],
    [:delete, '/api/v1/teams/1/avatar'],
    [:get, '/api/v1/teams/1/exports'],
    [:post, '/api/v1/teams/1/exports'],
    [:get, '/api/v1/teams/1/exports/1'],
    [:get, '/api/v1/teams/1/exports/1/download'],
    [:get, '/admin/documents'],
    [:get, '/admin/data_exports'],
    [:post, '/rails/active_storage/direct_uploads']
  ].each do |method, path|
    it "returns 404 for #{method.upcase} #{path}" do
      public_send(method, path)

      expect(response).to have_http_status(:not_found)
    end
  end
end
