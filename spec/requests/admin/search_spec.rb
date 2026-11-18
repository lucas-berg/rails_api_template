# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Administration search' do
  before { sign_in create(:admin_user, :support) }

  it 'searches permitted account fields with Ransack and retains filters across pages' do
    3.times { |index| create(:user, email: "search-#{index}@example.com") }
    create(:user, email: 'unrelated@example.com')
    get '/admin/users', params: { q: { email_cont: 'search-' }, per_page: 2 }
    expect(response).to have_http_status(:ok)
    page = response.parsed_body
    expect(page.css('tbody tr').size).to eq(2)
    expect(page.at_css('input[name="q[email_cont]"]')['value']).to eq('search-')
    expect(response.body).not_to include('unrelated@example.com')
    next_link = page.at_css('nav[aria-label="Pagination"] a')
    expect(next_link.text).to include('Next')
    expect(next_link['href']).to include('q%5Bemail_cont%5D=search-')
    Prosopite.finish
    Prosopite.scan
    get next_link['href']
    expect(response.parsed_body.css('tbody tr').size).to eq(1)
  end

  it 'renders actual audit events with no filters and searches actions through q parameters' do
    user = create(:user)
    team = Teams::Create.call(actor: user, attributes: { name: 'Searchable team' })
    AuditEvent.record!(actor: user, target: team, team:, action: 'team.reviewed')
    get '/admin/audit_events'
    expect(response.body).to include('team.created', 'team.reviewed')
    Prosopite.finish
    Prosopite.scan
    get '/admin/audit_events', params: { q: { action_cont: 'reviewed' } }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('team.reviewed')
    expect(response.body).not_to include('team.created')
  end

  %w[encrypted_password_cont reset_password_token_eq unknown_field_eq auth_sessions_jti_digest_eq].each do |query|
    it "rejects forbidden search #{query}" do
      get '/admin/users', params: { q: { query => 'private' } }
      expect(response).to have_http_status(:bad_request)
    end
  end

  it 'bounds list sizes and provides an empty state for unmatched searches' do
    create_list(:user, 3)
    get '/admin/users', params: { per_page: 500 }
    expect(response.parsed_body.at_css('select[name="per_page"] option[selected]')['value']).to eq('100')
    Prosopite.finish
    Prosopite.scan
    get '/admin/users', params: { q: { email_cont: 'no-match-address' } }
    expect(response.body).to include('No matching records')
  end

  it 'offers only current team states while retaining historical deleted records for review' do
    team = create(:team, status: 'deleted', deleted_at: 1.day.ago)
    get '/admin/teams', params: { q: { status_eq: 'deleted' } }

    expect(response).to have_http_status(:ok)
    statuses = response.parsed_body.css('select[name="q[status_eq]"] option').pluck('value')
    expect(statuses).to eq(['', 'active', 'suspended', 'deleted'])
    expect(response.body).to include(team.name)
  end
end
