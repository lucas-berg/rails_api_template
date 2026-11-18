# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Account lifecycle security', openapi: false do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }

  it 'requires the current password on the existing Devise deletion endpoint' do
    signed_headers = headers
    expect {
      delete user_registration_path, headers: signed_headers, as: :json
    }.not_to change(DeletionRequest, :count)
    expect(response).to have_http_status(:bad_request)
  end

  it 'rejects an incorrect deletion password without changing the account' do
    delete user_registration_path, headers: headers, params: { current_password: 'incorrect' }, as: :json
    expect(response).to have_http_status(:forbidden)
    expect(DeletionRequest.where(subject: user)).to be_empty
    expect(user.reload).to be_active
  end

  it 'rejects account deletion while the user remains the sole team owner' do
    Teams::Create.call(actor: user, attributes: { name: 'Owned team' })
    delete user_registration_path, headers: headers, params: { current_password: user.password }, as: :json
    expect(response).to have_http_status(:conflict)
    expect(json.fetch(:errors).first.fetch(:code)).to eq('last_owner')
    expect(DeletionRequest.where(subject: user)).to be_empty
  end

  it 'rejects a deleted account JWT and password even if its status was accidentally set active' do
    signed_headers = headers
    password = user.password
    # Authentication must still fail closed after a write that bypassed model validation.
    # rubocop:disable-next Rails/SkipsModelValidations
    user.update_columns(deleted_at: Time.current, status: 'active')
    get api_v1_user_path, headers: signed_headers
    expect(response).to have_http_status(:unauthorized)

    post user_session_path, params: { user: { email: user.email, password: } }, as: :json
    expect(response).to have_http_status(:unauthorized)
    expect(response.headers['Authorization']).to be_nil
  end

  it 'does not overwrite a profile anonymized after authentication but before its update lock' do
    signed_headers = headers
    controller = API::V1::UsersController.new
    allow(API::V1::UsersController).to receive(:new).and_return(controller)
    allow(controller).to receive(:update_user_params).and_wrap_original do |original|
      attributes = original.call
      # Simulate the lifecycle worker's controlled anonymization after request authentication.
      # rubocop:disable-next Rails/SkipsModelValidations
      user.update_columns(deleted_at: Time.current, status: 'suspended', username: '')
      attributes
    end

    patch api_v1_user_path, params: { user: { username: 'Should not return' } }, headers: signed_headers, as: :json
    expect(response).to have_http_status(:unauthorized)
    expect(user.reload.username).to eq('')
    expect(user.deleted_at).to be_present
  end

  it 'does not reintroduce email through the inherited Devise account update after anonymization' do
    signed_headers = headers
    password = user.password
    controller = Users::RegistrationsController.new
    allow(Users::RegistrationsController).to receive(:new).and_return(controller)
    allow(controller).to receive(:update_resource).and_wrap_original do |original, resource, attributes|
      # Reproduce cleanup committing after Devise loaded the request's account instance.
      # rubocop:disable-next Rails/SkipsModelValidations
      user.update_columns(deleted_at: Time.current, status: 'suspended',
                          email: "deleted-#{user.id}@deleted.invalid", unconfirmed_email: nil)
      original.call(resource, attributes)
    end

    put user_registration_path, headers: signed_headers,
                                params: { user: { current_password: password, email: 'reintroduced@example.com' } },
                                as: :json
    expect(response).to have_http_status(:unprocessable_content)
    expect(user.reload.unconfirmed_email).to be_nil
    expect(user.email).to end_with('@deleted.invalid')
  end

  it 'does not write login tracking data after anonymization commits during authentication' do
    email = user.email
    password = user.password
    allow(User).to receive(:find_for_database_authentication).and_return(user)
    allow(user).to receive(:update_tracked_fields!).and_wrap_original do |original, request|
      # Cleanup commits after Devise verified credentials, before its tracking callback writes.
      # rubocop:disable-next Rails/SkipsModelValidations
      User.find(user.id).update_columns(deleted_at: Time.current, status: 'suspended',
                                        email: "deleted-#{user.id}@deleted.invalid", sign_in_count: 0,
                                        current_sign_in_ip: nil, last_sign_in_ip: nil,
                                        current_sign_in_at: nil, last_sign_in_at: nil)
      original.call(request)
    end

    post user_session_path, params: { user: { email:, password: } }, as: :json

    expect(response).to have_http_status(:unauthorized)
    expect(response.headers['Authorization']).to be_nil
    expect(user.reload.sign_in_count).to eq(0)
    expect(user.current_sign_in_ip).to be_nil
    expect(user.last_sign_in_ip).to be_nil
    expect(user.current_sign_in_at).to be_nil
    expect(user.last_sign_in_at).to be_nil
  end
end
