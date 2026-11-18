# frozen_string_literal: true

# == Schema Information
#
# Table name: deletion_tombstones
#
#  id           :bigint           not null, primary key
#  deleted_at   :datetime         not null
#  fingerprint  :string           not null
#  request_uuid :string           not null
#  subject_type :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  subject_id   :bigint           not null
#
# Indexes
#
#  index_deletion_tombstones_on_request_uuid                 (request_uuid) UNIQUE
#  index_deletion_tombstones_on_subject_type_and_subject_id  (subject_type,subject_id)
#
class DeletionTombstone < ApplicationRecord
  validates :request_uuid, :subject_type, :subject_id, :fingerprint, :deleted_at, presence: true
  validates :subject_type, inclusion: { in: %w[Team User] }

  def self.ransackable_attributes(_auth_object = nil)
    %w[subject_type subject_id]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  def self.fingerprint(subject)
    Digest::SHA256.hexdigest("#{subject.class.name}:#{subject.id}:#{subject.created_at.utc.iso8601(6)}")
  end

  def ledger_entry
    attributes.slice('request_uuid', 'subject_type', 'subject_id', 'fingerprint', 'deleted_at').merge('version' => 1)
  end
end
