# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User do
  it 'rolls registration back if confirmation mail intent cannot be stored' do
    allow(MailDelivery).to receive(:enqueue_devise).and_raise(ActiveRecord::RecordInvalid)

    expect {
      expect { create(:user, :unconfirmed) }.to raise_error(ActiveRecord::RecordInvalid)
    }.not_to change(described_class, :count)
  end

  it 'rolls the new reset token back if mail intent cannot be stored' do
    user = create(:user)
    allow(MailDelivery).to receive(:enqueue_devise).and_raise(ActiveRecord::RecordInvalid)

    expect { user.send_reset_password_instructions }.to raise_error(ActiveRecord::RecordInvalid)
    expect(user.reload.reset_password_token).to be_nil
  end

  it 'rolls reconfirmation back if mail intent cannot be stored' do
    user = create(:user, uid: nil)
    previous_email = user.email
    allow(MailDelivery).to receive(:enqueue_devise).and_raise(ActiveRecord::RecordInvalid)

    expect { user.update!(email: 'changed@example.com') }.to raise_error(ActiveRecord::RecordInvalid)
    expect(user.reload.email).to eq(previous_email)
    expect(user.unconfirmed_email).to be_nil
    expect(user.uid).to eq(previous_email)
  end

  it 'advances the stored credential version even for a stale password update' do
    user = create(:user)
    stale = described_class.find(user.id)
    user.update!(password: 'First-new-password!')
    stale.update!(password: 'Second-new-password!')

    expect(user.reload.credentials_version).to eq(2)
  end

  it 'does not register a login token issued against stale credentials' do
    user = create(:user)
    headers = Devise::JWT::TestHelpers.auth_headers({}, user)
    token = headers.fetch('Authorization').delete_prefix('Bearer ')
    payload = Warden::JWTAuth::TokenDecoder.new.call(token)
    user.update!(password: 'Changed-before-the-token-response!')

    expect { AuthSession.register!(user, payload) }.to raise_error(AuthSession::InvalidCredentials)
    expect(user.auth_sessions).to be_empty
  end
end
