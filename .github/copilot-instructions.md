# Copilot instructions for Foodcourt

## Project overview

This repository is a Rails 8 application using PostgreSQL, Hotwire/Turbo, Stimulus, and Tailwind. Most application logic lives in the standard Rails MVC layout:

- `app/controllers` for request handling and controller logic
- `app/models` for Active Record models and business rules
- `app/views` for server-rendered templates and partials
- `app/javascript/controllers` for Stimulus behaviors
- `app/assets/stylesheets` for shared CSS/Tailwind entrypoints

The app is still effectively a generated Rails skeleton, so keep new work aligned to the default Rails structure rather than introducing ad hoc framework patterns.

## Local development

Use the repo's existing scripts rather than inventing new commands:

- Install Ruby gems: `bundle install`
- Install frontend dependencies: `yarn install`
- Prepare the database: `bin/rails db:prepare`
- Start the dev stack: `bin/dev`
- Or run the app directly: `bin/rails server`

The `Procfile.dev` runs:

- Rails server: `bin/rails server`
- JS build watch: `yarn build --watch`
- CSS build watch: `yarn build:css --watch`

## Build, test, and lint

The CI workflow in `.github/workflows/ci.yml` is the source of truth for repository checks:

- Security scan: `bin/brakeman --no-pager`
- Dependency audit: `bin/bundler-audit`
- Lint: `bin/rubocop -f github`
- RSpec suite: `bin/rails db:test:prepare && bundle exec rspec`
- System tests: `bin/rails db:test:prepare test:system`

For a single RSpec file or example, use RSpec directly, for example:

- `bundle exec rspec spec/models/foo_spec.rb`
- `bundle exec rspec spec/requests/foo_spec.rb`
- `bundle exec rspec spec/models/foo_spec.rb:12`

For JavaScript/CSS assets, use the package scripts from `package.json`:

- `yarn build`
- `yarn build:css`

## Architecture notes

- Route registration happens in `config/routes.rb`; prefer conventional RESTful routes unless a feature clearly requires a custom flow.
- Unhandled Rails exceptions are dispatched through `config.exceptions_app` to `ErrorsController`; keep public error responses generic and cover status/rendering behavior in controller integration tests.
- Database configuration lives in `config/database.yml` and is PostgreSQL-based. CI runs with a postgres service and sets `DATABASE_URL` for tests.
- The frontend stack is intentionally minimal: Turbo for page navigation and Stimulus for interactivity, with Tailwind CSS for styling. Avoid introducing a heavier client-side framework unless the repository clearly grows beyond this pattern.
- `app/javascript/application.js` is the entrypoint for JavaScript; controllers are auto-registered through `app/javascript/controllers/index.js`.
- Keep server-rendered HTML and Ruby logic in Rails conventions instead of building isolated client-only features.

## Repository conventions

- Match the signal from Rails generators: controllers, models, and views are named in standard Rails conventions.
- Prefer `config/routes.rb` + controller/model/view changes together when adding a feature.
- When adding a new Stimulus controller, follow the generated pattern in `app/javascript/controllers` and update the controller manifest if needed through `bin/rails stimulus:manifest:update`.
- This project uses Tailwind via `@tailwindcss/cli`; CSS should be added in the app stylesheet pipeline rather than by hand-editing generated build artifacts under `app/assets/builds`.
- Keep CI expectations in mind: security and lint checks run automatically in GitHub Actions.

## Practical guidance

- If a change affects routing, database schema, or UI behavior, inspect the relevant Rails MVC files as a unit instead of patching only one layer.
- For frontend changes, prefer Stimulus + Turbo patterns already used in the app over custom JavaScript state management.
- Treat the generated app defaults as the baseline; new behavior should fit naturally into the Rails conventions already present in the repository.
