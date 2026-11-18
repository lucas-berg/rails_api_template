# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Notifications::Catalog do
  let(:user) { build(:user) }
  let(:team) { build(:team, locale: 'zh-CN') }

  it 'uses the explicit personal language before the team default' do
    user.preferences = { 'locale' => 'en' }
    content = described_class.text('member_role_changed', user:, team:)
    expect(content.fetch('title')).to eq('Your team role changed')
    user.preferences = { 'locale' => 'zh-CN' }
    team.locale = 'en'
    expect(described_class.text('member_role_changed', user:, team:).fetch('title')).to eq('您的团队角色已更改')
  end

  it 'uses the team language when no supported personal language is configured' do
    [nil, 'unsupported-locale'].each do |locale|
      user.preferences = { 'locale' => locale }
      expect(described_class.text('invitation_accepted', user:, team:).fetch('title')).to eq('您已加入团队')
    end
  end

  it 'falls back to English for unsupported values and personal notifications without a team' do
    user.preferences = { 'locale' => 'unsupported-locale' }
    team.locale = 'unsupported-locale'
    expect(described_class.text('password_changed', user:, team:).fetch('title')).to eq('Your password changed')
    expect(described_class.text('password_changed', user:).fetch('title')).to eq('Your password changed')
  end

  it 'falls back to the English field if a supported translation is missing' do
    I18n.backend.store_translations(:'zh-CN', notifications: { invitation_accepted: { body: nil } })
    content = described_class.text('invitation_accepted', user:, team:)
    expect(content).to eq('title' => '您已加入团队', 'body' => 'Your team invitation was accepted.')
  ensure
    I18n.backend.reload!
  end

  it 'provides both translated fields for every supported event without changing the calling locale' do
    I18n.with_locale(:en) do
      described_class::EVENTS.each_key do |kind|
        described_class::LOCALES.each do |locale|
          user.preferences = { 'locale' => locale }
          content = described_class.text(kind, user:, team:)
          expect(content.keys).to eq(%w[title body])
          expect(content.values).to all(be_present)
          expect(content.values).not_to include(/translation missing/i)
        end
      end
      expect(I18n.locale).to eq(:en)
    end
  end
end
