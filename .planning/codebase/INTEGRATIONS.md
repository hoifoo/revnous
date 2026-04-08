# External Integrations

**Analysis Date:** 2026-04-08

## APIs & External Services

**Telegram Bot:**
- Service: Telegram Bot API
- What it's used for: Sending notifications for beta user signups and newsletter events
- SDK/Client: Custom HTTP client via `Net::HTTP` (Ruby standard library)
- Auth: `TELEGRAM_API_TOKEN` environment variable
- Implementation: `app/services/telegram.rb`
- Endpoint: `https://api.telegram.org/bot{token}/sendMessage`
- Usage:
  - `app/jobs/internal_event_job.rb` - Asynchronous job that sends messages via Telegram.send_message()
  - `app/controllers/beta_users_controller.rb` - Triggers Telegram notification on new beta user signup
  - `app/controllers/newsletters_controller.rb` - Sends Telegram notification for newsletter events
- Response format: JSON (parsed via JSON.parse)
- Parse mode: HTML (supports HTML formatting in messages)

**CAPTCHA Service:**
- Service: ALTCHA (Automated Low-Traffic Captcha for Humans & Anonymity)
- What it's used for: Form protection for beta signups and other user submissions
- SDK/Client:
  - Ruby: `altcha` gem 0.2.1
  - JavaScript: `altcha` npm package 2.2.4 with crypto support
- Auth: `ALTCHA_HMAC_KEY` environment variable (32-byte hex-encoded secret)
- Implementation:
  - Verification: `app/controllers/beta_users_controller.rb` - verify_altcha_payload method
  - Frontend: JavaScript integration for challenge submission
  - Payload handling: Base64 decoded or direct JSON parsing
- Verification process:
  - Receives altcha payload from form (params[:altcha])
  - Decodes if Base64 encoded
  - Validates HMAC signature using ALTCHA_HMAC_KEY
  - Logs payload for debugging (ALTCHA Payload received log message)

## Data Storage

**Databases:**
- Type/Provider: PostgreSQL (all environments)
- Connection: Configured via `config/database.yml` and ENV variables
- Client: `pg` gem 1.6.2
- ORM: Rails ActiveRecord 8.0.3
- Database instances (4 separate PostgreSQL databases per environment):
  1. **primary** - Main application data (users, beta_users, newsletters, etc.)
  2. **cache** - solid_cache store (fragment caching, cache keys)
  3. **queue** - solid_queue jobs table (background job processing)
  4. **cable** - solid_cable messages table (WebSocket/ActionCable state)

**Development Databases:**
- web_development_primary
- web_development_cache
- web_development_queue
- web_development_cable

**Production Databases:**
- revnous_web_production
- revnous_web_production_cache
- revnous_web_production_queue
- revnous_web_production_cable

**File Storage:**
- Local filesystem only (config/storage.yml service: Disk)
- Development: `tmp/storage`
- Production: `storage` directory (must be persisted outside container)
- Commented-out options for AWS S3, Google Cloud Storage, Azure Storage (not currently active)
- Used for ActionStorage file uploads (images, documents, rich text attachments)

**Caching:**
- solid_cache 1.0.7 - Database-backed cache (queries a PostgreSQL database)
- Cache TTL and behavior configured in config/cache.yml
- Development and test use in-memory caching, production uses solid_cache_store

## Authentication & Identity

**Auth Provider:**
- Custom with Devise
- Implementation: `devise` gem 4.9.4
- Approach:
  - User model: `app/models/user.rb` with devise modules
  - Configured modules: :database_authenticatable, :registerable (and others)
  - Password hashing: bcrypt 3.1.20 (via devise)
  - Session management via Warden (devise dependency)
- Database: PostgreSQL users table (primary database)
- Configuration: `config/initializers/devise.rb`
- Mailer: devise_mailer (for password reset, confirmation emails)

## Monitoring & Observability

**Error Tracking:**
- None detected in active use

**Logs:**
- Approach: STDOUT logging with request ID tagging
- Configuration (production): `config/environments/production.rb`
  - Logger: ActiveSupport::TaggedLogging with STDOUT output
  - Log level: INFO (via RAILS_LOG_LEVEL ENV var, default "info")
  - Log tags: :request_id (automatically added to all log lines)
  - Silence health check logs: /up endpoint
- Development logging configured in `config/environments/development.rb`
- Test logging uses standard Rails test mode

**Security Scanning:**
- brakeman 7.1.0 - Static analysis for Rails security issues
- Run via: `bundle exec brakeman` (dev/test dependency)

## CI/CD & Deployment

**Hosting:**
- Docker containers (self-hosted or cloud agnostic)
- Dockerfile: Production-optimized multi-stage build
- Node 24.2.0 and Ruby 3.4.2 compiled in build stage

**CI Pipeline:**
- Kamal 2.7.0 (deployment orchestration tool)
- Configuration: `.kamal/` directory with secrets
- Supports containerized deployment across multiple servers
- Alternative: Traditional SSH-based deployment via Capistrano (configured but optional)

**Build Process:**
1. esbuild bundles JavaScript from app/javascript/* to app/assets/builds/
2. Tailwind CSS CLI processes application.tailwind.css to app/assets/builds/application.css
3. Assets precompiled during Docker build stage (SECRET_KEY_BASE_DUMMY=1)
4. Node modules removed after precompilation to reduce image size

## Environment Configuration

**Required env vars:**
- TELEGRAM_API_TOKEN - Telegram bot token for notifications
- TELEGRAM_CHAT_ID - Telegram target chat ID
- ALTCHA_HMAC_KEY - CAPTCHA HMAC secret (32-byte hex string, generated with `openssl rand -hex 32`)
- RAILS_MASTER_KEY - Rails credentials decryption key (production)
- DATABASE_USERNAME - PostgreSQL username (production)
- DATABASE_PASSWORD - PostgreSQL password (production)
- POSTGRES_HOST - PostgreSQL hostname (test environment)
- RAILS_LOG_LEVEL - Log level (default: "info", production)
- RAILS_MAX_THREADS - Database connection pool size (default: 5)

**Optional env vars:**
- RAILS_ENV - Environment (development, test, production)
- SECRET_KEY_BASE_DUMMY=1 - For Docker asset precompilation build stage

**Secrets location:**
- config/credentials.yml.enc (Rails encrypted secrets)
- .env files (managed by figaro, not in git)
- Environment variables (Docker/deployment platform)
- .kamal/secrets (Kamal deployment secrets, not in git)

## Webhooks & Callbacks

**Incoming:**
- None detected

**Outgoing:**
- Telegram notifications (one-way HTTP POST to Telegram API)
  - Triggered by: beta user signups, newsletter events
  - No webhook response processing (fire-and-forget via async job)

## Service Dependencies Summary

| Service | Type | Status | Critical |
|---------|------|--------|----------|
| PostgreSQL | Database | Required for all environments | Yes |
| Telegram Bot API | External notification | Required for user notifications | No (graceful degradation needed) |
| ALTCHA API | CAPTCHA | Required for form protection | Yes |
| Docker Registry | Build/Deploy | Required for production | Yes (if using containers) |
| Yarn/npm | Package manager | Required for development | Yes |

---

*Integration audit: 2026-04-08*
