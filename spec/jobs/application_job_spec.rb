# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationJob do
  let(:document) { create(:document, status: 'processing') }
  let(:observations) { [] }
  let(:log_output) { StringIO.new }

  before do
    logger = Logger.new(log_output)
    logger.formatter = ->(_severity, _time, _program, message) { "#{message}\n" }
    allow(Rails).to receive(:logger).and_return(logger)
    allow(Documents::Verify).to receive(:call) { observations << Current.attributes }
    Current.reset
  end

  after { Current.reset }

  it 'persists the originating request and derives the tenant from the current document on the worker' do
    document
    Current.request_id = 'origin-request'
    queued = VerifyDocumentJob.perform_later(document.id)
    serialized = enqueued_jobs.find { |job| job['job_id'] == queued.job_id }
    expect(serialized.fetch('source_request_id')).to eq('origin-request')
    expect(serialized).not_to have_key('team_id')

    worker = VerifyDocumentJob.deserialize(serialized)
    Current.request_id = 'unrelated-request'
    Current.team = create(:team)
    worker.perform_now

    expect(observations.sole).to include(user: document.uploader, team: document.team,
                                         request_id: 'origin-request', job_id: queued.job_id)
    expect(Current.attributes.values).to all(be_nil)
    expect(log_output.string).to include('"event":"job.started"', '"event":"job.finished"',
                                         "\"job_id\":\"#{queued.job_id}\"", '"request_id":"origin-request"',
                                         "\"team_id\":#{document.team_id}")
  end

  it 'clears a stale tenant when a missing record or a multi-team sweep runs on the same worker thread' do
    VerifyDocumentJob.perform_now(document.id)
    missing = VerifyDocumentJob.new(-1)
    missing.perform_now
    sweep = SweepMailDeliveriesJob.new
    allow(sweep).to receive(:perform) { observations << Current.attributes }
    sweep.perform_now

    expect(observations.pluck(:team)).to eq([document.team, nil, nil])
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
    document
    Current.request_id = 'tagged-request'
    job = VerifyDocumentJob.new(document.id)
    allow(job).to receive(:perform) do
      Rails.logger.info('inside-worker')
      raise IOError
    end
    job.perform_now
    Rails.logger.info('after-worker')

    execution_line = log_output.string.lines.find { |line| line.include?('inside-worker') }
    expect(execution_line).to include("job_id=#{job.job_id}", 'request_id=tagged-request',
                                      "team_id=#{document.team_id}")
    expect(log_output.string.lines.last).not_to include('job_id=', 'request_id=', 'team_id=')
    expect(Current.attributes.values).to all(be_nil)
  end

  it 'restores an actively executing parent job after a nested job and resets the final thread context' do
    document
    Current.request_id = 'parent-request'
    parent = VerifyDocumentJob.new(document.id)
    allow(parent).to receive(:perform) do
      observations << Current.attributes
      child = SweepMailDeliveriesJob.new
      allow(child).to receive(:perform) { observations << Current.attributes }
      child.perform_now
      observations << Current.attributes
    end
    parent.perform_now

    expect(observations.first).to include(team: document.team, job_id: parent.job_id)
    expect(observations[1]).to include(team: nil, user: nil, request_id: 'parent-request')
    expect(observations.last).to eq(observations.first)
    expect(Current.attributes.values).to all(be_nil)
  end

  it 'derives the context of team deletion from its stored subject' do
    user = document.uploader
    deletion = DeletionRequest.create!(subject: document.team, requested_by: user, scheduled_at: 1.day.from_now)
    job = ProcessDeletionJob.new(deletion.id)
    allow(job).to receive(:perform) { observations << Current.attributes }
    job.perform_now

    expect(observations.sole).to include(team: document.team, user:)
    expect(Current.attributes.values).to all(be_nil)
  end

  it 'does not attach an account deletion to a team inherited from another operation' do
    user = document.uploader
    deletion = DeletionRequest.create!(subject: user, requested_by: user, scheduled_at: 1.day.from_now)
    job = ProcessDeletionJob.new(deletion.id)
    allow(job).to receive(:perform) { observations << Current.attributes }
    Current.team = document.team
    job.perform_now

    expect(observations.sole).to include(team: nil, user:)
    expect(Current.attributes.values).to all(be_nil)
  end

  it 'retains the original request identifier when a failure schedules a retry' do
    document
    Current.request_id = 'retry-origin'
    job = VerifyDocumentJob.new(document.id)
    allow(Documents::Verify).to receive(:call).and_raise(IOError)
    clear_enqueued_jobs
    job.perform_now

    expect(enqueued_jobs.sole.fetch('source_request_id')).to eq('retry-origin')
    expect(Current.attributes.values).to all(be_nil)
  end
end
