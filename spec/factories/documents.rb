# frozen_string_literal: true

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
