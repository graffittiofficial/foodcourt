class CreateReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :reviews do |t|
      t.references :user, null: false, foreign_key: true
      t.references :order, null: false, foreign_key: true
      t.references :reviewable, polymorphic: true, null: false, index: false
      t.integer :rating, null: false
      t.text :body

      t.timestamps
    end

    add_index :reviews, %i[order_id reviewable_type reviewable_id], unique: true, name: "index_reviews_on_order_and_reviewable"
    add_index :reviews, %i[reviewable_type reviewable_id]
    add_check_constraint :reviews, "rating BETWEEN 1 AND 5", name: "reviews_rating_in_range"
  end
end
