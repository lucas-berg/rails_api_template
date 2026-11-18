# frozen_string_literal: true

require 'rails_helper'

# == Schema Information
#
# Table name: auth_sessions
#
#  id                  :bigint           not null, primary key
#  credentials_version :integer          not null
#  expires_at          :datetime         not null
#  ip_address          :inet
#  jti_digest          :string           not null
#  last_used_at        :datetime
#  revoked_at          :datetime
#  user_agent          :string(256)
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  user_id             :integer          not null
#
# Indexes
#
#  index_auth_sessions_on_expires_at  (expires_at)
#  index_auth_sessions_on_jti_digest  (jti_digest) UNIQUE
#  index_auth_sessions_on_user_id     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
RSpec.describe AuthSession do
  let(:user) { create(:user) }
  let(:payload) { Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).last }

  it 'keeps metadata optional for existing callers and test helpers' do
    session = described_class.register!(user, payload)
    expect(session).to have_attributes(user_agent: nil, ip_address: nil)
  end

  it 'bounds the raw agent string and removes control and formatting characters' do
    agent = ('A' * 250) + "\n\t\0\u007f\u202e" + ('B' * 50)
    session = described_class.register!(user, payload, context: { user_agent: agent, ip_address: '2001:db8::1' })
    expect(session.user_agent).to eq(('A' * 250) + ('B' * 6))
    expect(session.user_agent.length).to eq(256)
    expect(session.ip_address.to_s).to eq('2001:db8::1')
  end

  it 'drops malformed optional metadata without changing credential validation' do
    context = { user_agent: "Client\xff".dup.force_encoding(Encoding::UTF_8), ip_address: 'invalid' }
    session = described_class.register!(user, payload, context:)
    expect(session.user_agent).to eq('Client')
    expect(session.ip_address).to be_nil
    expect(session).to be_valid_for(user)
  end
end
