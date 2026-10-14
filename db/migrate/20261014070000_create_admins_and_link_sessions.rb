class CreateAdminsAndLinkSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :admins do |t|
      t.string :email_address, null: false
      t.string :password_digest, null: false

      t.timestamps
    end
    add_index :admins, :email_address, unique: true

    change_column_null :sessions, :user_id, true
    add_reference :sessions, :admin, foreign_key: true
    add_check_constraint :sessions,
      "(user_id IS NOT NULL AND admin_id IS NULL) OR (user_id IS NULL AND admin_id IS NOT NULL)",
      name: "sessions_belong_to_one_account"
  end
end
