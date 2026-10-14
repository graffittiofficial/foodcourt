# Foodcourt Context

This project is a Rails-based food ordering application for a food court or restaurant platform.

## Core vocabulary

- Foodcourt: the product domain and application as a whole.
- Order: a customer order that contains one or more items.
- Cart: the current basket before an order is placed.
- Menu item: a selectable food or beverage item offered to customers.
- Restaurant: a provider or vendor that sells items in the system.
- Staff user: an authenticated user assigned to one restaurant and limited to that restaurant's operational data.
- Staff dashboard: the restaurant-scoped workspace for managing menu items and orders and reviewing daily sales.
- Driver: an account assigned deliveries by an administrator; drivers can update only the delivery milestones for their assigned Orders.
- Delivery status: the customer-facing fulfillment milestones unassigned, assigned, picked up, and delivered, separate from kitchen order status.
- Checkout group: the items and delivery quote for one restaurant within a customer checkout; successful payment creates one restaurant-scoped Order per group.
- Checkout: the flow where a customer confirms an order and completes payment.
- User: an authenticated person interacting with the app.
- Menu availability: whether an active menu item can be ordered; archived items are removed from the active menu.
- Order status: the kitchen workflow states pending, preparing, ready, completed, and cancelled.

## Use this vocabulary consistently

Prefer these terms in code, tests, and issue titles unless a more specific domain term is already defined in a relevant ADR or feature context.
