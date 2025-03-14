# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_03_15_140339) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name"
    t.string "account_type"
    t.decimal "balance"
    t.string "institution"
    t.datetime "last_synced"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "plaid_account_id"
    t.datetime "last_synced_at"
    t.index ["plaid_account_id"], name: "index_accounts_on_plaid_account_id", unique: true, where: "(plaid_account_id IS NOT NULL)"
    t.index ["user_id"], name: "index_accounts_on_user_id"
  end

  create_table "budgets", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "category_id", null: false
    t.decimal "amount"
    t.date "period_start"
    t.date "period_end"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_budgets_on_category_id"
    t.index ["user_id"], name: "index_budgets_on_user_id"
  end

  create_table "categories", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.bigint "parent_category_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_category_id"], name: "index_categories_on_parent_category_id"
  end

  create_table "category_account_mappings", force: :cascade do |t|
    t.bigint "category_id", null: false
    t.bigint "ledger_account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id", "ledger_account_id"], name: "index_category_ledger_account_unique", unique: true
    t.index ["category_id"], name: "index_category_account_mappings_on_category_id"
    t.index ["ledger_account_id"], name: "index_category_account_mappings_on_ledger_account_id"
  end

  create_table "integrations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "provider", null: false
    t.string "status", default: "active"
    t.text "credentials", null: false
    t.datetime "connected_at"
    t.datetime "last_used_at"
    t.datetime "expires_at"
    t.text "metadata", default: "{}"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_integrations_on_status"
    t.index ["user_id", "provider"], name: "index_integrations_on_user_id_and_provider", unique: true
    t.index ["user_id"], name: "index_integrations_on_user_id"
  end

  create_table "invoices", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "client_name"
    t.decimal "amount"
    t.date "issue_date"
    t.date "due_date"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "stripe_invoice_id"
    t.string "stripe_payment_intent_id"
    t.string "stripe_subscription_id"
    t.string "stripe_customer_id"
    t.string "payment_status", default: "awaiting_payment"
    t.string "payment_method"
    t.datetime "last_payment_attempt"
    t.date "next_payment_date"
    t.boolean "recurring", default: false
    t.string "recurring_interval"
    t.integer "recurring_period"
    t.string "template", default: "default"
    t.string "currency", default: "usd"
    t.string "client_email"
    t.text "client_address"
    t.text "notes"
    t.text "terms"
    t.jsonb "custom_fields", default: {}
    t.index ["payment_status"], name: "index_invoices_on_payment_status"
    t.index ["stripe_invoice_id"], name: "index_invoices_on_stripe_invoice_id"
    t.index ["stripe_subscription_id"], name: "index_invoices_on_stripe_subscription_id"
    t.index ["user_id"], name: "index_invoices_on_user_id"
  end

  create_table "journal_entries", force: :cascade do |t|
    t.date "date", null: false
    t.string "reference"
    t.text "description"
    t.string "status", default: "draft"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["date"], name: "index_journal_entries_on_date"
    t.index ["reference"], name: "index_journal_entries_on_reference"
    t.index ["status"], name: "index_journal_entries_on_status"
    t.index ["user_id"], name: "index_journal_entries_on_user_id"
  end

  create_table "journal_lines", force: :cascade do |t|
    t.bigint "journal_entry_id", null: false
    t.bigint "ledger_account_id", null: false
    t.decimal "debit_amount", precision: 15, scale: 2, default: "0.0"
    t.decimal "credit_amount", precision: 15, scale: 2, default: "0.0"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_increase", default: true
    t.decimal "net_amount", precision: 15, scale: 2, default: "0.0"
    t.index ["is_increase"], name: "index_journal_lines_on_is_increase"
    t.index ["journal_entry_id", "ledger_account_id"], name: "index_journal_lines_on_journal_entry_id_and_ledger_account_id"
    t.index ["journal_entry_id"], name: "index_journal_lines_on_journal_entry_id"
    t.index ["ledger_account_id"], name: "index_journal_lines_on_ledger_account_id"
  end

  create_table "ledger_accounts", force: :cascade do |t|
    t.string "name", null: false
    t.string "code", null: false
    t.string "account_type", null: false
    t.string "account_subtype"
    t.text "description"
    t.bigint "parent_account_id"
    t.boolean "active", default: true, null: false
    t.string "default_balance", default: "debit", null: false
    t.integer "display_order"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_type", "account_subtype"], name: "index_ledger_accounts_on_account_type_and_account_subtype"
    t.index ["active"], name: "index_ledger_accounts_on_active"
    t.index ["code"], name: "index_ledger_accounts_on_code", unique: true
    t.index ["parent_account_id"], name: "index_ledger_accounts_on_parent_account_id"
  end

  create_table "plaid_tokens", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "encrypted_access_token"
    t.string "item_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "encrypted_access_token_iv"
    t.index ["item_id"], name: "index_plaid_tokens_on_item_id", unique: true
    t.index ["user_id"], name: "index_plaid_tokens_on_user_id"
  end

  create_table "transactions", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.decimal "amount"
    t.datetime "date"
    t.text "description"
    t.bigint "category_id", null: false
    t.boolean "recurring"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "plaid_transaction_id"
    t.bigint "journal_entry_id"
    t.index ["account_id"], name: "index_transactions_on_account_id"
    t.index ["category_id"], name: "index_transactions_on_category_id"
    t.index ["journal_entry_id"], name: "index_transactions_on_journal_entry_id"
    t.index ["plaid_transaction_id"], name: "index_transactions_on_plaid_transaction_id", unique: true, where: "(plaid_transaction_id IS NOT NULL)"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "phone_number"
    t.string "timezone", default: "UTC"
    t.string "company_name"
    t.string "company_size"
    t.string "industry"
    t.string "business_type"
    t.string "currency", default: "USD"
    t.date "fiscal_year_start"
    t.boolean "onboarding_completed", default: false
    t.boolean "tutorial_completed", default: false
    t.string "address_line1"
    t.string "address_line2"
    t.string "city"
    t.string "state"
    t.string "zip_code"
    t.string "country", default: "US"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.string "provider"
    t.string "uid"
    t.string "stripe_customer_id"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["stripe_customer_id"], name: "index_users_on_stripe_customer_id"
  end

  add_foreign_key "accounts", "users"
  add_foreign_key "budgets", "categories"
  add_foreign_key "budgets", "users"
  add_foreign_key "categories", "categories", column: "parent_category_id"
  add_foreign_key "category_account_mappings", "categories"
  add_foreign_key "category_account_mappings", "ledger_accounts"
  add_foreign_key "integrations", "users"
  add_foreign_key "invoices", "users"
  add_foreign_key "journal_entries", "users"
  add_foreign_key "journal_lines", "journal_entries"
  add_foreign_key "journal_lines", "ledger_accounts"
  add_foreign_key "ledger_accounts", "ledger_accounts", column: "parent_account_id"
  add_foreign_key "plaid_tokens", "users"
  add_foreign_key "transactions", "accounts"
  add_foreign_key "transactions", "categories"
  add_foreign_key "transactions", "journal_entries"
end
