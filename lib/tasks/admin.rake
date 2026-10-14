namespace :admin do
  desc "Grant admin access to an existing user by email address"
  task :grant, [ :email_address ] => :environment do |_task, args|
    email_address = args[:email_address].to_s.strip.downcase
    abort "Usage: bin/rails 'admin:grant[email@example.com]'" if email_address.blank?

    user = User.find_by(email_address: email_address)
    abort "No user found for #{email_address}" unless user

    user.update!(admin: true)
    puts "Admin access granted to #{user.email_address}"
  end
end
