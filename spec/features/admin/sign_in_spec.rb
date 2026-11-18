# frozen_string_literal: true

RSpec.describe 'Admin SignIn' do
  feature 'Signing in', :js do
    let(:admin_user) { create(:admin_user) }

    scenario 'Admin signs in successfully' do
      visit admin_root_path
      expect(page).to have_current_path(new_admin_user_session_path)
      fill_in 'Email', with: admin_user.email
      fill_in 'Password', with: admin_user.password
      click_on 'Login'

      expect(page).to have_current_path(admin_root_path)
      expect(page).to have_css('.flash_notice', text: 'Signed in successfully.')
    end

    scenario 'Admin fails to sign in with invalid credentials' do
      visit admin_root_path
      expect(page).to have_current_path(new_admin_user_session_path)
      fill_in 'Email', with: 'wrong@example.com'
      fill_in 'Password', with: 'wrongpassword'
      click_on 'Login'

      expect(page).to have_css('.flash_alert',
                               text: I18n.t('devise.failure.invalid', authentication_keys: 'email'))
    end
  end
end
