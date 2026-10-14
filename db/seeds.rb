if Rails.env.development?
  restaurant_data = [
    {
      name: "The Corner Table",
      description: "Comforting neighborhood favorites, made fresh every day.",
      menu_items: [
        { name: "Roasted Tomato Soup", description: "Slow-roasted tomatoes, basil, and sourdough.", price: 8.50 },
        { name: "Grilled Cheese", description: "A golden sourdough toastie with aged cheddar.", price: 10.00 },
        { name: "Garden Salad", description: "Market greens, cucumber, tomato, and lemon dressing.", price: 9.50 }
      ]
    },
    {
      name: "Little Napoli",
      description: "Hand-stretched pizza and pasta with a little Italian sunshine.",
      menu_items: [
        { name: "Margherita Pizza", description: "Tomato, mozzarella, and fresh basil.", price: 15.00 },
        { name: "Mushroom Tagliatelle", description: "Wild mushrooms, parmesan, and ribbons of pasta.", price: 17.50 },
        { name: "Tiramisu", description: "Espresso-soaked layers with mascarpone cream.", price: 7.00 }
      ]
    },
    {
      name: "Saffron & Spice",
      description: "Bright, fragrant bowls inspired by kitchens around the world.",
      menu_items: [
        { name: "Crispy Falafel Bowl", description: "Herbed falafel, hummus, pickles, and greens.", price: 14.00 },
        { name: "Chicken Shawarma Wrap", description: "Spiced chicken, crunchy salad, and garlic sauce.", price: 15.50 },
        { name: "Mango Lassi", description: "Chilled yogurt blended with ripe mango.", price: 5.50 }
      ]
    }
  ]

  seeded_restaurants = restaurant_data.to_h do |attributes|
    restaurant = Restaurant.find_or_create_by!(name: attributes[:name]) do |record|
      record.description = attributes[:description]
    end

    menu_items = attributes[:menu_items].map do |item_attributes|
      MenuItem.find_or_create_by!(restaurant: restaurant, name: item_attributes[:name]) do |item|
        item.description = item_attributes[:description]
        item.price = item_attributes[:price]
      end
    end

    [ restaurant.name, { restaurant: restaurant, menu_items: menu_items } ]
  end

  customer = User.find_or_create_by!(email_address: "demo.customer@example.test") do |user|
    user.password = "password"
    user.role = :customer
  end

  AdminAccount.find_or_create_by!(email_address: "demo.admin@example.test") do |admin|
    admin.password = "password"
  end

  staff_restaurant = seeded_restaurants.fetch("The Corner Table").fetch(:restaurant)
  staff = User.find_or_create_by!(email_address: "demo.staff@example.test") do |user|
    user.password = "password"
    user.role = :staff
    user.restaurant = staff_restaurant
  end

  sample_orders = [
    {
      customer_name: "Alex Rivera (sample order)",
      status: :completed,
      menu_item: seeded_restaurants.fetch("The Corner Table").fetch(:menu_items).first,
      quantity: 1
    },
    {
      customer_name: "Jordan Lee (sample order)",
      status: :preparing,
      menu_item: seeded_restaurants.fetch("The Corner Table").fetch(:menu_items).second,
      quantity: 2
    }
  ]

  sample_orders.each do |attributes|
    order = Order.find_or_initialize_by(
      restaurant: staff_restaurant,
      customer_name: attributes[:customer_name]
    )

    if order.new_record?
      order.assign_attributes(user: customer, created_by: staff, status: attributes[:status])
      order.order_items.build(
        menu_item: attributes[:menu_item],
        quantity: attributes[:quantity],
        unit_price: attributes[:menu_item].price
      )
      order.save!
    else
      OrderItem.find_or_create_by!(order: order, menu_item: attributes[:menu_item]) do |item|
        item.quantity = attributes[:quantity]
        item.unit_price = attributes[:menu_item].price
      end
    end
  end

  customer_cart =   Cart.find_or_create_by!(user: customer)
  [
    seeded_restaurants.fetch("Little Napoli").fetch(:menu_items).first,
    seeded_restaurants.fetch("Saffron & Spice").fetch(:menu_items).first
  ].each do |menu_item|
    CartItem.find_or_create_by!(cart: customer_cart, menu_item: menu_item) do |item|
      item.quantity = 1
    end
  end

  puts "Development demo data is ready."
  puts "Customer sign-in: demo.customer@example.test / password"
  puts "Staff sign-in: demo.staff@example.test / password"
end
