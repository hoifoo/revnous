# Coding Conventions

**Analysis Date:** 2026-04-08

## Naming Patterns

**Files:**
- Ruby models and controllers use PascalCase with underscores for multi-word names: `app/models/beta_user.rb`, `app/controllers/admin/blogs_controller.rb`
- View files match controller action names: `app/views/admin/blogs/index.html.erb`, `edit.html.erb`, `new.html.erb`
- Factory files are plural: `spec/factories/users.rb`, `spec/factories/blogs.rb`
- JavaScript controllers use snake_case: `app/javascript/controllers/hello_controller.js`

**Functions/Methods:**
- Use snake_case for method names: `generate_slug`, `verify_altcha_payload`, `format_telegram_message`, `set_seo_metadata`
- Private methods are grouped at the bottom of the class after `private` keyword
- Predicate methods use question mark: Methods are not yet shown in code samples, but Rails convention is followed

**Variables:**
- Instance variables use @: `@blog`, `@products`, `@admin`, `@active_notice`
- Local variables use snake_case: `telegram_message`, `payload_data`, `admin_user`
- Constants are UPPERCASE: `ALTCHA_HMAC_KEY` (accessed via ENV)

**Classes/Modules:**
- Models inherit from `ApplicationRecord`: `class Blog < ApplicationRecord`
- Controllers inherit from `Admin::BaseController` (admin) or `ApplicationController`: `class Admin::BlogsController < Admin::BaseController`
- Use singular names for models: `Blog`, `User`, `Product`, `BetaUser`
- Namespace admin controllers under `Admin::` module

## Code Style

**Formatting:**
- Tool: Rubocop with Rails Omakase configuration (`inherit_gem: { rubocop-rails-omakase: rubocop.yml }`)
- File: `.rubocop.yml` inherits from `rubocop-rails-omakase` which enforces Rails best practices
- Indentation: 2 spaces (Rails standard)
- String quotes: Single quotes preferred in most places, double quotes for interpolation

**Linting:**
- Tool: Rubocop (static analysis for code style and quality)
- Configuration: `rubocop-rails-omakase` gem provides opinionated Rails styling guidelines
- Security: Brakeman for Rails security vulnerability scanning
- No custom rules documented—uses default Omakase configuration

## Import Organization

**Order:**
1. Rails standard library imports: `require 'rails_helper'`, `require 'spec_helper'`
2. Framework includes (Devise, Capybara, etc.)
3. Custom support files: `Rails.root.glob('spec/support/**/*.rb').sort_by(&:to_s).each { |f| require f }`

**Path Aliases:**
- Not detected in this codebase (no `config/initializers/aliases.rb`)
- Uses relative requires and Rails' automatic class loading

## Error Handling

**Patterns:**
- Broad rescue with logging: `rescue => e` followed by `Rails.logger.error()`
- Example in `BetaUsersController#verify_altcha_payload`: Multiple rescue blocks for specific error types (JSON::ParserError) and generic fallback
- Early return pattern: Check conditions, return false if fails, continue if passes
- Uses guard clauses: `return false if condition`
- Exception details logged with backtrace: `Rails.logger.error("ALTCHA Backtrace: #{e.backtrace.first(5).join("\n")}")`

**Error Response:**
- Controllers redirect with alert messages: `redirect_to beta_signup_path, alert: "CAPTCHA verification failed..."`
- View validation errors displayed: `flash.now[:alert] = @beta_user.errors.full_messages.join(", ")`
- HTTP status codes used: `status: :unprocessable_entity` for validation failures

## Logging

**Framework:** Rails.logger (built-in)

**Patterns:**
- Info level for flow tracking: `Rails.logger.info("ALTCHA Verification START")`
- Error level for failures: `Rails.logger.error("ALTCHA FAILED: ...")`
- Structured logging with context: `Rails.logger.info("ALTCHA Payload received: #{altcha_payload.inspect}")`
- Inspect method used for debugging complex objects: `.inspect` on hashes and arrays
- No structured logging framework (e.g., Lograge) detected

## Comments

**When to Comment:**
- Minimal comments in code—Rails conventions are self-documenting
- Comments used for non-obvious logic: `# Fallback for console/tests` in `Blog#cover_photo_url`
- Section comments for logical groupings: `# SEO Meta Tags` in ApplicationHelper
- Comments explaining external integrations: ALTCHA verification has detailed inline comments

**Documentation:**
- No JSDoc/RDoc detected in provided files
- Method names are descriptive enough to avoid comments: `def verify_altcha_payload`, `def format_telegram_message`

## Function Design

**Size:** Controllers typically 30-60 lines per file; keep methods single-responsibility

**Parameters:**
- Controllers use params hash: `params.require(:blog).permit(...)`
- Strong parameters pattern enforced: `def blog_params` private method
- Params are white-listed before passing to models

**Return Values:**
- Models return objects or nil: Blog model returns instance or nil on failure
- Controllers return responses (redirect, render, or implicit nil)
- Scopes return ActiveRecord relations: `Blog.published`, `Product.active`

## Module Design

**Exports:**
- Rails uses automatic class loading—no explicit exports
- Models defined in `app/models/`
- Controllers defined in `app/controllers/`
- Helpers defined in `app/helpers/`

**Barrel Files:**
- Not used in this codebase
- JavaScript: `app/javascript/controllers/index.js` is minimal (likely auto-generated)

## Scope Management

**ActiveRecord Scopes:**
- Used for reusable query patterns: `scope :published, -> { where(...).order(...) }`
- Chainable design: `Blog.published.featured.order(...)`
- Default scope avoided (not detected)
- Defined in model files: `app/models/blog.rb`

**Class Methods:**
- Rarely used; scopes preferred for queries
- Private class methods used for setup: Not detected

## Associations

**Patterns:**
- One-to-many: `has_many :pricing_plans, dependent: :destroy`
- Many-to-many: `has_and_belongs_to_many :products`
- One-to-one: `has_one_attached :image` (Active Storage)
- Dependent cleanup: `dependent: :destroy` clears related records

**Validations:**
- Model-level validations: `validates :title, :content, presence: true`
- Uniqueness with allow_nil: `validates :slug, uniqueness: true, allow_nil: true`
- Custom validations: `before_validation :generate_slug, on: :create`

## Testing-Related Conventions

**Test Doubles:**
- FactoryBot for factories: `create(:user, :admin)`, `create(:blog)`
- Traits for variations: `:admin` trait in User factory
- Sequences for unique attributes: `sequence(:email) { |n| "user#{n}@example.com" }`

**Setup/Teardown:**
- `let` blocks for test data: `let(:admin) { create(:user, :admin) }`
- `before` hooks for authentication: `before { sign_in admin }`
- No explicit teardown—Rails transactional fixtures handle cleanup

---

*Convention analysis: 2026-04-08*
