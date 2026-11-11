class CreateInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :invitations do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :invited_by_user, foreign_key: { to_table: :users }
      t.references :invited_by_admin, foreign_key: { to_table: :admins }
      t.string :email_address, null: false
      t.string :role, null: false
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :accepted_at
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :invitations, :token_digest, unique: true
    add_index :invitations, [ :organization_id, :email_address, :accepted_at, :revoked_at ], name: "index_invitations_on_org_email_and_status"

    create_table :invitation_restaurants do |t|
      t.references :invitation, null: false, foreign_key: true
      t.references :restaurant, null: false, foreign_key: true
      t.timestamps
    end
    add_index :invitation_restaurants, [ :invitation_id, :restaurant_id ], unique: true
  end
end
