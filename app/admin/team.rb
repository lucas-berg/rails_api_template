# frozen_string_literal: true

ActiveAdmin.register Team do
  actions :index, :show
  filter :name
  filter :status, as: :select, collection: %w[active suspended]

  %i[suspend restore].each do |operation|
    member_action operation, method: :post do
      authorize! operation, resource
      status = operation == :suspend ? 'suspended' : 'active'
      Platform::ChangeStatus.new(actor: current_admin_user, target: resource, request_id: request.request_id)
                            .call(status:, reason: params.require(:reason))
      redirect_to resource_path, notice: I18n.t('saas.admin.team_updated')
    end
  end

  index do
    id_column
    column :name
    column :status
    column :locale
    column :timezone
    actions
  end

  show do
    attributes_table do
      row :name
      row :status
      row :locale
      row :timezone
      row :created_at
    end
    if current_admin_user.super_admin? && %w[active suspended].include?(resource.status)
      panel 'Change team status' do
        %w[suspend restore].each do |operation|
          form action: "/admin/teams/#{resource.id}/#{operation}", method: :post do
            input type: :hidden, name: :authenticity_token, value: form_authenticity_token
            input type: :text, name: :reason, placeholder: 'Reason', required: true
            input type: :submit, value: operation.capitalize
          end
        end
      end
    end
  end
end
