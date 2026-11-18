# frozen_string_literal: true

require 'rails_helper'

# == Schema Information
#
# Table name: mail_deliveries
#
#  id                :bigint           not null, primary key
#  attempts          :integer          default(0), not null
#  encrypted_payload :text
#  event_key         :string           not null
#  kind              :string           not null
#  last_error        :string
#  lease_token       :string
#  locked_at         :datetime
#  next_attempt_at   :datetime         not null
#  sent_at           :datetime
#  status            :string           default("pending"), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  team_id           :bigint
#  user_id           :integer
#
# Indexes
#
#  index_mail_deliveries_on_event_key                   (event_key) UNIQUE
#  index_mail_deliveries_on_status_and_locked_at        (status,locked_at)
#  index_mail_deliveries_on_status_and_next_attempt_at  (status,next_attempt_at)
#  index_mail_deliveries_on_team_id                     (team_id)
#  index_mail_deliveries_on_user_id                     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (team_id => teams.id) ON DELETE => nullify
#  fk_rails_...  (user_id => users.id) ON DELETE => nullify
#
RSpec.describe MailDelivery do
  let(:user) { create(:user) }

  before { clear_enqueued_jobs }

  def enqueue(token = 'secret-reset-token', event_key: 'reset-request-id')
    described_class.enqueue_devise(user, :reset_password_instructions, [token], event_key:)
  end

  it 'encrypts secret payloads and deduplicates the same explicitly identified notification event' do
    delivery = enqueue
    expect(delivery.reload.encrypted_payload).not_to include('secret-reset-token')
    expect(delivery.payload.fetch('args')).to eq(['secret-reset-token'])
    expect { enqueue }.not_to change(described_class, :count)
  end

  it 'rolls the mail intent back with its business transaction' do
    user
    expect {
      described_class.transaction do
        enqueue
        raise ActiveRecord::Rollback
      end
    }.not_to change(described_class, :count)
    expect(enqueued_jobs).to be_empty
  end

  it 'rejects unsupported notifications' do
    expect { described_class.enqueue_devise(user, :destroy, []) }.to raise_error(ArgumentError)
  end

  it 'claims a delivery only once while its lease remains valid' do
    delivery = enqueue
    lease = delivery.claim!
    expect(lease).to be_present
    expect(described_class.find(delivery.id).claim!).to be_nil
    expect(delivery.reload.attempts).to eq(1)
  end

  it 'recovers an expired lease and rejects completion by an earlier worker' do
    delivery = enqueue
    old_lease = delivery.claim!
    travel 6.minutes do
      lease = delivery.claim!
      expect(lease).not_to eq(old_lease)
      delivery.finish!(old_lease)
      expect(delivery.reload.status).to eq('sending')
      delivery.finish!(lease)
      expect(delivery.reload.status).to eq('sent')
      expect(delivery.encrypted_payload).to be_nil
    end
  end

  it 'does not retain error messages containing secrets' do
    delivery = enqueue
    lease = delivery.claim!
    delivery.fail!(lease, RuntimeError.new('secret-reset-token'))
    expect(delivery.reload.last_error).to eq('RuntimeError')
    expect(delivery.status).to eq('pending')
    expect(delivery.next_attempt_at).to be > Time.current
  end

  it 'stops after the retry budget and permits a deliberate retry' do
    delivery = enqueue
    delivery.update!(attempts: described_class::MAX_ATTEMPTS - 1)
    lease = delivery.claim!
    delivery.fail!(lease, IOError.new)
    expect(delivery.reload.status).to eq('failed')
    expect { delivery.retry_delivery! }.to have_enqueued_job(SendMailDeliveryJob).with(delivery.id)
    expect(delivery.reload).to have_attributes(status: 'pending', attempts: 0)
  end

  it 'keeps the committed mail intent when queueing fails' do
    allow(SendMailDeliveryJob).to receive(:perform_later).and_raise(IOError)
    expect { enqueue }.to change(described_class, :count).by(1)
    expect(described_class.last.status).to eq('pending')
  end
end
