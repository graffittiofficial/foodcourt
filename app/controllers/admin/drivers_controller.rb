module Admin
  class DriversController < BaseController
    def index
      @drivers = User.driver.order(:name, :email_address)
    end

    def new
      @driver = User.new(role: :driver)
    end

    def create
      @driver = User.new(driver_params.merge(role: :driver))
      if @driver.save
        redirect_to admin_drivers_path, notice: "Driver account created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    private

    def driver_params
      params.require(:user).permit(:name, :email_address, :password, :password_confirmation)
    end
  end
end
