class CreateForecasts < ActiveRecord::Migration[8.0]
  def change
    create_table :forecasts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.integer :time_horizon, null: false, default: 30
      t.text :result_data
      t.text :included_category_ids
      t.string :scenario_type, default: "default"

      t.timestamps
    end

    add_index :forecasts, [ :user_id, :name ]
  end
end
