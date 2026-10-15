module Admin
  class MenuItemsController < BaseController
    before_action :set_restaurant
    before_action :set_menu_item

    def edit
    end

    def update
      if @menu_item.update(menu_item_params)
        redirect_to edit_admin_restaurant_path(@restaurant), notice: "Menu item photo updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_restaurant
      @restaurant = Restaurant.find(params[:restaurant_id])
    end

    def set_menu_item
      @menu_item = @restaurant.menu_items.active.find(params[:id])
    end

    def menu_item_params
      params.require(:menu_item).permit(:photo)
    end
  end
end
