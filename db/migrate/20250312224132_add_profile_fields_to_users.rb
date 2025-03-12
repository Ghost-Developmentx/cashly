class AddProfileFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :first_name, :string
    add_column :users, :last_name, :string
    add_column :users, :phone_number, :string
    add_column :users, :timezone, :string, default: "UTC"

    # Company information
    add_column :users, :company_name, :string
    add_column :users, :company_size, :string
    add_column :users, :industry, :string
    add_column :users, :business_type, :string

    # Preferences
    add_column :users, :currency, :string, default: "USD"
    add_column :users, :fiscal_year_start, :date
    add_column :users, :onboarding_completed, :boolean, default: false
    add_column :users, :tutorial_completed, :boolean, default: false

    # Additional contact information
    add_column :users, :address_line1, :string
    add_column :users, :address_line2, :string
    add_column :users, :city, :string
    add_column :users, :state, :string
    add_column :users, :zip_code, :string
    add_column :users, :country, :string, default: "US"
  end
end
