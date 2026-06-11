# Backend Architecture

**Analysis Date:** 2026-04-08  
**Focus:** Rails server, data layer, business logic, async processing

## Pattern Overview

**Overall:** Monolithic Rails MVC server with content management focus

**Key Characteristics:**
- Layered request/response flow (Controllers → Models → Services/Jobs)
- Multi-database PostgreSQL setup (primary, cache, queue, cable)
- Admin namespace separation with role-based authorization
- Polymorphic content system (Blogs, Case Studies, Legal Documents, Products)
- Job-based async processing (Solid Queue)
- External API integrations (Telegram notifications)
- SEO-first design with metadata management

## Request/Response Layers

**Controller Layer:**
- Purpose: Route requests, coordinate business logic, enforce authorization
- Location: `app/controllers/`
  - Public controllers: `app/controllers/*.rb` (blogsController, ProductsController, etc.)
  - Admin controllers: `app/controllers/admin/*.rb` (Admin::BlogsController, Admin::DashboardController, etc.)
- Responsibilities:
  - Extract and validate params via strong parameters
  - Orchestrate model queries and service calls
  - Manage response format (HTML redirects, form re-renders)
  - Log business events
- Depends on: Models, Services, Helpers, Devise

**Admin Authorization Layer:**
- Purpose: Enforce admin-only access and context
- Location: `app/controllers/admin/base_controller.rb`
- Pattern:
  - `before_action :authenticate_user!` (Devise) — verify logged in
  - `before_action :ensure_admin!` — verify user.admin == true
  - `before_action :set_admin_context` — set @admin_context for layout
- Used by: All admin controllers via inheritance

**ApplicationController Base:**
- Purpose: Shared request/response setup
- Location: `app/controllers/application_controller.rb`
- Responsibilities:
  - Load active notice (`load_active_notice` before action)
  - Set page-level SEO metadata (`set_seo_metadata` before action)
  - Browser compatibility checks

## Data/Business Logic Layers

**Model/Data Layer:**
- Purpose: Encapsulate business logic and data persistence
- Location: `app/models/`
- Contains:
  - ActiveRecord models with validations, scopes, associations
  - Model callbacks (before_create, before_save)
  - Query logic and data access patterns
- Depends on: PostgreSQL, ActiveStorage
- Used by: Controllers, Services, Jobs

**Service Layer:**
- Purpose: Encapsulate external integrations and complex multi-step operations
- Location: `app/services/`
- Examples:
  - `Telegram` service — posts messages to Telegram for notifications
  - Pattern: simple input → output, no side effects on models directly
- Used by: Controllers, Jobs

**Background Job Layer:**
- Purpose: Handle async work without blocking request/response
- Location: `app/jobs/`
- Adapter: Solid Queue (database-backed job queue)
- Examples:
  - `InternalEventJob` — async notification delivery
  - Pattern: enqueue in controller, execute later by worker
- Depends on: Solid Queue, Services, Models
- Used by: Controllers when async work is needed

**Helper Layer:**
- Purpose: Reusable view helpers, content generation, SEO logic
- Location: `app/helpers/`
- Examples:
  - `ApplicationHelper` — structured data (JSON-LD), page title/description, canonical URL
  - `BlogHelper` — blog-specific formatting
- Depends on: Models, Rails helpers (sanitize, tag)
- Used by: View templates

## Database Layer

**PostgreSQL Multi-Database Setup:**
- Primary: `web_development` (production: env var)
  - All user data, content, auth
  - Tables: users, blogs, products, pricing_plans, legal_documents, seo_metadata, action_text_rich_texts, active_storage_*
- Cache: `solid_cache` (database-backed cache)
- Queue: `solid_queue` (job queue state)
- Cable: `solid_cable` (WebSocket session state)

**Key Tables:**
- `users` — auth (email, encrypted_password), admin flag, profile fields
- `products` — core business entity
- `pricing_plans` — product variants
- `blogs` — content with ActionText rich text
- `blogs_products` — join table for polymorphic content
- `case_studies_products` — join table
- `legal_documents` — versioned legal content (global or per-product)
- `seo_metadata` — page-level SEO config (keyed by controller#action)
- `beta_users` — early adopter signups per product
- `action_text_rich_texts` — ActionText backing table for rich content
- `active_storage_blobs`, `active_storage_attachments` — file storage refs

## Data Flow Patterns

**Public Content Request (e.g., Blog Post):**

```
1. GET /blog/post-slug
2. Rails router → BlogsController#show
3. ApplicationController before actions:
   - load_active_notice
   - set_seo_metadata (fetch SeoMetadatum record if exists)
4. Controller action:
   - Blog.find_by!(slug: params[:slug])
   - Set instance vars (@blog, @page_og_image, @canonical_url)
5. View renders:
   - View helpers render structured data (JSON-LD)
   - HTML content from ActionText
6. Response sent to browser
```

**Admin Content Creation (Blog):**

```
1. POST /admin/blogs
2. Rails router → Admin::BlogsController#create
3. Admin::BaseController before actions:
   - authenticate_user! (Devise)
   - ensure_admin!
   - set_admin_context
4. Controller action:
   - Extract blog_params via strong parameters
   - Call Blog.new, validate, save
   - On success: redirect with notice
   - On failure: re-render form with errors
5. Model callbacks fire (before_save, etc.)
6. Database writes to blogs table
```

**Async Job Processing (Notification):**

```
1. POST /contact (user submits contact form)
2. ContactsController#create:
   - Verify ALTCHA payload (CAPTCHA)
   - On success: InternalEventJob.perform_later(message)
3. Return redirect immediately (request completes)
4. Solid Queue worker picks up job from queue
5. InternalEventJob#perform:
   - Call Telegram.send_message(text)
   - Service POSTs to Telegram API
6. Response logged; job marked complete
```

**State Management:**
- Database-backed: All persistent state in PostgreSQL via ActiveRecord
- Session state: User auth via Devise (encrypted cookie or session store)
- View-level state: Instance variables set by controller actions
- Job state: Solid Queue maintains queue and retry logic
- No client-side Redux/Vuex — Stimulus only for progressive enhancement

## Key Business Abstractions

**Product (Aggregate Root):**
- Represents a product offering (core business entity)
- Location: `app/models/product.rb`
- Associations:
  - `has_many :pricing_plans, dependent: :destroy`
  - `has_and_belongs_to_many :blogs, :case_studies, :legal_documents`
  - `has_many :beta_users`
- Pattern: Aggregate root with many related entities

**Polymorphic Content:**
- Manage different content types linked to products
- Examples: Blogs, Case Studies, Legal Documents, Partners, Trusted Brands
- Pattern: Independent ActiveRecord models with HABTM join tables
- Schema: `blogs_products`, `case_studies_products` (join tables)

**Legal Documents:**
- Versioned, scoped legal content (global or per-product)
- Location: `app/models/legal_document.rb`
- Pattern: Document versioning with active/inactive status
- Scopes: `active`, `privacy_policies`, `terms_of_service`, `global`, `for_product`, `latest_version`

**SEO Metadata:**
- Page-level SEO configuration outside of content models
- Location: `app/models/seo_metadatum.rb`
- Pattern: Keyed by page identifier (controller#action or custom key)
- Load: `ApplicationController#set_seo_metadata` loads per request based on controller/action
- Fields: title, description, keywords, canonical URL

**Beta User Registration:**
- Collect early adopter signups per product
- Location: `app/models/beta_user.rb`
- Pattern: Lightweight form submission to product-scoped signup pages
- Association: `belongs_to :product`

## Server Configuration

**Ruby on Rails 8.0:**
- Defaults configured in `config/application.rb`
- Solid Queue as ActiveJob adapter (background jobs)
- Zeitwerk automatic class loading
- Propshaft asset pipeline

**Environment Setup:**
- Ruby 3.4.2 (via .ruby-version)
- Bundled gems (Gemfile): Rails 8.0, Devise, Solid Queue, etc.
- Database credentials from `config/database.yml`
- Secrets from Rails encrypted credentials or ENV vars (figaro)
- Logging to `log/development.log` and `log/production.log`

## Error Handling Strategy

**Controller Exception Handling:**
- Pattern: `rescue => e` with Rails.logger.error, then redirect with flash alert
- Example: `ContactsController#verify_altcha_payload` catches JSON::ParserError
- Messages: Neutral language ("Sorry, there was an error...") — never expose internals

**Model Validation Errors:**
- ActiveRecord validates presence, uniqueness, inclusion (model layer)
- Invalid model.save returns false; controller re-renders form with @model.errors

**Async Job Error Handling:**
- Solid Queue job retries with exponential backoff (config/solid_queue.yml)
- Failed jobs stored in queue for admin inspection

## Cross-Cutting Concerns

**Authentication & Authorization:**
- Auth: Devise gem (database_authenticatable, recoverable, validatable)
- Public routes: No authentication required
- Admin routes: `/admin/*` paths require authenticated admin user (Admin::BaseController)
- Authorization: Role-based — simple Admin boolean flag on User model

**Validation:**
- Model-level: ActiveRecord validates presence, uniqueness, inclusion
- Form-level: Strong parameters in controller (`params.require(:blog).permit(...)`)
- CAPTCHA: Custom `ContactsController#verify_altcha_payload` (ALTCHA verification)

**Logging:**
- Uses Rails.logger for all logging
- Levels: info (flow tracking), error (failures)
- Example: ALTCHA verification logs detailed steps for debugging
- Structured logs in production (Rails default JSON format)

**Security:**
- Strong parameters whitelist: prevent mass assignment
- XSS protection: Rails auto-escapes ERB output (use `html_safe` carefully)
- CSRF tokens: Rails form helpers add automatically
- SQL injection: ActiveRecord parameterization prevents injection
- Session: encrypted cookies (Rails default)

---

*Backend architecture documentation: 2026-04-08*
