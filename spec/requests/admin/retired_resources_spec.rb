# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Retired administration resources', openapi: false do
  before { sign_in create(:admin_user) }

  %w[/admin/deletion_requests /admin/deletion_requests/1
     /admin/deletion_tombstones /admin/deletion_tombstones/1].each do |path|
    it "does not expose #{path}" do
      get path
      expect(response).to have_http_status(:not_found)
    end
  end

  it 'does not provide a deletion cleanup retry action' do
    post '/admin/deletion_requests/1/retry_cleanup', params: { reason: 'The feature has been removed' }
    expect(response).to have_http_status(:not_found)
  end
end
