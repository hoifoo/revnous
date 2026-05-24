<!-- GSD:project-start source:PROJECT.md -->
## Project

**Blog CMS & SEO Overhaul**

A set of targeted improvements to the Revnous admin blog section that replace the default Trix/ActionText editor with Tiptap, add full author profile support linked to admin users, and extend the SEO/schema tooling with keywords, FAQ schema, canonical URL, and OG image override fields. The goal is to make the blog a capable, SEO-first publishing tool for a marketing freelancer without needing developer involvement for routine content.

**Core Value:** Marketing team can publish well-formatted, fully SEO-optimized blog posts from the admin UI without touching code or workarounds.

### Constraints

- **Tech stack**: Must stay on Rails/Stimulus/esbuild — no React/Vue frontend frameworks
- **Editor storage**: Tiptap output stored as sanitized HTML in a plain `text` column (not ActionText) to simplify rendering and avoid `<action-text-attachment>` dependencies on the public side
- **Image uploads**: Use ActiveStorage direct uploads; Tiptap image extension configured to POST to existing Rails blob endpoint
- **No external SEO plugins**: All SEO/schema logic stays server-side in Rails helpers — no third-party SEO gem
<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->
## Technology Stack

## Languages
- Ruby 3.4.2 - Server-side business logic, models, controllers, job processing
- JavaScript 24.2.0 (Node.js) - Frontend interactivity and build tooling
- CSS (with Tailwind) - Styling and layout
- HTML/ERB - View templates
## Runtime
- Ruby 3.4.2 (via .ruby-version)
- Node.js 24.2.0 (via .node-version, also Docker ARG NODE_VERSION=24.2.0)
- Yarn 1.22.22 (for Node package management)
- Bundle (Ruby gem management) - Version 2.6.2
- Yarn (Node package management) - Version 1.22.22
- npm (secondary Node package support)
- Lockfile: `Gemfile.lock` and `package-lock.json` present
## Frameworks
- Rails 8.0.3 - Full web framework (models, controllers, views, routing)
- Puma 7.0.4 - HTTP server
- Hotwire (Turbo + Stimulus) - Rails front-end framework
- Tailwind CSS 4.1.14 - Utility-first CSS framework
- esbuild 0.25.10 - JavaScript bundler (dev dependency)
- Propshaft 1.3.1 - Modern Rails asset pipeline
- jsbundling-rails 1.3.1 - JavaScript bundler integration
- cssbundling-rails 1.4.3 - CSS bundler integration
- @tailwindcss/cli 4.1.14 - Tailwind CSS CLI for build process
- jbuilder 2.14.1 - JSON API builder
- actiontext 8.0.3 - Rich text handling (via Rails)
- ERB templates (Rails default)
- Trix 2.1.15 (npm) - Rich text editor
- solid_cache 1.0.7 - Database-backed cache store
- solid_queue 1.2.1 - Background job queue (database-backed)
- solid_cable 3.0.12 - ActionCable adapter (WebSocket support)
- devise 4.9.4 - User authentication system
- kaminari 1.2.2 - Pagination library
- altcha 0.2.1 (Ruby) and 2.2.4 (npm) - CAPTCHA verification system
- image_processing 1.14.0 - Image transformation (uses ImageMagick/libvips)
- mini_magick 5.3.1 - ImageMagick wrapper
- ruby-vips 2.2.5 - libvips Ruby binding
- figaro 1.3.0 - Environment variable management
- thruster 0.1.15 - HTTP/2 push and caching for Puma
## Key Dependencies
- Rails 8.0.3 - Core framework, all ActiveRecord, routing, middleware
- PostgreSQL (pg 1.6.2) - Primary database
- devise 4.9.4 - User authentication with bcrypt hashing
- solid_queue 1.2.1 - Job processing for async tasks
- kamal 2.7.0 - Docker deployment orchestration
- bootsnap 1.18.6 - Boot time optimization (precompilation)
- zeitwerk 2.7.3 - Automatic code loading (Rails 6+ standard)
- activerecord 8.0.3 - ORM
- pg 1.6.2 - PostgreSQL client
- Multi-database config: primary, cache, queue, cable (each with own PostgreSQL schema)
- rspec-rails 7.1.1 - Test framework
- capybara 3.40.0 - Integration/system testing
- factory_bot_rails 6.5.1 - Test data fixtures
- faker 3.5.2 - Fake data generation
- shoulda-matchers 7.0.1 - RSpec matcher helpers
- database_cleaner-active_record 2.2.2 - Test database cleanup
- selenium-webdriver 4.36.0 - Browser automation for E2E tests
- brakeman 7.1.0 - Rails security vulnerability scanner
- rubocop-rails-omakase 1.1.0 - Rails coding style enforcement
- capistrano 3.19.2 - SSH-based deployment (configured but optional)
- capistrano-rails 1.7.0 - Rails-specific Capistrano tasks
- capistrano-bundler 2.1.1 - Gem bundling for deployments
- capistrano-rbenv 2.2.0 - Ruby version management
- capistrano3-puma 7.0.0 - Puma integration
- capistrano-yarn 2.0.2 - Yarn integration
## Configuration
- Managed by `figaro` (reads from config/application.yml or ENV)
- See `.env.example` for required variables:
- `esbuild` config - Bundles app/javascript/* to app/assets/builds/
- Tailwind CSS build - Compiles app/assets/stylesheets/application.tailwind.css to app/assets/builds/application.css
- Both run via npm scripts in package.json
- `config/database.yml` - PostgreSQL connection config for 4 separate databases:
- Development: local sockets to web_development_* databases
- Production: ENV variables (DATABASE_USERNAME, DATABASE_PASSWORD)
- `config/storage.yml` - Local disk storage configured (not S3/cloud)
- Supports AWS S3, Google Cloud Storage, Azure (commented out)
- `config/cable.yml` - Development uses async adapter, production uses solid_cable
- `config/queue.yml` - solid_queue configuration
- `config/cache.yml` - solid_cache configuration
## Platform Requirements
- Ruby 3.4.2
- Node.js 24.2.0
- Yarn 1.22.22
- PostgreSQL (4 databases)
- Git
- Docker container (see Dockerfile)
- PostgreSQL (4 databases)
- RAILS_MASTER_KEY for secrets
- Environment variables for Telegram, ALTCHA, database credentials
- Kamal for orchestration (optional - can also run Docker manually)
- Base: ruby:3.4.2-slim
- Build tools included: build-essential, git, libpq-dev, libyaml-dev, python
- Runtime libraries: curl, libjemalloc2, libvips, postgresql-client
- Precompiles assets during build (SECRET_KEY_BASE_DUMMY=1)
- Runs as non-root user (uid 1000:1000)
- Entrypoint: bin/docker-entrypoint (database setup)
- Server: Thruster with Rails server on port 80
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

## Naming Patterns
- Ruby models and controllers use PascalCase with underscores for multi-word names: `app/models/beta_user.rb`, `app/controllers/admin/blogs_controller.rb`
- View files match controller action names: `app/views/admin/blogs/index.html.erb`, `edit.html.erb`, `new.html.erb`
- Factory files are plural: `spec/factories/users.rb`, `spec/factories/blogs.rb`
- JavaScript controllers use snake_case: `app/javascript/controllers/hello_controller.js`
- Use snake_case for method names: `generate_slug`, `verify_altcha_payload`, `format_telegram_message`, `set_seo_metadata`
- Private methods are grouped at the bottom of the class after `private` keyword
- Predicate methods use question mark: Methods are not yet shown in code samples, but Rails convention is followed
- Instance variables use @: `@blog`, `@products`, `@admin`, `@active_notice`
- Local variables use snake_case: `telegram_message`, `payload_data`, `admin_user`
- Constants are UPPERCASE: `ALTCHA_HMAC_KEY` (accessed via ENV)
- Models inherit from `ApplicationRecord`: `class Blog < ApplicationRecord`
- Controllers inherit from `Admin::BaseController` (admin) or `ApplicationController`: `class Admin::BlogsController < Admin::BaseController`
- Use singular names for models: `Blog`, `User`, `Product`, `BetaUser`
- Namespace admin controllers under `Admin::` module
## Code Style
- Tool: Rubocop with Rails Omakase configuration (`inherit_gem: { rubocop-rails-omakase: rubocop.yml }`)
- File: `.rubocop.yml` inherits from `rubocop-rails-omakase` which enforces Rails best practices
- Indentation: 2 spaces (Rails standard)
- String quotes: Single quotes preferred in most places, double quotes for interpolation
- Tool: Rubocop (static analysis for code style and quality)
- Configuration: `rubocop-rails-omakase` gem provides opinionated Rails styling guidelines
- Security: Brakeman for Rails security vulnerability scanning
- No custom rules documented—uses default Omakase configuration
## Import Organization
- Not detected in this codebase (no `config/initializers/aliases.rb`)
- Uses relative requires and Rails' automatic class loading
## Error Handling
- Broad rescue with logging: `rescue => e` followed by `Rails.logger.error()`
- Example in `BetaUsersController#verify_altcha_payload`: Multiple rescue blocks for specific error types (JSON::ParserError) and generic fallback
- Early return pattern: Check conditions, return false if fails, continue if passes
- Uses guard clauses: `return false if condition`
- Exception details logged with backtrace: `Rails.logger.error("ALTCHA Backtrace: #{e.backtrace.first(5).join("\n")}")`
- Controllers redirect with alert messages: `redirect_to beta_signup_path, alert: "CAPTCHA verification failed..."`
- View validation errors displayed: `flash.now[:alert] = @beta_user.errors.full_messages.join(", ")`
- HTTP status codes used: `status: :unprocessable_entity` for validation failures
## Logging
- Info level for flow tracking: `Rails.logger.info("ALTCHA Verification START")`
- Error level for failures: `Rails.logger.error("ALTCHA FAILED: ...")`
- Structured logging with context: `Rails.logger.info("ALTCHA Payload received: #{altcha_payload.inspect}")`
- Inspect method used for debugging complex objects: `.inspect` on hashes and arrays
- No structured logging framework (e.g., Lograge) detected
## Comments
- Minimal comments in code—Rails conventions are self-documenting
- Comments used for non-obvious logic: `# Fallback for console/tests` in `Blog#cover_photo_url`
- Section comments for logical groupings: `# SEO Meta Tags` in ApplicationHelper
- Comments explaining external integrations: ALTCHA verification has detailed inline comments
- No JSDoc/RDoc detected in provided files
- Method names are descriptive enough to avoid comments: `def verify_altcha_payload`, `def format_telegram_message`
## Function Design
- Controllers use params hash: `params.require(:blog).permit(...)`
- Strong parameters pattern enforced: `def blog_params` private method
- Params are white-listed before passing to models
- Models return objects or nil: Blog model returns instance or nil on failure
- Controllers return responses (redirect, render, or implicit nil)
- Scopes return ActiveRecord relations: `Blog.published`, `Product.active`
## Module Design
- Rails uses automatic class loading—no explicit exports
- Models defined in `app/models/`
- Controllers defined in `app/controllers/`
- Helpers defined in `app/helpers/`
- Not used in this codebase
- JavaScript: `app/javascript/controllers/index.js` is minimal (likely auto-generated)
## Scope Management
- Used for reusable query patterns: `scope :published, -> { where(...).order(...) }`
- Chainable design: `Blog.published.featured.order(...)`
- Default scope avoided (not detected)
- Defined in model files: `app/models/blog.rb`
- Rarely used; scopes preferred for queries
- Private class methods used for setup: Not detected
## Associations
- One-to-many: `has_many :pricing_plans, dependent: :destroy`
- Many-to-many: `has_and_belongs_to_many :products`
- One-to-one: `has_one_attached :image` (Active Storage)
- Dependent cleanup: `dependent: :destroy` clears related records
- Model-level validations: `validates :title, :content, presence: true`
- Uniqueness with allow_nil: `validates :slug, uniqueness: true, allow_nil: true`
- Custom validations: `before_validation :generate_slug, on: :create`
## Testing-Related Conventions
- FactoryBot for factories: `create(:user, :admin)`, `create(:blog)`
- Traits for variations: `:admin` trait in User factory
- Sequences for unique attributes: `sequence(:email) { |n| "user#{n}@example.com" }`
- `let` blocks for test data: `let(:admin) { create(:user, :admin) }`
- `before` hooks for authentication: `before { sign_in admin }`
- No explicit teardown—Rails transactional fixtures handle cleanup
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

## Pattern Overview
- Layered Rails architecture (Controllers → Models → Views)
- Admin namespace separation with authorization
- Polymorphic content system (Products, Blogs, Case Studies, Legal Documents)
- Multi-product support with product-scoped content
- Hotwire stack (Turbo + Stimulus) for dynamic interactions
- Job-based async processing (Solid Queue)
- SEO-first design with metadata management
## Layers
- Purpose: Render HTML views and handle user interactions
- Location: `app/views/`, `app/javascript/`
- Contains: ERB templates, Stimulus controllers, CSS (Tailwind)
- Depends on: Rails view helpers, models for data
- Used by: Browsers, client devices
- Purpose: Route requests, coordinate request/response, enforce authorization
- Location: `app/controllers/`
- Contains: Public controllers (`app/controllers/*.rb`), Admin controllers (`app/controllers/admin/*.rb`)
- Depends on: Models, services, helpers
- Used by: Rails router, request pipeline
- Purpose: Enforce admin-only access and set admin context
- Location: `app/controllers/admin/base_controller.rb`
- Contains: Authentication check via `authenticate_user!`, admin role check via `ensure_admin!`
- Depends on: Devise (authentication), User model
- Used by: All admin controllers via inheritance
- Purpose: Encapsulate business logic and data persistence
- Location: `app/models/`
- Contains: ActiveRecord models, validations, scopes, associations
- Depends on: PostgreSQL database, ActiveStorage (for file attachments)
- Used by: Controllers, jobs
- Purpose: Encapsulate external integrations and complex operations
- Location: `app/services/`
- Contains: Integration with external APIs (currently Telegram via `Telegram` service)
- Depends on: ENV configuration, HTTP libraries
- Used by: Controllers, jobs
- Purpose: Handle async work without blocking request
- Location: `app/jobs/`
- Contains: Job classes for internal events (`InternalEventJob`), async operations
- Depends on: Solid Queue adapter, services, models
- Used by: Controllers when async work needed
- Purpose: Reusable view helpers and content generation
- Location: `app/helpers/`
- Contains: SEO helpers (`ApplicationHelper`), view-specific helpers
- Depends on: Models, Rails helpers
- Used by: View templates
## Data Flow
- Database-backed: All persistent state in PostgreSQL via ActiveRecord
- Session state: User authentication via Devise session/cookies
- No client-side state management (Stimulus for progressive enhancement only)
- View-level state: Instance variables set by controller actions
- Job state: Solid Queue manages job queue and retry logic
## Key Abstractions
- Purpose: Represents a product offering (core business entity)
- Examples: `app/models/product.rb`, schema tables `products`, `pricing_plans`
- Pattern: Aggregate root with many associations (pricing, legal docs, beta signups)
- Relationships: has_many pricing_plans, has_many legal_documents, habtm blogs/case_studies
- Purpose: Manage different content types linked to products
- Examples: Blogs, Case Studies, Legal Documents, Partners, Trusted Brands
- Pattern: Independent models with product associations via join tables (HABTM)
- Schema pattern: `blogs_products`, `case_studies_products` join tables
- Purpose: Versioned, scoped legal content (global or per-product)
- Examples: Privacy Policies, Terms of Service
- Pattern: Document versioning with active/inactive status
- Scopes: `active`, `privacy_policies`, `terms_of_service`, `global`, `for_product`, `latest_version`
- Purpose: Page-level SEO configuration outside of content
- Examples: `app/models/seo_metadatum.rb`
- Pattern: Centralized metadata storage keyed by page identifier (controller#action)
- Load: `ApplicationController#set_seo_metadata` loads per request based on controller/action
- Purpose: Collect early adopter signups per product
- Examples: `app/models/beta_user.rb`
- Pattern: Lightweight form submission to product-scoped signup pages
- Relationships: belongs_to :product
## Entry Points
- Location: Base controller
- Triggers: Every request (inherited by all controllers)
- Responsibilities:
- Location: Public homepage
- Triggers: `GET /` (root route)
- Responsibilities: Render homepage with featured content
- Location: Public blog
- Triggers: `GET /blog`, `GET /blog/:id`
- Responsibilities: List/show blog posts with SEO
- Location: Admin entry
- Triggers: `GET /admin`
- Responsibilities: Display admin dashboard
- Sets Rails 8.0 defaults
- Configures Solid Queue as ActiveJob adapter
- Autoloads lib/ directory
- Imports Turbo Rails for SPA-like behavior
- Imports Stimulus controllers
- Imports Trix and ActionText for rich text editing
- Imports ALTCHA for CAPTCHA
## Error Handling
- `contacts_controller.rb` example: `rescue => e` catches errors, logs to Rails.logger.error, redirects with flash alert
- Error messages use neutral language ("Sorry, there was an error...") instead of exposing internals
- Model validations prevent invalid data at model layer
- Controllers render forms with errors on validation failure
- No global exception handler currently in place (falls back to Rails default error pages)
- Solid Queue handles job retries with exponential backoff (configured in solid_queue config)
- Failed jobs stored for admin inspection
## Cross-Cutting Concerns
- Uses Rails.logger for error/info logging
- Structured logs in production (via Rails default)
- ALTCHA verification logs detailed steps for debugging
- Model-level: ActiveRecord validates presence, uniqueness, inclusion
- Form-level: Controller permit whitelist via `params.require().permit()`
- CAPTCHA validation: Custom verification in `ContactsController#verify_altcha_payload`
- Devise gem handles user auth (database_authenticatable, recoverable, rememberable, validatable)
- Admin authorization: Custom `Admin::BaseController#ensure_admin!` checks user.admin? boolean
- Public routes: No authentication required
- All admin routes: Require authenticated admin user
- Role-based: Admin boolean flag on User model
- Namespace-based: `/admin/*` routes inherit from `Admin::BaseController`
- Simple two-tier: admin or not admin
- Propshaft for asset management
- esbuild for JavaScript bundling (minified, tree-shaken, ESM format)
- Tailwind CLI for CSS processing (minified)
- Generated assets in `app/assets/builds/`
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, `.github/skills/`, or `.codex/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
