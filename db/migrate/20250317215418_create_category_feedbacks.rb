class CreateCategoryFeedbacks < ActiveRecord::Migration[8.0]
  def change
    create_table :category_feedbacks do |t|
      t.references :user, null: false, foreign_key: true
      t.references :transaction_record, null: false, foreign_key: { to_table: :transactions }
      t.references :suggested_category, null: false, foreign_key: { to_table: :categories }
      t.references :chosen_category, null: false, foreign_key: { to_table: :categories }
      t.string :feedback_type

      t.timestamps
    end
  end
end
