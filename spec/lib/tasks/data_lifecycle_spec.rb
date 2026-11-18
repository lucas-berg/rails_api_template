# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'DataLifecycle', :rake do
  let(:user) { create(:user) }
  let(:team) { Teams::Create.call(actor: user, attributes: { name: 'Task restore' }) }
  let(:ledger_directory) { Dir.mktmpdir('deletion-task-spec') }

  before do
    Rails.application.load_tasks unless Rake::Task.task_defined?('data:deletions:export')
    allow(Lifecycle::DeletionLedger).to receive(:directory).and_return(Pathname.new(ledger_directory))
  end

  after { FileUtils.remove_entry(ledger_directory) }

  it 'exports the deletion ledger and replays it through the documented tasks' do
    deletion = Deletions::Request.call(actor: user, subject: team, password: user.password)
    deletion.update!(scheduled_at: 1.minute.ago)
    ProcessDeletionJob.perform_now(deletion.id)
    Lifecycle::DeletionLedger.directory.glob('*.json').each(&:delete)

    Rake::Task['data:deletions:export'].reenable
    Rake::Task['data:deletions:export'].invoke
    expect(Lifecycle::DeletionLedger.entries.size).to eq(1)
    # Simulate restoration of the SQL backup without restoring the independent ledger directory.
    # rubocop:disable-next Rails/SkipsModelValidations
    team.update_columns(status: 'active', deleted_at: nil)
    create(:member, :owner, user: user, team: team)
    Rake::Task['data:deletions:replay'].reenable
    Rake::Task['data:deletions:replay'].invoke
    expect(team.reload.status).to eq('deleted')
    expect(team.members).to be_empty
  end
end
