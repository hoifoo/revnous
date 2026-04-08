# Testing Infrastructure

**Analysis Date:** 2026-04-08

## Test Framework

- **RSpec**: Primary testing framework for Rails
- **Configuration**: `.rspec` file specifies default options
- **Test Location**: `spec/` directory mirrors `app/` structure

## Testing Strategy

### Unit Tests
- **Models**: Test business logic, validations, scopes, and associations
  - Located in `spec/models/`
  - Test ActiveRecord validations, custom methods, and relationships

- **Helpers**: Test view helper methods
  - Located in `spec/helpers/`

### Integration Tests
- **Controllers**: Test request handling and response status
  - Located in `spec/controllers/`
  - Test authorization, parameter handling, and rendering

- **Request Specs**: End-to-end tests for API and page responses
  - Located in `spec/requests/`
  - Test complete request/response cycles

## Test Organization

```
spec/
├── models/              # ActiveRecord model tests
├── controllers/         # Controller action tests
├── helpers/             # View helper tests
├── requests/            # Full request/response tests
└── spec_helper.rb       # RSpec configuration and shared setup
```

## Test Conventions

1. **File Naming**: `*_spec.rb` suffix for all test files
2. **Test Isolation**: Each test is independent with setup/teardown
3. **Fixtures/Factories**: Database seeding for test data (through fixtures or factory libraries)
4. **Mocking**: Selectively mock external dependencies while preferring integration tests with database

## Coverage Tools

- **SimpleCov**: Likely configured for measuring test coverage
- **CI Integration**: Tests likely run in GitHub Actions pipeline

## Development Workflow

1. Write tests first (TDD approach)
2. Run `bundle exec rspec` to execute tests
3. Run specific test file: `bundle exec rspec spec/models/product_spec.rb`
4. Run with coverage: May have custom rake task for coverage reporting

## Quality Standards

- All critical paths should have request specs
- Models must validate relationships and custom methods
- Controllers tested for authorization and state changes
- Views tested indirectly through request specs

## Known Testing Gaps

- No explicit mention of feature/system specs (browser-based tests)
- No obvious performance testing setup
- Limited visibility into test data factory setup (factories.rb or fixtures.rb not immediately evident)
