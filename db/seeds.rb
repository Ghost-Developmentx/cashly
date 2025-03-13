# Load default categories
load(Rails.root.join('db', 'seeds', 'categories.rb'))

# Create admin user if in development
if Rails.env.development?
  admin_email = "admin@example.com"
  unless User.exists?(email: admin_email)
    User.create!(
    email: admin_email,
    password: "password",
    password_confirmation: "password",
    first_name: "Admin",
    last_name: "User",
    company_name: "Cashly Dev",
    onboarding_completed: true,
    tutorial_completed: true
    )
    puts "Admin User created: #{admin_email}, password: password"
  end
end
