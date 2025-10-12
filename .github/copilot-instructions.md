# Copilot Instructions for Revnous Web Application

## Architecture Overview
This is a Rails 8.0 marketing/content website with an admin panel. The app uses modern Rails conventions with Hotwire (Turbo + Stimulus), TailwindCSS, and PostgreSQL. Key architectural decisions:

- **Solid Stack**: Uses `solid_cache`, `solid_queue`, and `solid_cable` for database-backed Rails infrastructure
- **Admin Separation**: All admin functionality is namespaced under `Admin::` controllers with separate layout
- **Content Management**: Handles blogs, case studies, products, and marketing content with image attachments

## Development Workflow

### Starting Development
```bash
bin/dev  # Starts Rails server, JS/CSS watchers, and background jobs via Procfile.dev
```

### Asset Pipeline
- **JavaScript**: ESBuild bundles `app/javascript/*` → `app/assets/builds/` 
- **CSS**: TailwindCSS compiles `app/assets/stylesheets/application.tailwind.css` → `app/assets/builds/application.css`
- Watch modes run automatically via `bin/dev`

### Testing
- Uses Rails' built-in test framework with parallel execution
- Run with `bin/rails test` or `bin/rails test:system`

## Key Patterns & Conventions

### Models
- **Slug Generation**: Content models like `Blog` auto-generate slugs from titles in `before_validation`
- **Scoping**: Use published scopes: `Blog.published`, `featured`, `featured_on_home`
- **Image Attachments**: Models use `has_one_attached :image` for single images
- **HABTM Relations**: `Blog` has `has_and_belongs_to_many :products`

### Controllers
- **Admin Base**: All admin controllers inherit from `Admin::BaseController` which enforces authentication and admin role
- **Global Notice**: `ApplicationController` loads `@active_notice` for site-wide announcements
- **Modern Browser**: Uses `allow_browser versions: :modern` to enforce modern browser requirements

### Admin Panel
- Located at `/admin` with authentication via Devise
- Uses separate `admin` layout
- All admin controllers skip `:show` actions (index/new/create/edit/update/destroy only)
- Admin access controlled by `current_user.admin?` check

### Notice System
- Single active notice displayed site-wide
- Background colors defined as TailwindCSS gradient classes in `BACKGROUND_COLORS` constant
- Automatically deactivates other notices when one is marked active

## External Integrations

### Telegram Service
- `app/services/telegram.rb` handles bot communications
- Requires `TELEGRAM_API_TOKEN` and `TELEGRAM_CHAT_ID` environment variables
- Sends HTML-formatted messages to configured chat

### CAPTCHA
- Uses Altcha gem for CAPTCHA functionality
- Endpoint: `GET /altcha/challenge`

### Deployment
- **Kamal**: Configured for Docker deployment via `config/deploy.yml`
- **Database**: PostgreSQL with multiple schema files for different adapters
- **SSL**: Automatic via Let's Encrypt proxy configuration

## File Organization
- **Services**: Place business logic in `app/services/` (e.g., `Telegram`)
- **Admin Controllers**: Namespace under `app/controllers/admin/`
- **Concerns**: Use `app/models/concerns/` and `app/controllers/concerns/` for shared behavior
- **Assets**: Compiled assets go to `app/assets/builds/` (not `public/assets/`)

## Environment & Dependencies
- **Ruby**: Rails 8.0.3
- **Node**: Uses Yarn for package management
- **Authentication**: Devise with registration disabled (`skip: [:registrations]`)
- **Background Jobs**: Solid Queue (database-backed)
- **Cache/Cable**: Solid Cache and Solid Cable (database-backed)