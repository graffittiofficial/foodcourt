# Foodcourt Glossary

This project is a Rails-based food ordering application for a food court or restaurant platform.

## Core vocabulary

- Foodcourt: the product domain and application as a whole.
- Order: a customer order that contains one or more items.
- Cart: the current basket before an order is placed.
- Menu item: a selectable food or beverage item offered to customers.
- Restaurant: a provider or vendor that sells items in the system.
- Organization: the account boundary that owns one or more Restaurants and their management access.
- Organization admin: a User who can manage an Organization's Restaurants, staff, menus, and orders, but not platform or payout settings.
- Restaurant staff: a User assigned to one or more Restaurants within a single Organization, with operational access limited to the selected Restaurant.
- Membership: the persisted access assignment connecting a User to an Organization or Restaurant.
- Invitation: a time-limited, revocable request to join an Organization as an admin or as Restaurant staff.
- Staff dashboard: the selected-Restaurant workspace for managing menu items and orders and reviewing daily sales.
- Driver: an account assigned deliveries by an administrator; drivers can update only the delivery milestones for their assigned Orders.
- Delivery status: the customer-facing fulfillment milestones unassigned, assigned, picked up, and delivered, separate from kitchen order status.
- Checkout group: the items and delivery quote for one restaurant within a customer checkout; successful payment creates one restaurant-scoped Order per group.
- Checkout: the flow where a customer confirms an order and completes payment.
- User: an authenticated person interacting with the app.
- Menu availability: whether an active menu item can be ordered; archived items are removed from the active menu.
- Order status: the kitchen workflow states pending, preparing, ready, completed, and cancelled.
- Restaurant photo: the administrator-managed cover image displayed in customer restaurant discovery and tracking.
- Menu photo: the administrator-managed image for a menu item, shown in menus, baskets, and order details.
- Review: a customer's one-to-five-star rating and optional comment for a restaurant or menu item from a delivered Order; public immediately and editable or deletable by its author.
- Rating summary: the average and count of published Reviews for a Restaurant or Menu item; never a manually invented score.
- Report: a CSV export for an authorized Organization or Restaurant scope, generated asynchronously and retained for 30 days.
- Report category: a Finance, Operations, or Kitchen/product view over existing Orders; not a separate Department entity.
- Report schedule: a recurring local-time request for one or more Report categories, managed within the owner's Organization or Restaurant access.
- Search: a case-insensitive partial match over records visible to the current account, with unified and list-specific entry points.

## Use this vocabulary consistently

Prefer these terms in code, tests, and issue titles unless a more specific domain term is already defined in a relevant ADR or feature context.
