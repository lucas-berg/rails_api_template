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
        resources :uploads, only: :create do
          post :complete, on: :member
        end
        resources :files, only: %i[index show destroy] do
          get :download, on: :member
          get :preview, on: :member
        end
        resource :avatar, only: %i[update destroy]
        resource :dashboard, only: :show, controller: 'team_dashboards'
        resource :onboarding, only: :show, controller: 'team_onboarding'
        resources :exports, controller: 'data_exports', only: %i[index create show] do
          get :download, on: :member
        end
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

  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)
  namespace :admin do
    authenticate(:admin_user, ->(admin) { admin.super_admin? }) do
      mount Flipper::UI.app(Flipper) => '/feature-flags'
      mount GoodJob::Engine => '/jobs'
    end
  end

  if !Rails.env.production? || (ENV['SWAGGER_USERNAME'].present? && ENV['SWAGGER_PASSWORD'].present?)
    mount Rswag::Ui::Engine => '/api-docs'
    mount Rswag::Api::Engine => '/api-docs'
  end
end
