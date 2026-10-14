class AllowReusingArchivedMenuItemNames < ActiveRecord::Migration[8.1]
  def change
    remove_index :menu_items, name: "index_menu_items_on_restaurant_id_and_name"
    add_index :menu_items, [ :restaurant_id, :name ], unique: true, where: "archived_at IS NULL"
  end
end
