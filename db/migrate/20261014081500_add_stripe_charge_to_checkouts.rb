class AddStripeChargeToCheckouts < ActiveRecord::Migration[8.1]
  def change
    add_column :checkouts, :stripe_charge_id, :string
    add_index :checkouts, :stripe_charge_id
  end
end
