# frozen_string_literal: true

# == Schema Information
#
# Table name: deletion_requests
#
#  id                    :bigint           not null, primary key
#  attempts              :integer          default(0), not null
#  canceled_at           :datetime
#  completed_at          :datetime
#  encrypted_recipient   :text
#  failure_code          :string
#  notice_attempts       :integer          default(0), not null
#  notice_failure_code   :string
#  notified_at           :datetime
#  previous_team_status  :string
#  processing_started_at :datetime
#  scheduled_at          :datetime         not null
#  stage                 :string           default("requested"), not null
#  status                :string           default("pending"), not null
#  subject_type          :string           not null
#  uuid                  :string           not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  requested_by_id       :integer
#  subject_id            :bigint           not null
#
# Indexes
#
#  index_deletion_requests_on_open_subject             (subject_type,subject_id) UNIQUE WHERE ((status)::text = ANY (ARRAY[('pending'::character varying)::text, ('processing'::character varying)::text, ('failed'::character varying)::text]))
#  index_deletion_requests_on_requested_by_id          (requested_by_id)
#  index_deletion_requests_on_status_and_scheduled_at  (status,scheduled_at)
#  index_deletion_requests_on_uuid                     (uuid) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (requested_by_id => users.id)
#
class DeletionRequest < ApplicationRecord
  belongs_to :requested_by, class_name: 'User', optional: true
  belongs_to :subject, polymorphic: true

  validates :subject_type, inclusion: { in: %w[User Team] }
  validates :status, inclusion: { in: %w[pending processing failed completed canceled] }
  validates :uuid, :scheduled_at, presence: true

  before_validation(on: :create) { self.uuid ||= SecureRandom.uuid }

  def self.ransackable_attributes(_auth_object = nil)
    %w[subject_type subject_id status]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  def self.cooling_period
    Integer(ENV.fetch('DELETION_COOLING_DAYS', '7')).clamp(1, 30).days
  end

  def cancellable?
    %w[pending failed].include?(status) && stage == 'requested'
  end

  def recipient=(email)
    self.encrypted_recipient = MailDelivery.encryptor.encrypt_and_sign(email, purpose: 'deletion-completion')
  end

  def recipient
    return if encrypted_recipient.blank?

    MailDelivery.encryptor.decrypt_and_verify(encrypted_recipient, purpose: 'deletion-completion')
  end

  def presentation
    attributes.slice('id', 'subject_type', 'subject_id', 'status', 'stage', 'scheduled_at', 'completed_at',
                     'canceled_at', 'failure_code', 'created_at')
  end
end
