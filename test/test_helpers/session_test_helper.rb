module SessionTestHelper
  def sign_in_as(user, select_restaurant: true)
    Current.session = user.sessions.create!

    ActionDispatch::TestRequest.create.cookie_jar.tap do |cookie_jar|
      cookie_jar.signed[:session_id] = Current.session.id
      cookies["session_id"] = cookie_jar[:session_id]
    end
    if select_restaurant && user.is_a?(User) && user.staff?
      patch select_staff_restaurant_path(user.restaurants.first)
    end
  end

  def sign_in_as_staff(user, restaurant)
    sign_in_as(user, select_restaurant: false)
    patch select_staff_restaurant_path(restaurant)
  end

  def sign_out
    Current.session&.destroy!
    cookies.delete("session_id")
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include SessionTestHelper
end
