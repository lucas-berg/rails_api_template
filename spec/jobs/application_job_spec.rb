# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationJob do
  let(:user) { create(:user) }
  let(:team) { create(:team) }
  let(:deletion) { DeletionRequest.create!(subject: team, requested_by: user, scheduled_at: 1.day.from_now) }
  let(:observations) { [] }
  let(:log_output) { StringIO.new }

  before do
    logger = Logger.new(log_output)
    logger.formatter = ->(_severity, _time, _program, message) { "#{message}\n" }
    allow(Rails).to receive(:logger).and_return(logger)
    allow(Deletions::BeginProcessing).to receive(:call) do
      observations << Current.attributes
      false
    end
    Current.reset
  end

  after { Current.reset }

  it 'persists the originating request and derives the tenant from the current deletion request on the worker' do
    deletion
    Current.request_id = 'origin-request'
    queued = ProcessDeletionJob.perform_later(deletion.id)
    serialized = enqueued_jobs.find { |job| job['job_id'] == queued.job_id }
    expect(serialized.fetch('source_request_id')).to eq('origin-request')
    expect(serialized).not_to have_key('team_id')

    worker = ProcessDeletionJob.deserialize(serialized)
    Current.request_id = 'unrelated-request'
    Current.team = create(:team)
    worker.perform_now

    expect(observations.sole).to include(user: user, team: team,
                                         request_id: 'origin-request', job_id: queued.job_id)
    expect(Current.attributes.values).to all(be_nil)
    expect(log_output.string).to include('"event":"job.started"', '"event":"job.finished"',
                                         "\"job_id\":\"#{queued.job_id}\"", '"request_id":"origin-request"',
                                         "\"team_id\":#{team.id}")
  end

  it 'clears a stale tenant when a missing record or a multi-team sweep runs on the same worker thread' do
    ProcessDeletionJob.perform_now(deletion.id)
    missing = ProcessDeletionJob.new(-1)
    allow(missing).to receive(:perform) { observations << Current.attributes }
    missing.perform_now
    sweep = SweepMailDeliveriesJob.new
    allow(sweep).to receive(:perform) { observations << Current.attributes }
    sweep.perform_now

    expect(observations.pluck(:team)).to eq([team, nil, nil])
    expect(observations.last).to include(user: nil, request_id: nil, job_id: sweep.job_id)
    expect(Current.attributes.values).to all(be_nil)
  end

  it 'clears context after an exception without including exception contents in its correlation log' do
    job = SweepMailDeliveriesJob.new
    allow(job).to receive(:perform).and_raise(IOError, 'secret from a storage provider')
    expect { job.perform_now }.to raise_error(IOError)
    expect(Current.attributes.values).to all(be_nil)
    expect(log_output.string).to include('"event":"job.failed"', '"error_class":"IOError"')
    expect(log_output.string).not_to include('secret from a storage provider')
  end

  it 'tags internal execution logs and clears the tags even if the job raises' do
    logger = ActiveSupport::TaggedLogging.new(Logger.new(log_output))
    allow(Rails).to receive(:logger).and_return(logger)
    deletion
    Current.request_id = 'tagged-request'
    job = ProcessDeletionJob.new(deletion.id)
    allow(job).to receive(:perform) do
      Rails.logger.info('inside-worker')
      raise IOError
    end
    expect { job.perform_now }.to raise_error(IOError)
    Rails.logger.info('after-worker')

    execution_line = log_output.string.lines.find { |line| line.include?('inside-worker') }
    expect(execution_line).to include("job_id=#{job.job_id}", 'request_id=tagged-request',
                                      "team_id=#{team.id}")
    expect(log_output.string.lines.last).not_to include('job_id=', 'request_id=', 'team_id=')
    expect(Current.attributes.values).to all(be_nil)
  end

  it 'restores an actively executing parent job after a nested job and resets the final thread context' do
    deletion
    Current.request_id = 'parent-request'
    parent = ProcessDeletionJob.new(deletion.id)
    allow(parent).to receive(:perform) do
      observations << Current.attributes
      child = SweepMailDeliveriesJob.new
      allow(child).to receive(:perform) { observations << Current.attributes }
      child.perform_now
      observations << Current.attributes
    end
    parent.perform_now

    expect(observations.first).to include(team: team, job_id: parent.job_id)
    expect(observations[1]).to include(team: nil, user: nil, request_id: 'parent-request')
    expect(observations.last).to eq(observations.first)
    expect(Current.attributes.values).to all(be_nil)
  end

  it 'derives the context of team deletion from its stored subject' do
    job = ProcessDeletionJob.new(deletion.id)
    allow(job).to receive(:perform) { observations << Current.attributes }
    job.perform_now

    expect(observations.sole).to include(team: team, user:)
    expect(Current.attributes.values).to all(be_nil)
  end

  it 'does not attach an account deletion to a team inherited from another operation' do
    deletion = DeletionRequest.create!(subject: user, requested_by: user, scheduled_at: 1.day.from_now)
    job = ProcessDeletionJob.new(deletion.id)
    allow(job).to receive(:perform) { observations << Current.attributes }
    Current.team = team
    job.perform_now

    expect(observations.sole).to include(team: nil, user:)
    expect(Current.attributes.values).to all(be_nil)
  end

  it 'retains the original request identifier when the same job is enqueued for retry' do
    deletion
    Current.request_id = 'retry-origin'
    job = ProcessDeletionJob.new(deletion.id)
    job.perform_now
    clear_enqueued_jobs
    job.retry_job(wait: 1.minute)

    expect(enqueued_jobs.sole.fetch('source_request_id')).to eq('retry-origin')
    expect(Current.attributes.values).to all(be_nil)
  end
end
