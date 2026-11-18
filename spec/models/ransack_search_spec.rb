# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ransack do
  {
    User => [{ email_cont: 'example', username_cont: 'reader', status_eq: 'active', id_eq: 1 },
             %w[encrypted_password reset_password_token confirmation_token tokens credentials_version]],
    AdminUser => [{ email_cont: 'example', role_eq: 'support' }, %w[encrypted_password reset_password_token]],
    Team => [{ name_cont: 'Project', status_eq: 'active', id_eq: 1 }, %w[deleted_at]],
    Member => [{ team_id_eq: 1, user_id_eq: 1, role_eq: 'viewer', status_eq: 'active' }, %w[created_at]],
    Invitation => [{ team_id_eq: 1, normalized_email_cont: 'example', role_eq: 'member' }, %w[token_digest]],
    AuthSession => [{ user_id_eq: 1 }, %w[jti_digest user_agent ip_address credentials_version]],
    AuditEvent => [{ team_id_eq: 1, actor_type_eq: 'User', actor_id_eq: 1, action_cont: 'changed',
                     target_type_eq: 'Team', target_id_eq: 1, occurred_at_gteq: '2026-01-01' }, %w[metadata reason]],
    MailDelivery => [{ status_eq: 'failed', kind_eq: 'devise', team_id_eq: 1, user_id_eq: 1 },
                     %w[encrypted_payload event_key lease_token]],
    Notification => [{ user_id_eq: 1, team_id_eq: 1, kind_eq: 'invitation_accepted', category_eq: 'activity' },
                     %w[event_key]],
    NotificationDelivery => [{ status_eq: 'failed', channel_eq: 'email', notification_id_eq: 1 },
                             %w[lease_token last_error]],
    DeletionRequest => [{ subject_type_eq: 'User', subject_id_eq: 1, status_eq: 'pending' },
                        %w[encrypted_recipient uuid]],
    DeletionTombstone => [{ subject_type_eq: 'Team', subject_id_eq: 1 }, %w[fingerprint request_uuid]]
  }.each do |model, (filters, protected_attributes)|
    context "when searching #{model.name}" do
      it 'accepts the explicit fields used by its administration form' do
        search = model.ransack!(filters)
        attributes = search.conditions.flat_map { |condition| condition.attributes.map(&:name) }
        expect(attributes).to match_array(model.ransackable_attributes)
      end

      it 'rejects protected fields even when the caller has permitted the request parameters' do
        expect(model.column_names).to include(*protected_attributes)
        protected_attributes.each do |attribute|
          parameters = ActionController::Parameters.new("#{attribute}_eq" => 'probe').permit!
          expect { model.ransack!(parameters).result }.to raise_error(described_class::InvalidSearchError)
        end
      end

      it 'does not allow callers to traverse associations or invoke arbitrary model scopes' do
        model.reflect_on_all_associations.each do |association|
          expect {
            model.ransack!("#{association.name}_created_at_gteq" => '2026-01-01').result
          }.to raise_error(described_class::InvalidSearchError)
        end
        expect { model.ransack!(unscoped: true).result }.to raise_error(described_class::InvalidSearchError)
      end
    end
  end

  it 'filters ordinary business fields within the original authorized relation' do
    match = create(:user, email: 'search-reader@example.com', username: 'Reader')
    outsider = create(:user, email: 'search-other@example.com', username: 'Reader')
    search = User.where(id: match.id).ransack!(email_cont: 'search-', username_cont: 'Read', status_eq: 'active')

    expect(search.result).to contain_exactly(match)
    expect(search.result).not_to include(outsider)
  end

  it 'rejects sensitive sorting and mixed public/private conditions' do
    expect { User.ransack!(s: 'encrypted_password asc') }.to raise_error(described_class::InvalidSearchError)
    expect {
      User.ransack!(email_or_reset_password_token_cont: 'probe').result
    }.to raise_error(described_class::InvalidSearchError)
  end
end
