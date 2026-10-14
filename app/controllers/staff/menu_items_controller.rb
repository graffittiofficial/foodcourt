module Staff
  class MenuItemsController < BaseController
    before_action :set_menu_item, only: %i[edit update archive]

    def index
      @menu_items = current_restaurant.menu_items.active.order(:name)
    end

    def new
      @menu_item = current_restaurant.menu_items.new
    end

    def create
      @menu_item = current_restaurant.menu_items.new(menu_item_params)
      if @menu_item.save
        redirect_to staff_menu_items_path, notice: "Menu item created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @menu_item.update(menu_item_params)
        redirect_to staff_menu_items_path, notice: "Menu item updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def archive
      @menu_item.update!(available: false, archived_at: Time.current)
      redirect_to staff_menu_items_path, notice: "Menu item archived."
    end

    private

    def set_menu_item
      @menu_item = current_restaurant.menu_items.active.find(params[:id])
    end

    def menu_item_params
      params.require(:menu_item).permit(:name, :description, :price, :available)
    end
  end
end
