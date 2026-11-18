# frozen_string_literal: true

Rails.application.routes.draw do
  devise_for :users, controllers: {
    sessions: 'users/sessions',
    registrations: 'users/registrations',
    passwords: 'users/passwords',
    confirmations: 'users/confirmations'
  }

  authenticate :user do
    resource :account, only: :show, controller: 'users/accounts'
  end
  get '/invitations/accept', to: 'invitation_acceptances#show', as: :invitation_acceptance
  post '/invitations/accept', to: 'invitation_acceptances#create'

  namespace :api do
    namespace :v1, defaults: { format: :json } do
      get :status, to: 'health#status'
      get :ready, to: 'health#ready'
      resources :auth_sessions, only: %i[index destroy]
      resources :teams, only: %i[index show create update] do
        resources :members, only: %i[index update destroy]
        resources :invitations, only: %i[index create destroy] do
          post :resend, on: :member
        end
        resource :settings, only: %i[show update], controller: 'team_settings'
        resource :ownership_transfer, only: :create, controller: 'ownership_transfers'
        resources :audit_events, only: :index
        resources :notifications, only: :index do
          post :read, on: :member
        end
        resource :dashboard, only: :show, controller: 'team_dashboards'
        resource :onboarding, only: :show, controller: 'team_onboarding'
      end
      post 'invitations/accept', to: 'invitation_acceptances#create'
      resources :security_notifications, only: :index do
        post :read, on: :member
      end
      resource :notification_preferences, only: %i[show update], controller: 'notification_preferences'
      post 'teams/:team_id/deletion_request', to: 'deletion_requests#create'
      post 'user/deletion_request', to: 'deletion_requests#create'
      resources :deletion_requests, only: %i[show destroy]
      devise_scope :user do
        resource :user, only: %i[update show]
      end
      resources :settings, only: [] do
        get :must_update, on: :collection
      end
    end
  end

  devise_for :admin_users, path: 'admin', path_names: { sign_in: 'login', sign_out: 'logout' },
                           controllers: { sessions: 'admin/sessions', passwords: 'admin/passwords' }
  namespace :admin do
    root 'dashboard#show'
    resources :users, only: %i[index show] do
      post :suspend, on: :member
      post :restore, on: :member
    end
    resources :teams, only: %i[index show] do
      post :suspend, on: :member
      post :restore, on: :member
    end
    resources :admin_users, except: :destroy
    resources :members, only: %i[index show]
    resources :invitations, only: %i[index show]
    resources :auth_sessions, only: %i[index show]
    resources :audit_events, only: %i[index show]
    resources :notifications, only: %i[index show]
    resources :deletion_tombstones, only: %i[index show]
    resources :mail_deliveries, only: %i[index show] do
      post :retry_delivery, on: :member
    end
    resources :notification_deliveries, only: %i[index show] do
      post :retry_delivery, on: :member
    end
    resources :deletion_requests, only: %i[index show] do
      post :retry_cleanup, on: :member
    end
    authenticate(:admin_user, ->(admin) { Pundit.policy!(admin, %i[admin dashboard]).manage_tools? }) do
      mount Flipper::UI.app(Flipper) => '/feature-flags'
      mount GoodJob::Engine => '/jobs'
    end
  end

  if !Rails.env.production? || (ENV['SWAGGER_USERNAME'].present? && ENV['SWAGGER_PASSWORD'].present?)
    mount Rswag::Ui::Engine => '/api-docs'
    mount Rswag::Api::Engine => '/api-docs'
  end
end
