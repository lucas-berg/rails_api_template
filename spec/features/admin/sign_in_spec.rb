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

    scenario 'Admin searches an account, suspends access and reviews its audit trail' do
      user = create(:user, email: 'browser-review@example.com')
      team = Teams::Create.call(actor: user, attributes: { name: 'Example workspace' })
      create(:user, email: 'another-account@example.com')
      visit new_admin_user_session_path
      fill_in 'Email', with: admin_user.email
      fill_in 'Password', with: admin_user.password
      click_on 'Login'
      expect(page).to have_current_path(admin_root_path)
      expect(page).to have_text('team.created')
      page.current_window.resize_to(1440, 1100)
      # Opt-in screenshot supports visual review of the real, authenticated dashboard.
      if ENV['ADMIN_SCREENSHOT'] == 'true'
        page.save_screenshot(Rails.root.join('tmp/custom-admin-dashboard.png')) # rubocop:disable Lint/Debugger
      end

      within('.admin-nav') { click_on 'Accounts' }
      expect(page).to have_current_path(admin_users_path)
      fill_in 'Email', with: 'browser-review'
      click_on 'Search'
      expect(page).to have_current_path(admin_users_path, ignore_query: true)
      expect(page).to have_text(user.email)
      expect(page).to have_no_text('another-account@example.com')
      within('tbody') { click_on user.id.to_s }
      expect(page).to have_current_path(admin_user_path(user))
      fill_in 'Reason', with: 'Reviewed account abuse report'
      click_on 'Suspend account'
      expect(page).to have_text('Account status updated.')
      expect(page).to have_text('Suspended')
      expect(user.reload).to be_suspended

      within('.admin-nav') { click_on 'Audit history' }
      expect(page).to have_current_path(admin_audit_events_path)
      fill_in 'Action', with: 'user.suspend'
      click_on 'Search'
      within('tbody tr', text: 'user.suspend') { find('a').click }
      expect(page).to have_text('Reviewed account abuse report')
      expect(team.reload).to be_active
    end
  end
end
