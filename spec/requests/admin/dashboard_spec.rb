# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin dashboard', openapi: false do
  it 'shows actual platform counts, failed operations and recent audit activity' do
    owner = create(:user)
    Teams::Create.call(actor: owner, attributes: { name: 'Dashboard team' })
    delivery = MailDelivery.enqueue_devise(owner, :reset_password_instructions, ['private-token'])
    delivery.update!(status: 'failed')
    sign_in create(:admin_user)

    get admin_root_path

    expect(response).to have_http_status(:ok)
    page = response.parsed_body
    expect(page.css('.admin-stat strong').map(&:text)).to eq(%w[1 1])
    expect(page.css('.admin-count').map(&:text)).to eq(%w[1 0])
    expect(response.body).to include('team.created', 'Needs attention', '/admin/jobs', '/admin/feature-flags')
    expect(response.body).not_to include('ActiveAdmin', 'aa:', 'private-token', delivery.encrypted_payload)
    expect(response.body).not_to include('Scheduled deletions', 'Deletion cleanup', '/admin/deletion_requests',
                                         '/admin/deletion_tombstones')
    expect(page.at_css('link[rel="stylesheet"]')['href']).to match(%r{/assets/admin-[a-f0-9]+\.css})
  end

  it 'shows an empty state and hides privileged tools from support' do
    sign_in create(:admin_user, :support)
    get admin_root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('No audit activity yet', 'Support access')
    expect(response.body).not_to include('href="/admin/jobs"', 'href="/admin/feature-flags"')
  end

  it 'redirects anonymous visitors to the administrator login page' do
    get admin_root_path
    expect(response).to redirect_to(new_admin_user_session_path)
  end
end
