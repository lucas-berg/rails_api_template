# frozen_string_literal: true

namespace :tailwindcss do
  desc 'Build the customer-facing Tailwind and DaisyUI stylesheet'
  task :build_users, [:mode] => :environment do |_task, args|
    input = Rails.root.join('app/assets/tailwind/users.css')
    output = Rails.root.join('app/assets/builds/users.css')
    command = [Tailwindcss::Ruby.executable, '-i', input.to_s, '-o', output.to_s]
    command << '--minify' if Rails.application.config.assets.css_compressor.blank?
    if args[:mode] == 'watch'
      exec(*command, '--watch=always')
    else
      system(*command, exception: true)
    end
  end
end

Rake::Task['assets:precompile'].enhance(['tailwindcss:build_users'])
