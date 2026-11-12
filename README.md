# README

## Staff dashboard

Staff access is restaurant-scoped. A trusted operator can provision a staff
account from the Rails console after creating the restaurant:

```ruby
restaurant = Restaurant.find_by!(name: "Example Restaurant")
temporary_password = SecureRandom.base58(24)
User.create!(
  email_address: "staff@example.com",
  password: temporary_password,
  role: :staff,
  restaurant: restaurant
)
puts temporary_password
```

Deliver the generated password through a secure channel and remove it from
console history where applicable. Staff users can view
and update orders for their restaurant, enter orders using currently available
menu items, and manage their menu. The dashboard's sales total includes only
completed orders created during the current application-local day; cancelled
orders are excluded from the daily order count and revenue.

## Admin accounts

Admins are separate from customer and staff users and can be provisioned from
the Rails console:

```ruby
temporary_password = SecureRandom.base58(24)
AdminAccount.create!(email_address: "admin@example.com", password: temporary_password)
puts temporary_password
```

Deliver the generated password through a secure channel. Admin accounts can sign
in through the regular sign-in page and are sent to the admin dashboard.

The regular development setup is:

- Install Ruby gems: `bundle install`
- Install frontend dependencies: `yarn install`
- Start PostgreSQL, Redis, and Memcached: `docker compose up -d`
- Prepare the database: `bin/rails db:prepare`
- Load development demo data: `bin/rails db:seed`
- Start the app: `bin/dev`
- Run tests: `bin/rails test`
- Check application line coverage (80% minimum): `bin/rails coverage`

When using a forwarded Codespaces port, open the app through its forwarded
`*.app.github.dev` URL. Development also accepts the exact origin
`https://localhost:3000` for proxied requests; all other cross-origin requests
remain rejected, and Rails' CSRF token validation stays enabled.

## Customer ordering, payments, and delivery

Restaurant menus and baskets are public. A guest can build a basket across
restaurants; checkout requires a customer account. One Stripe Checkout payment
creates a separate restaurant-scoped order and transfer for each restaurant.
Orders are created only after Stripe confirms payment. Foodcourt does not take a
platform commission in this version; Stripe processing fees are charged to the
platform account.

Configure these environment variables without committing their values:

- `STRIPE_SECRET_KEY` — Stripe test or live secret key.
- `STRIPE_WEBHOOK_SECRET` — signing secret for the `/webhooks/stripe` endpoint.
- `GOOGLE_MAPS_SERVER_API_KEY` — server-restricted key with Places API (New)
  and Routes API enabled.
- `GOOGLE_MAPS_BROWSER_API_KEY` — HTTP-referrer-restricted key with Places API
  (New) enabled for address autocomplete.

For local payment testing, forward Stripe events to the app with
`stripe listen --forward-to localhost:3000/webhooks/stripe` and use the signing
secret printed by the Stripe CLI. The Google Maps project must have billing
enabled for Places lookups and driving-route distance calculations.

An administrator must configure each restaurant's Google Places pickup address,
USD base delivery fee, per-kilometre rate, maximum delivery distance, and Stripe
Express account in **Admin → Restaurants** before it can accept online orders.
If any restaurant in the basket is outside its delivery radius, checkout is
blocked so the customer can review the basket. A paid restaurant order is
transferred to that restaurant after the Stripe webhook is processed; if staff
cancel it, Foodcourt refunds that restaurant order and reverses its transfer.

Admins create driver accounts and assign each restaurant order manually.
Drivers see only assigned orders and can mark them picked up and delivered.
Customers can view those milestones from their order page; live GPS and
SMS/email notifications are not included.

## Customer photos and ratings

Admins can upload one restaurant cover image and one image per menu item from
**Admin → Restaurants**. Uploads accept JPEG, PNG, or WebP files up to 5 MB and
use the configured Active Storage service. The current configuration stores
files on local disk; production deployments should use persistent shared storage
or configure a cloud Active Storage service so uploads survive host replacement.

After a delivery is marked delivered, the customer can rate the restaurant and
each ordered menu item from 1 to 5 stars, with an optional written comment.
Ratings publish immediately, can be edited or deleted by their author, and are
shown with their actual review count and average. Admins can remove inappropriate
reviews from **Admin → Reviews**. Restaurant discovery supports searching by
restaurant name or city; it does not display unconfigured cuisine, delivery-time,
or popularity claims.

## Search

The **Search** page provides grouped, filterable results with case-insensitive
partial matching. Admins can search Organizations, Restaurants, Drivers, order
history, deliveries, and Reviews. Organization admins are restricted to the
selected Organization and its related records; drivers see only their assigned
deliveries; customers see public Restaurants, their own orders, and Reviews
they authored. Local search is also available on the corresponding list pages.
Customer names, contact details, and delivery addresses are not search fields.

Keep the server Google API key restricted to the required APIs and the browser
key restricted to the app's allowed domains. Never place Stripe secrets in
frontend assets or commit provider credentials.

The development seed creates sample restaurants, menus, orders, and customer,
staff, and admin accounts. Sign in with `demo.customer@example.test`,
`demo.staff@example.test`, or `demo.admin@example.test`; all use the password
`password`. These accounts are created only in development and should never be
used outside a local environment.

Development and test automatically connect to the Compose PostgreSQL service
on `127.0.0.1:5433` (host port; the container listens on port `5432`).
Connection settings can be overridden with
`POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_DB`, `POSTGRES_USER`, and
`POSTGRES_PASSWORD`.

The Compose services are available on `localhost:5433` (PostgreSQL),
`localhost:6379` (Redis), and `localhost:11211` (Memcached). PostgreSQL and
Redis data persist in named Docker volumes. The default PostgreSQL credentials
are for local development only and can be overridden with `POSTGRES_DB`,
`POSTGRES_USER`, and `POSTGRES_PASSWORD`.

## Reports

Organization admins and Restaurant staff can request Finance, Operations, and
Kitchen/product CSV reports from **Reports**. Generation runs through ActiveJob
on Sidekiq; start the worker with `bin/dev` or `bundle exec sidekiq -q default
-q reports -q mailers`. On-demand reports use inclusive Organization-local
dates, default to the prior 30 complete days, and allow at most one year.
Recurring schedules can run daily, weekly, or monthly; reports cover the
previous complete local period. Organization admins can set the Organization
time zone in **Organization profile**; it defaults to UTC.

Generated files use the configured Active Storage backend, expire after 30
days, and can be downloaded only by users who still have access to the report
scope. Completion emails include both a protected app link and a CSV
attachment; emailed attachments cannot be recalled after delivery. Configure
`REDIS_URL` for production web and job containers and `APP_HOST` to the public
hostname used in report email links. Production email delivery also requires
working Action Mailer SMTP settings.
