# frozen_string_literal: true

if Rails.env.development?
  AdminUser.find_or_create_by!(email: 'admin@example.com') do |admin|
    admin.password = 'password'
    admin.role = 'super_admin'
  end
end

Setting.find_or_create_by!(key: 'min_version') { |setting| setting.value = '0.0' }
