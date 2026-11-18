# frozen_string_literal: true

# == Schema Information
#
# Table name: data_exports
#
#  id                    :bigint           not null, primary key
#  attempts              :integer          default(0), not null
#  expires_at            :datetime
#  failure_code          :string
#  lease_token           :string
#  processing_started_at :datetime
#  status                :string           default("pending"), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  requested_by_id       :integer          not null
#  staging_blob_id       :bigint
#  team_id               :bigint           not null
#
# Indexes
#
#  index_data_exports_on_requested_by_id        (requested_by_id)
#  index_data_exports_on_staging_blob_id        (staging_blob_id)
#  index_data_exports_on_status_and_expires_at  (status,expires_at)
#  index_data_exports_on_team_id                (team_id)
#
# Foreign Keys
#
#  fk_rails_...  (requested_by_id => users.id)
#  fk_rails_...  (staging_blob_id => active_storage_blobs.id) ON DELETE => nullify
#  fk_rails_...  (team_id => teams.id)
#
class DataExport < ApplicationRecord
  belongs_to :staging_blob, class_name: 'ActiveStorage::Blob', optional: true
  belongs_to :team
  belongs_to :requested_by, class_name: 'User'
  has_one_attached :file

  validates :status, inclusion: { in: %w[pending processing ready failed expired] }
  validates :attempts, numericality: { greater_than_or_equal_to: 0 }

  RANSACK_ATTRIBUTES = %w[id team_id requested_by_id status attempts expires_at failure_code created_at].freeze

  after_create_commit :enqueue

  def presentation
    attributes.slice('id', 'team_id', 'status', 'expires_at', 'failure_code', 'created_at').merge('stage' => stage)
  end

  def stage
    return staging_blob_id ? 'uploading' : 'snapshotting' if status == 'processing'

    { 'pending' => 'queued', 'ready' => 'completed' }.fetch(status, status)
  end

  def available?
    status == 'ready' && expires_at&.future? && file.attached?
  end

  def claim!
    with_lock do
      return unless retryable?

      update!(status: 'processing', attempts: attempts + 1, lease_token: SecureRandom.uuid,
              processing_started_at: Time.current, failure_code: nil)
      lease_token
    end
  end

  def retryable?
    stale = status == 'processing' && processing_started_at && processing_started_at < 10.minutes.ago
    attempts < 5 && (stale || %w[pending failed].include?(status))
  end

  def enqueue
    BuildDataExportJob.perform_later(id)
  rescue StandardError => error
    Rails.logger.error("Export enqueue failed id=#{id} error=#{error.class.name}")
  end
end
