# Codebase Structure

**Analysis Date:** 2026-04-08

## Directory Layout

```
/Users/irfan/projects/revnous/web/
├── app/                          # Rails application code
│   ├── assets/                   # Static assets
│   │   ├── builds/               # Generated JS/CSS from esbuild & Tailwind
│   │   └── stylesheets/          # Source CSS (Tailwind)
│   ├── controllers/              # Request handlers
│   │   ├── admin/                # Admin namespace controllers
│   │   ├── application_controller.rb
│   │   ├── blogs_controller.rb
│   │   ├── products_controller.rb
│   │   ├── contacts_controller.rb
│   │   ├── beta_users_controller.rb
│   │   └── legal_documents_controller.rb
│   ├── helpers/                  # View helpers
│   ├── jobs/                     # Background jobs
│   │   └── application_job.rb
│   ├── mailers/                  # Email delivery
│   ├── models/                   # Core business logic
│   │   ├── application_record.rb
│   │   ├── product.rb
│   │   ├── blog.rb
│   │   ├── user.rb
│   │   ├── beta_user.rb
│   │   ├── contact.rb
│   │   ├── notice.rb
│   │   └── legal_document.rb
│   ├── views/                    # ERB templates
│   │   ├── layouts/
│   │   ├── home/
│   │   ├── products/
│   │   ├── blogs/
│   │   ├── devise/               # Authentication views
│   │   └── admin/                # Admin templates
│   └── javascript/               # Client-side logic
│       └── controllers/          # Stimulus JS controllers
├── config/                       # Rails configuration
│   ├── routes.rb
│   ├── database.yml
│   ├── environments/
│   ├── initializers/
│   └── locales/                  # i18n translations
├── db/                           # Database
│   ├── migrate/                  # Migrations
│   ├── seeds.rb
│   └── schema.rb
├── lib/                          # Custom libraries
├── public/                       # Static files
├── spec/                         # RSpec tests
│   ├── controllers/
│   ├── models/
│   ├── helpers/
│   ├── requests/
│   └── spec_helper.rb
├── package.json                  # Node dependencies
├── Gemfile                       # Ruby dependencies
├── Rakefile
└── config.ru                     # Rack entry point
```

## Module Organization

### Core Models
- **Product**: Product catalog management with attachments, pricing plans, and SEO metadata
- **Blog**: Content management with categorization and product associations
- **User**: Authentication via Devise with role-based access
- **BetaUser**: Beta program registration tracking
- **Contact**: Contact form submissions
- **Notice**: In-app notices with styling (background colors)
- **LegalDocument**: Legal agreements storage

### Controllers Structure
- **Public Controllers**: Handle user-facing requests (products, blogs, contacts)
- **Admin Controllers**: Nested under `/admin` namespace for dashboard functionality
- **Authentication**: Devise handles user authentication flows

### View Organization
- **Shared Layouts**: `app/views/layouts/` contains main application structure
- **Namespaced Views**: Views organized by controller namespace
- **Devise Views**: Pre-built authentication forms

### Asset Pipeline
- **Tailwind CSS**: Located in `app/assets/stylesheets/`
- **esbuild**: Compiles JavaScript bundles to `app/assets/builds/`
- **JavaScript Controllers**: Stimulus JS controllers for interactivity

## Key Entry Points
1. **Web Server**: `config.ru` loads Rails application
2. **Routes**: `config/routes.rb` defines all URL patterns
3. **Seeds**: `db/seeds.rb` initializes database with starter data
4. **Migrations**: `db/migrate/` manages schema evolution
