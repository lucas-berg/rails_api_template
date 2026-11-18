# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SendMailDeliveryJob do
  let(:user) { create(:user) }

  before do
    clear_enqueued_jobs
    ActionMailer::Base.deliveries.clear
  end

  it 'sends a confirmation using the token format of the installed Devise version' do
    account = create(:user, confirmed_at: nil)
    delivery = MailDelivery.where(user_id: account.id).last
    token = delivery.payload.fetch('args').first
    expect { described_class.perform_now(delivery.id) }.to change(ActionMailer::Base.deliveries, :count).by(1)
    expect(ActionMailer::Base.deliveries.last.body.encoded).to include(token)
    expect(delivery.reload.status).to eq('sent')
  end

  it 'sends reconfirmation to the new email while retaining the original login email' do
    old_email = user.email
    user.update!(email: 'new-address@example.com')
    delivery = MailDelivery.where(user_id: user.id).last
    described_class.perform_now(delivery.id)
    expect(ActionMailer::Base.deliveries.last.to).to eq(['new-address@example.com'])
    expect(user.reload.email).to eq(old_email)
  end

  it 'does not send a confirmation after the email has already been confirmed' do
    account = create(:user, confirmed_at: nil)
    delivery = MailDelivery.where(user_id: account.id).last
    account.confirm
    expect { described_class.perform_now(delivery.id) }.not_to change(ActionMailer::Base.deliveries, :count)
    expect(delivery.reload.status).to eq('skipped')
  end

  it 'allows a deliberate confirmation resend even when the token remains unchanged' do
    account = create(:user, confirmed_at: nil)
    first_delivery = MailDelivery.where(user_id: account.id).last
    described_class.perform_now(first_delivery.id)
    account.send_confirmation_instructions
    next_delivery = MailDelivery.where(user_id: account.id).last
    expect(next_delivery.id).not_to eq(first_delivery.id)
    expect { described_class.perform_now(next_delivery.id) }.to change(ActionMailer::Base.deliveries, :count).by(1)
  end

  it 'sends the current password reset and clears its encrypted token' do
    token = user.send_reset_password_instructions
    delivery = MailDelivery.where(user_id: user.id).last
    expect { described_class.perform_now(delivery.id) }.to change(ActionMailer::Base.deliveries, :count).by(1)
    expect(ActionMailer::Base.deliveries.last.to).to eq([user.email])
    expect(ActionMailer::Base.deliveries.last.body.encoded).to include(token)
    expect(delivery.reload).to have_attributes(status: 'sent', encrypted_payload: nil)
    expect { described_class.perform_now(delivery.id) }.not_to change(ActionMailer::Base.deliveries, :count)
  end

  it 'skips superseded password reset tokens' do
    user.send_reset_password_instructions
    old_delivery = MailDelivery.where(user_id: user.id).last
    user.send_reset_password_instructions
    expect { described_class.perform_now(old_delivery.id) }.not_to change(ActionMailer::Base.deliveries, :count)
    expect(old_delivery.reload.status).to eq('skipped')
    expect(old_delivery.encrypted_payload).to be_nil
  end

  it 'skips expired password reset tokens' do
    user.send_reset_password_instructions
    delivery = MailDelivery.where(user_id: user.id).last
    travel 7.hours do
      expect { described_class.perform_now(delivery.id) }.not_to change(ActionMailer::Base.deliveries, :count)
      expect(delivery.reload.status).to eq('skipped')
    end
  end

  it 'preserves payload and backs off after a mail transport failure' do
    user.send_reset_password_instructions
    delivery = MailDelivery.where(user_id: user.id).last
    message = instance_double(ActionMailer::MessageDelivery)
    builder = instance_double(MailDeliveryMessage, build: message)
    allow(MailDeliveryMessage).to receive(:new).with(delivery).and_return(builder)
    allow(message).to receive(:deliver_now).and_raise(IOError, 'private connection data')
    described_class.perform_now(delivery.id)
    expect(delivery.reload).to have_attributes(status: 'pending', attempts: 1, last_error: 'IOError')
    expect(delivery.encrypted_payload).to be_present
    expect(delivery.next_attempt_at).to be > Time.current
  end

  it 'ignores a delivery removed by retention cleanup' do
    expect { described_class.perform_now(-1) }.not_to raise_error
  end
end
