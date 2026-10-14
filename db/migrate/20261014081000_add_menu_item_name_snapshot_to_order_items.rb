class AddMenuItemNameSnapshotToOrderItems < ActiveRecord::Migration[8.1]
  def up
    add_column :order_items, :menu_item_name, :string
    execute <<~SQL.squish
      UPDATE order_items
      SET menu_item_name = menu_items.name
      FROM menu_items
      WHERE order_items.menu_item_id = menu_items.id
    SQL
    change_column_null :order_items, :menu_item_name, false
  end

  def down
    remove_column :order_items, :menu_item_name
  end
end
