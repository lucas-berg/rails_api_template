# frozen_string_literal: true

# == Schema Information
#
# Table name: documents
#
#  id                        :bigint           not null, primary key
#  byte_size                 :bigint           not null
#  declared_content_type     :string           not null
#  failure_code              :string
#  last_error                :string
#  original_filename         :string           not null
#  purge_attempts            :integer          default(0), not null
#  purge_requested_at        :datetime
#  purged_at                 :datetime
#  status                    :string           default("uploading"), not null
#  upload_expires_at         :datetime         not null
#  verification_requested_at :datetime
#  verified_at               :datetime
#  verified_content_type     :string
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  team_id                   :bigint           not null
#  uploader_id               :integer          not null
#
# Indexes
#
#  index_documents_on_status_and_purge_requested_at         (status,purge_requested_at)
#  index_documents_on_status_and_upload_expires_at          (status,upload_expires_at)
#  index_documents_on_status_and_verification_requested_at  (status,verification_requested_at)
#  index_documents_on_team_id                               (team_id)
#  index_documents_on_uploader_id                           (uploader_id)
#
# Foreign Keys
#
#  fk_rails_...  (team_id => teams.id)
#  fk_rails_...  (uploader_id => users.id)
#
class Document < ApplicationRecord
  CONTENT_TYPES = %w[image/png image/jpeg application/pdf].freeze
  IMAGE_TYPES = %w[image/png image/jpeg].freeze
  STATUSES = %w[uploading processing ready rejected deleting deleted purge_failed].freeze
  RANSACK_ATTRIBUTES = %w[id team_id uploader_id original_filename declared_content_type verified_content_type
                          byte_size status failure_code created_at verified_at purged_at].freeze

  belongs_to :team
  belongs_to :uploader, class_name: 'User'
  has_one_attached :file

  validates :original_filename, :upload_expires_at, presence: true
  validates :original_filename, length: { maximum: 255 }
  validates :declared_content_type, inclusion: { in: CONTENT_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :byte_size, numericality: { greater_than_or_equal_to: 0 }

  after_update_commit :schedule_processing, if: :saved_change_to_status?

  scope :visible, -> { where.not(status: 'deleted') }

  def self.maximum_bytes
    Integer(ENV.fetch('MAX_UPLOAD_BYTES', 10.megabytes.to_s)).clamp(1, 100.megabytes)
  end

  def ready?
    status == 'ready' && verified_at.present? && verified_content_type.present?
  end

  def image?
    IMAGE_TYPES.include?(verified_content_type)
  end

  def retry_purge!
    with_lock do
      raise ArgumentError, 'Only failed purges can be retried' unless status == 'purge_failed'

      update!(status: 'deleting', purge_attempts: 0, purge_requested_at: Time.current, last_error: nil)
    end
  end

  private

  def schedule_processing
    case status
    when 'processing' then VerifyDocumentJob.perform_later(id)
    when 'rejected', 'deleting' then PurgeDocumentJob.perform_later(id)
    end
  rescue StandardError => exception
    Rails.logger.error("Document enqueue failed id=#{id} error=#{exception.class.name}")
  end
end
