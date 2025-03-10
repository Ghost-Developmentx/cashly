class CreateCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :categories do |t|
      t.string :name
      t.text :description
      t.references :parent_category, null: true, foreign_key: { to_table: :categories }

      t.timestamps
    end
  end
end
