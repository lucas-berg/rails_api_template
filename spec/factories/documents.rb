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
FactoryBot.define do
  factory :document do
    team
    uploader factory: :user
    original_filename { 'sample.png' }
    declared_content_type { 'image/png' }
    byte_size { contents.bytesize }
    upload_expires_at { 1.hour.from_now }

    transient do
      contents do
        Base64.decode64(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg=='
        )
      end
    end

    after(:create) do |document, evaluator|
      document.team.members.find_or_create_by!(user: document.uploader) { |member| member.role = 'member' }
      document.file.attach(io: StringIO.new(evaluator.contents), filename: document.original_filename,
                           content_type: document.declared_content_type)
    end
  end
end
