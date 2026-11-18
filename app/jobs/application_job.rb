# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  attr_accessor :source_request_id

  before_enqueue :capture_request_id
  around_perform :with_execution_context

  def initialize(...)
    super
    capture_request_id
  end

  def serialize
    super.merge('source_request_id' => source_request_id)
  end

  def deserialize(job_data)
    super
    self.source_request_id = job_data['source_request_id']
  end

  private

  def capture_request_id
    self.source_request_id ||= Current.request_id
  end

  # Individual jobs resolve trusted records themselves. Sweepers keep an empty tenant context.
  def execution_context
    {}
  end

  def with_execution_context
    parent_context = Current.attributes if ActiveSupport::ExecutionContext.to_h[:saas_job_context]
    prepare_execution_context
    ActiveSupport::ExecutionContext.set(saas_job_context: true) do
      with_log_tags do
        log_execution('job.started')
        yield
        log_execution('job.finished')
      end
    end
  rescue StandardError => error
    log_execution('job.failed', error_class: error.class.name)
    raise
  ensure
    restore_execution_context(parent_context)
  end

  def restore_execution_context(parent_context)
    Current.reset
    Current.instance.attributes = parent_context if parent_context
  end

  # Only these explicit, record-derived fields are installed in the per-job context.
  # :reek:FeatureEnvy
  def prepare_execution_context
    Current.reset
    Current.request_id = source_request_id
    Current.job_id = job_id
    context = execution_context
    Current.user = context[:user]
    Current.team = context[:team]
  end

  def log_execution(event, **details)
    payload = { event:, job_class: self.class.name, job_id:, request_id: Current.request_id,
                team_id: Current.team&.id }.merge(details)
    Rails.logger.info(payload.to_json)
  end

  # Production uses tagged logging; tests and embedding applications may supply a plain logger.
  # :reek:ManualDispatch
  # :reek:FeatureEnvy
  def with_log_tags(&)
    logger = Rails.logger
    return yield unless logger.respond_to?(:tagged)

    tags = ["job_id=#{job_id}", "request_id=#{Current.request_id}", "team_id=#{Current.team&.id}"]
    logger.tagged(*tags, &)
  end
end
