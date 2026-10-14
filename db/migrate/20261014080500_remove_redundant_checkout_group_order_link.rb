class RemoveRedundantCheckoutGroupOrderLink < ActiveRecord::Migration[8.1]
  def change
    remove_index :checkout_groups, :order_id, name: "index_checkout_groups_on_order_id"
    remove_reference :checkout_groups, :order, foreign_key: true, index: false
  end
end
