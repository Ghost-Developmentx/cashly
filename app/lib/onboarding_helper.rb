class OnboardingHelper
  # Onboarding steps in order
  STEPS = [ :complete_profile, :connect_account, :add_transaction, :create_budget, :view_insights ]

  def self.get_next_step(user)
    # Return the next step the user should complete

    # Step 1: Complete profile
    return :complete_profile unless user.onboarding_completed?

    # Step 2: Connect account
    return :connect_account unless user.accounts.any?

    # Step 3: Add transaction
    return :add_transaction unless user.transactions.any?

    # Step 4: Create budget
    return :create_budget unless user.budgets.any?

    # Step 5: View insights
    # We assume this is complete if they have transactions, as insights are automatic

    # All steps completed
    nil
  end

  def self.completion_percentage(user)
    steps_completed = 0

    # Step 1: Complete profile
    steps_completed += 1 if user.onboarding_completed?

    # Step 2: Connect account
    steps_completed += 1 if user.accounts.any?

    # Step 3: Add transaction
    steps_completed += 1 if user.transactions.any?

    # Step 4: Create budget
    steps_completed += 1 if user.budgets.any?

    # Step 5: View insights (we mark as complete if they've viewed the dashboard after adding transactions)
    steps_completed += 1 if user.transactions.any? && user.tutorial_completed?

    # Calculate percentage
    (steps_completed.to_f / STEPS.size * 100).round
  end

  def self.get_step_url(step)
    case step
    when :complete_profile
      "/profile/onboarding"
    when :connect_account
      "/accounts"
    when :add_transaction
      "/transactions/new"
    when :create_budget
      "/budgets/new"
    when :view_insights
      "/dashboard"
    else
      "/dashboard"
    end
  end
end
