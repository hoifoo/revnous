# Architecture

**Analysis Date:** 2026-04-08

## Pattern Overview

**Overall:** Monolithic Rails MVC with content management focus

**Key Characteristics:**
- Layered Rails architecture (Controllers → Models → Views)
- Admin namespace separation with authorization
- Polymorphic content system (Products, Blogs, Case Studies, Legal Documents)
- Multi-product support with product-scoped content
- Hotwire stack (Turbo + Stimulus) for dynamic interactions
- Job-based async processing (Solid Queue)
- SEO-first design with metadata management

## Layers

**Presentation Layer:**
- Purpose: Render HTML views and handle user interactions
- Location: `app/views/`, `app/javascript/`
- Contains: ERB templates, Stimulus controllers, CSS (Tailwind)
- Depends on: Rails view helpers, models for data
- Used by: Browsers, client devices

**Controller Layer:**
- Purpose: Route requests, coordinate request/response, enforce authorization
- Location: `app/controllers/`
- Contains: Public controllers (`app/controllers/*.rb`), Admin controllers (`app/controllers/admin/*.rb`)
- Depends on: Models, services, helpers
- Used by: Rails router, request pipeline

**Admin Authorization Layer:**
- Purpose: Enforce admin-only access and set admin context
- Location: `app/controllers/admin/base_controller.rb`
- Contains: Authentication check via `authenticate_user!`, admin role check via `ensure_admin!`
- Depends on: Devise (authentication), User model
- Used by: All admin controllers via inheritance

**Model/Data Layer:**
- Purpose: Encapsulate business logic and data persistence
- Location: `app/models/`
- Contains: ActiveRecord models, validations, scopes, associations
- Depends on: PostgreSQL database, ActiveStorage (for file attachments)
- Used by: Controllers, jobs

**Service Layer:**
- Purpose: Encapsulate external integrations and complex operations
- Location: `app/services/`
- Contains: Integration with external APIs (currently Telegram via `Telegram` service)
- Depends on: ENV configuration, HTTP libraries
- Used by: Controllers, jobs

**Background Job Layer:**
- Purpose: Handle async work without blocking request
- Location: `app/jobs/`
- Contains: Job classes for internal events (`InternalEventJob`), async operations
- Depends on: Solid Queue adapter, services, models
- Used by: Controllers when async work needed

**Helper Layer:**
- Purpose: Reusable view helpers and content generation
- Location: `app/helpers/`
- Contains: SEO helpers (`ApplicationHelper`), view-specific helpers
- Depends on: Models, Rails helpers
- Used by: View templates

## Data Flow

**Public Content Request (e.g., Blog Post):**

1. Request arrives at Rails router (`config/routes.rb`)
2. Routes to public controller (e.g., `BlogsController#show`)
3. Controller queries model (`Blog.find_by(slug: params[:slug])`)
4. Controller loads SEO metadata via `ApplicationController` before action (`set_seo_metadata`)
5. Controller loads active notice via before action (`load_active_notice`)
6. View renders with helpers (`page_title`, `page_description`, structured data helpers)
7. Stimulus controllers attach behavior if needed
8. Response sent to browser

**Admin Content Creation:**

1. Request arrives at admin route (e.g., `/admin/blogs`)
2. Routes to admin controller (`Admin::BlogsController`)
3. `Admin::BaseController` before actions execute:
   - `authenticate_user!` (Devise) - verify user logged in
   - `ensure_admin!` - verify user.admin == true
   - `set_admin_context` - set @admin_context for layout
4. Controller action executes (new, create, edit, update, destroy)
5. Controller validates and persists via model
6. Response redirects or re-renders form
7. User sees admin layout with admin-specific styling

**Async Job Processing (Contact Form):**

1. User submits contact form with ALTCHA verification
2. `ContactsController#create` verifies ALTCHA payload
3. On success, enqueues `InternalEventJob.perform_later(message)`
4. Returns redirect immediately (no blocking)
5. Solid Queue worker picks up job async
6. `InternalEventJob` calls `Telegram.send_message` to post to Telegram
7. Notification delivered to admin

**State Management:**

- Database-backed: All persistent state in PostgreSQL via ActiveRecord
- Session state: User authentication via Devise session/cookies
- No client-side state management (Stimulus for progressive enhancement only)
- View-level state: Instance variables set by controller actions
- Job state: Solid Queue manages job queue and retry logic

## Key Abstractions

**Product:**
- Purpose: Represents a product offering (core business entity)
- Examples: `app/models/product.rb`, schema tables `products`, `pricing_plans`
- Pattern: Aggregate root with many associations (pricing, legal docs, beta signups)
- Relationships: has_many pricing_plans, has_many legal_documents, habtm blogs/case_studies

**Polymorphic Content:**
- Purpose: Manage different content types linked to products
- Examples: Blogs, Case Studies, Legal Documents, Partners, Trusted Brands
- Pattern: Independent models with product associations via join tables (HABTM)
- Schema pattern: `blogs_products`, `case_studies_products` join tables

**Legal Documents:**
- Purpose: Versioned, scoped legal content (global or per-product)
- Examples: Privacy Policies, Terms of Service
- Pattern: Document versioning with active/inactive status
- Scopes: `active`, `privacy_policies`, `terms_of_service`, `global`, `for_product`, `latest_version`

**SEO Metadata:**
- Purpose: Page-level SEO configuration outside of content
- Examples: `app/models/seo_metadatum.rb`
- Pattern: Centralized metadata storage keyed by page identifier (controller#action)
- Load: `ApplicationController#set_seo_metadata` loads per request based on controller/action

**Beta User Registration:**
- Purpose: Collect early adopter signups per product
- Examples: `app/models/beta_user.rb`
- Pattern: Lightweight form submission to product-scoped signup pages
- Relationships: belongs_to :product

## Entry Points

**Web Request Entry Points:**

**`app/controllers/application_controller.rb`:**
- Location: Base controller
- Triggers: Every request (inherited by all controllers)
- Responsibilities:
  - Load active notice (`load_active_notice` before action)
  - Set SEO metadata per page (`set_seo_metadata` before action)
  - Browser compatibility check (modern browsers only)

**`app/controllers/home_controller.rb`:**
- Location: Public homepage
- Triggers: `GET /` (root route)
- Responsibilities: Render homepage with featured content

**`app/controllers/blogs_controller.rb`:**
- Location: Public blog
- Triggers: `GET /blog`, `GET /blog/:id`
- Responsibilities: List/show blog posts with SEO

**`app/controllers/admin/dashboard_controller.rb`:**
- Location: Admin entry
- Triggers: `GET /admin`
- Responsibilities: Display admin dashboard

**Configuration Entry Point:**

**`config/application.rb`:**
- Sets Rails 8.0 defaults
- Configures Solid Queue as ActiveJob adapter
- Autoloads lib/ directory

**JavaScript Entry Point:**

**`app/javascript/application.js`:**
- Imports Turbo Rails for SPA-like behavior
- Imports Stimulus controllers
- Imports Trix and ActionText for rich text editing
- Imports ALTCHA for CAPTCHA

## Error Handling

**Strategy:** Rescues with user-friendly redirects and logging

**Patterns:**

**Controller Exception Handling:**
- `contacts_controller.rb` example: `rescue => e` catches errors, logs to Rails.logger.error, redirects with flash alert
- Error messages use neutral language ("Sorry, there was an error...") instead of exposing internals

**Validation Errors:**
- Model validations prevent invalid data at model layer
- Controllers render forms with errors on validation failure
- No global exception handler currently in place (falls back to Rails default error pages)

**Async Job Errors:**
- Solid Queue handles job retries with exponential backoff (configured in solid_queue config)
- Failed jobs stored for admin inspection

## Cross-Cutting Concerns

**Logging:**
- Uses Rails.logger for error/info logging
- Structured logs in production (via Rails default)
- ALTCHA verification logs detailed steps for debugging

**Validation:**
- Model-level: ActiveRecord validates presence, uniqueness, inclusion
- Form-level: Controller permit whitelist via `params.require().permit()`
- CAPTCHA validation: Custom verification in `ContactsController#verify_altcha_payload`

**Authentication:**
- Devise gem handles user auth (database_authenticatable, recoverable, rememberable, validatable)
- Admin authorization: Custom `Admin::BaseController#ensure_admin!` checks user.admin? boolean
- Public routes: No authentication required
- All admin routes: Require authenticated admin user

**Authorization:**
- Role-based: Admin boolean flag on User model
- Namespace-based: `/admin/*` routes inherit from `Admin::BaseController`
- Simple two-tier: admin or not admin

**Asset Pipeline:**
- Propshaft for asset management
- esbuild for JavaScript bundling (minified, tree-shaken, ESM format)
- Tailwind CLI for CSS processing (minified)
- Generated assets in `app/assets/builds/`

---

*Architecture analysis: 2026-04-08*
