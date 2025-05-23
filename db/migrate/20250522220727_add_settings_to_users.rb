class AddSettingsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :date_format, :string
    add_column :users, :theme, :string
    add_column :users, :language, :string
    add_column :users, :notification_settings, :json
  end
end
