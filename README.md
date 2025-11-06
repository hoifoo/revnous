# Revnous Web Application

A Rails 8 application for managing promotional content, case studies, pricing plans, and admin resources.

## Tech Stack

- **Ruby**: 3.4.2
- **Rails**: 8.0.3
- **Database**: PostgreSQL
- **Frontend**: Tailwind CSS 4, Stimulus, Turbo
- **Asset Pipeline**: Propshaft + esbuild
- **Authentication**: Devise
- **Testing**: RSpec, FactoryBot, Capybara, Database Cleaner

## Prerequisites

Before you begin, ensure you have the following installed:

- Ruby 3.4.2 (use `.ruby-version` file)
- Node.js 20+ and Yarn
- PostgreSQL
- Bundler (`gem install bundler`)

## Getting Started

### 1. Clone the repository

```bash
git clone <repository-url>
cd web
```

### 2. Install dependencies

```bash
# Install Ruby gems
bundle install

# Install JavaScript dependencies
yarn install
```

### 3. Database setup

```bash
# Create and setup the database
bin/rails db:create
bin/rails db:migrate
bin/rails db:seed  # Optional: Load seed data
```

### 4. Build assets

```bash
# Build JavaScript with esbuild
npm run build

# Build CSS with Tailwind
npm run build:css
```

### 5. Start the server

```bash
bin/rails server
```

Visit [http://localhost:3000](http://localhost:3000) to see the application.

## Development

### Running tests

```bash
# Run the entire test suite
bundle exec rspec

# Run a specific test file
bundle exec rspec spec/requests/admin/resource_deletion_spec.rb

# Run with coverage (if SimpleCov is configured)
COVERAGE=true bundle exec rspec
```

### Code quality

```bash
# Run RuboCop for linting
bin/rubocop

# Run Brakeman for security scanning
bin/brakeman
```

### Asset compilation

The application uses a modern asset pipeline:

- **JavaScript**: esbuild compiles files from `app/javascript/` to `app/assets/builds/`
- **CSS**: Tailwind CSS compiles from `app/assets/stylesheets/application.tailwind.css`

For development with auto-reloading:

```bash
# In separate terminal windows:
npm run build -- --watch
npm run build:css -- --watch
```

## Key Features

### Admin Dashboard
- Manage case studies, blogs, notices, and legal documents
- Admin authentication with role-based access control
- Product and pricing plan management
- Partner and trusted brand management
- Special offers configuration

### Public Features
- Display promotional content
- Case study showcase
- Pricing information
- Newsletter subscriptions
- Beta user registration

## Testing

The application uses RSpec with the following helpers:

- **FactoryBot**: For test data generation
- **Capybara**: For system/integration testing
- **Database Cleaner**: For database state management
- **Devise Test Helpers**: For authentication in tests

Test files are organized as:
- `spec/models/`: Model tests
- `spec/requests/`: Request/controller tests
- `spec/system/`: End-to-end browser tests
- `spec/factories/`: FactoryBot definitions

## Continuous Integration

The project uses GitHub Actions for CI/CD with three workflows:

1. **Security Scan**: Brakeman static analysis
2. **Lint**: RuboCop code style checks
3. **Test**: Full RSpec test suite with PostgreSQL

CI automatically:
- Installs dependencies (Ruby gems and Node packages)
- Builds assets
- Sets up the test database
- Runs the complete test suite

## Deployment

This app ships with Kamal configuration for container-based deploys (`config/deploy.yml`). If you prefer traditional SSH-based deployments, see the Capistrano plan:

- docs/deployment/capistrano.md

### Pre-deployment checklist

- [ ] All tests passing
- [ ] Assets precompiled
- [ ] Environment variables configured
- [ ] Database migrations ready
- [ ] Security scan clean

## Environment Variables

Key environment variables to configure:

```bash
# Database
DATABASE_URL=postgresql://user:password@localhost/dbname

# Rails
RAILS_ENV=production
SECRET_KEY_BASE=your-secret-key

# Add other environment-specific variables as needed
```

## Contributing

1. Create a feature branch (`git checkout -b feature/amazing-feature`)
2. Make your changes
3. Run tests (`bundle exec rspec`)
4. Run linters (`bin/rubocop`)
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## License

[Add your license information here]

