Clerk.configure do |c|
  # You can hardcode or use ENV here:
  c.secret_key = ENV["CLERK_SECRET_KEY"]
  c.publishable_key = ENV["NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY"]
  c.logger = Rails.logger
end
