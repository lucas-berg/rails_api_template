# frozen_string_literal: true

module API
  module V1
    class UsersController < API::V1::APIController
      def show
        render 'api/v1/users/show'
      end

      def update
        attributes = update_user_params
        if attributes.key?(:email) && attributes[:email] != current_user.email
          raise ActiveRecord::RecordInvalid, current_user unless current_user.update_with_password(attributes)
        else
          current_user.update!(attributes.except(:current_password))
        end
        show
      end

      private

      def update_user_params
        params.expect(user: %i[username first_name last_name email current_password])
      end
    end
  end
end
