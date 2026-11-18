# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Platform data lifecycle controls' do
  let(:operator) { create(:admin_user) }
  let(:support) { create(:admin_user, :support) }
  let(:user) { create(:user) }
  let(:team) { Teams::Create.call(actor: user, attributes: { name: 'Lifecycle team' }) }

  it 'cannot restore a team during deletion through the ordinary status action' do
    Deletions::Request.call(actor: user, subject: team, password: user.password)
    sign_in operator

    post "/admin/teams/#{team.id}/restore", params: { reason: 'Bypass cooling period' }

    expect(response).to have_http_status(:conflict)
    expect(team.reload.status).to eq('deletion_pending')
  end

  it 'cannot reactivate an account after its irreversible deletion decision' do
    DeletionRequest.create!(subject: user, requested_by: user, status: 'failed', stage: 'ledger',
                            scheduled_at: 1.minute.ago)
    user.suspend!
    sign_in operator

    post "/admin/users/#{user.id}/restore", params: { reason: 'Do not bypass deletion' }

    expect(response).to have_http_status(:conflict)
    expect(user.reload).to be_suspended
  end

  it 'prevents support from retrying failed cleanup' do
    deletion = Deletions::Request.call(actor: user, subject: team, password: user.password)
    deletion.update!(status: 'failed', stage: 'files', attempts: 8, failure_code: 'IOError')
    clear_enqueued_jobs
    sign_in support
    post "/admin/deletion_requests/#{deletion.id}/retry_cleanup", params: { reason: 'Storage recovered' }
    expect(response).to have_http_status(:forbidden)
    expect(enqueued_jobs).to be_empty
  end

  it 'requires and audits a reason for a super administrator to retry failed cleanup' do
    deletion = Deletions::Request.call(actor: user, subject: team, password: user.password)
    deletion.update!(status: 'failed', stage: 'files', attempts: 8, failure_code: 'IOError')
    clear_enqueued_jobs
    sign_in operator
    get '/admin'
    post "/admin/deletion_requests/#{deletion.id}/retry_cleanup", params: { reason: ' ' }
    expect(response).to have_http_status(:bad_request)
    post "/admin/deletion_requests/#{deletion.id}/retry_cleanup", params: { reason: 'Storage recovered' }
    expect(response).to have_http_status(:found)
    expect(deletion.reload.attempts).to eq(0)
    expect(enqueued_jobs.pluck(:job)).to include(ProcessDeletionJob)
    expect(AuditEvent.find_by!(action: 'deletion.retried')).to have_attributes(
      actor_type: 'AdminUser', actor_id: operator.id, reason: 'Storage recovered'
    )
  end

  it 'shows lifecycle metadata without encrypted recipients, fingerprints or storage leases' do
    deletion = Deletions::Request.call(actor: user, subject: team, password: user.password)
    tombstone = DeletionTombstone.create!(subject_type: 'Team', subject_id: team.id,
                                          request_uuid: deletion.uuid, fingerprint: 'private-fingerprint',
                                          deleted_at: Time.current)
    export = DataExport.create!(team: team, requested_by: user, lease_token: 'private-lease')
    sign_in support

    get "/admin/deletion_requests/#{deletion.id}"
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include(deletion.encrypted_recipient)
    get "/admin/deletion_tombstones/#{tombstone.id}"
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include(tombstone.fingerprint)
    get "/admin/data_exports/#{export.id}"
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include(export.lease_token)
  end
end
