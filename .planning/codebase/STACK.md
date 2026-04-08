# Technology Stack

**Analysis Date:** 2026-04-08

## Languages

**Primary:**
- Ruby 3.4.2 - Server-side business logic, models, controllers, job processing
- JavaScript 24.2.0 (Node.js) - Frontend interactivity and build tooling

**Secondary:**
- CSS (with Tailwind) - Styling and layout
- HTML/ERB - View templates

## Runtime

**Environment:**
- Ruby 3.4.2 (via .ruby-version)
- Node.js 24.2.0 (via .node-version, also Docker ARG NODE_VERSION=24.2.0)
- Yarn 1.22.22 (for Node package management)

**Package Manager:**
- Bundle (Ruby gem management) - Version 2.6.2
- Yarn (Node package management) - Version 1.22.22
- npm (secondary Node package support)
- Lockfile: `Gemfile.lock` and `package-lock.json` present

## Frameworks

**Core:**
- Rails 8.0.3 - Full web framework (models, controllers, views, routing)
- Puma 7.0.4 - HTTP server

**Frontend/UI:**
- Hotwire (Turbo + Stimulus) - Rails front-end framework
  - `@hotwired/turbo-rails` 8.0.18 - SPA-like page acceleration
  - `@hotwired/stimulus` 3.2.2 - Modest JavaScript framework
- Tailwind CSS 4.1.14 - Utility-first CSS framework
- esbuild 0.25.10 - JavaScript bundler (dev dependency)

**Asset Pipeline:**
- Propshaft 1.3.1 - Modern Rails asset pipeline
- jsbundling-rails 1.3.1 - JavaScript bundler integration
- cssbundling-rails 1.4.3 - CSS bundler integration
- @tailwindcss/cli 4.1.14 - Tailwind CSS CLI for build process

**View/Templating:**
- jbuilder 2.14.1 - JSON API builder
- actiontext 8.0.3 - Rich text handling (via Rails)
- ERB templates (Rails default)
- Trix 2.1.15 (npm) - Rich text editor

**Caching & Jobs:**
- solid_cache 1.0.7 - Database-backed cache store
- solid_queue 1.2.1 - Background job queue (database-backed)
- solid_cable 3.0.12 - ActionCable adapter (WebSocket support)

**Authentication & Authorization:**
- devise 4.9.4 - User authentication system

**Pagination:**
- kaminari 1.2.2 - Pagination library

**Form Validation & CAPTCHA:**
- altcha 0.2.1 (Ruby) and 2.2.4 (npm) - CAPTCHA verification system

**Media Processing:**
- image_processing 1.14.0 - Image transformation (uses ImageMagick/libvips)
- mini_magick 5.3.1 - ImageMagick wrapper
- ruby-vips 2.2.5 - libvips Ruby binding

**Configuration:**
- figaro 1.3.0 - Environment variable management

**Web Server/Performance:**
- thruster 0.1.15 - HTTP/2 push and caching for Puma

## Key Dependencies

**Critical:**
- Rails 8.0.3 - Core framework, all ActiveRecord, routing, middleware
- PostgreSQL (pg 1.6.2) - Primary database
- devise 4.9.4 - User authentication with bcrypt hashing
- solid_queue 1.2.1 - Job processing for async tasks

**Infrastructure:**
- kamal 2.7.0 - Docker deployment orchestration
- bootsnap 1.18.6 - Boot time optimization (precompilation)
- zeitwerk 2.7.3 - Automatic code loading (Rails 6+ standard)

**Database Support:**
- activerecord 8.0.3 - ORM
- pg 1.6.2 - PostgreSQL client
- Multi-database config: primary, cache, queue, cable (each with own PostgreSQL schema)

**Testing:**
- rspec-rails 7.1.1 - Test framework
- capybara 3.40.0 - Integration/system testing
- factory_bot_rails 6.5.1 - Test data fixtures
- faker 3.5.2 - Fake data generation
- shoulda-matchers 7.0.1 - RSpec matcher helpers
- database_cleaner-active_record 2.2.2 - Test database cleanup
- selenium-webdriver 4.36.0 - Browser automation for E2E tests

**Security & Quality:**
- brakeman 7.1.0 - Rails security vulnerability scanner
- rubocop-rails-omakase 1.1.0 - Rails coding style enforcement
  - rubocop 1.81.1 - Code style linter
  - rubocop-rails 2.33.4 - Rails-specific rules
  - rubocop-performance 1.26.0 - Performance analysis

**Deployment/SSH:**
- capistrano 3.19.2 - SSH-based deployment (configured but optional)
- capistrano-rails 1.7.0 - Rails-specific Capistrano tasks
- capistrano-bundler 2.1.1 - Gem bundling for deployments
- capistrano-rbenv 2.2.0 - Ruby version management
- capistrano3-puma 7.0.0 - Puma integration
- capistrano-yarn 2.0.2 - Yarn integration

## Configuration

**Environment:**
- Managed by `figaro` (reads from config/application.yml or ENV)
- See `.env.example` for required variables:
  - TELEGRAM_API_TOKEN - Telegram bot token
  - TELEGRAM_CHAT_ID - Telegram target chat ID
  - ALTCHA_HMAC_KEY - CAPTCHA HMAC secret

**Build:**
- `esbuild` config - Bundles app/javascript/* to app/assets/builds/
- Tailwind CSS build - Compiles app/assets/stylesheets/application.tailwind.css to app/assets/builds/application.css
- Both run via npm scripts in package.json

**Database:**
- `config/database.yml` - PostgreSQL connection config for 4 separate databases:
  - primary - Main app data
  - cache - solid_cache storage
  - queue - solid_queue job storage
  - cable - solid_cable WebSocket storage
- Development: local sockets to web_development_* databases
- Production: ENV variables (DATABASE_USERNAME, DATABASE_PASSWORD)

**Storage:**
- `config/storage.yml` - Local disk storage configured (not S3/cloud)
- Supports AWS S3, Google Cloud Storage, Azure (commented out)

**ActionCable:**
- `config/cable.yml` - Development uses async adapter, production uses solid_cable

**Queue/Cache:**
- `config/queue.yml` - solid_queue configuration
- `config/cache.yml` - solid_cache configuration

## Platform Requirements

**Development:**
- Ruby 3.4.2
- Node.js 24.2.0
- Yarn 1.22.22
- PostgreSQL (4 databases)
- Git

**Production:**
- Docker container (see Dockerfile)
- PostgreSQL (4 databases)
- RAILS_MASTER_KEY for secrets
- Environment variables for Telegram, ALTCHA, database credentials
- Kamal for orchestration (optional - can also run Docker manually)

**Docker Image Specifications:**
- Base: ruby:3.4.2-slim
- Build tools included: build-essential, git, libpq-dev, libyaml-dev, python
- Runtime libraries: curl, libjemalloc2, libvips, postgresql-client
- Precompiles assets during build (SECRET_KEY_BASE_DUMMY=1)
- Runs as non-root user (uid 1000:1000)
- Entrypoint: bin/docker-entrypoint (database setup)
- Server: Thruster with Rails server on port 80

---

*Stack analysis: 2026-04-08*
