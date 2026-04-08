# Codebase Concerns & Technical Debt

**Analysis Date:** 2026-04-08

## Known Issues & Limitations

### Mixed Technology Stack
- **Rails MVC + Node.js toolchain**: Combines Ruby on Rails backend with Node.js-based frontend build tools (esbuild, Tailwind CSS)
- **Impact**: Adds complexity to deployment and development environment setup
- **Recommendation**: Consider standardizing on single tech stack or documenting integration points

### Frontend Architecture
- **Stimulus JS**: Lightweight approach suitable for server-rendered templates but may be limiting for complex UX
- **Tailwind CSS**: Good for rapid development but class-based styling can impact template readability
- **No SPA Framework**: Lacks modern frontend framework (React, Vue, etc.) which could limit user experience enhancement

### Authentication & Authorization
- **Devise**: Reliable for authentication but basic role-based access control
- **Recommendation**: Consider adding role-based authorization gem (Pundit, CanCanCan) for complex permission scenarios

## Technical Debt

### Code Quality Concerns
1. **View Complexity**: Some views may have significant business logic
   - Views should remain thin, delegating logic to helpers/models

2. **Model Responsibilities**: Rails models sometimes accumulate too much logic
   - Consider extracting service objects for complex workflows

3. **Polymorphic Content**: Uses polymorphic associations for content types
   - Powerful but can impact query performance and code clarity

### Performance Considerations

1. **Database Queries**
   - N+1 query risk with associations in views/templates
   - Recommendation: Use eager loading (includes, eager_load)

2. **Asset Pipeline**
   - esbuild + Tailwind CSS compilation may impact build times
   - Consider caching strategies for static assets

3. **Image Optimization**
   - Product and blog cover images should be optimized
   - Recommendation: Implement image variants (ActiveStorage)

## Dependencies & Version Management

### Ruby Dependencies
- Gemfile contains production and development gems
- Recommendation: Regular security audits of gems
- Action: Check for outdated or vulnerable dependencies

### Node Dependencies
- package.json contains 44+ node_modules directories
- Recommendation: Audit for vulnerabilities with `npm audit`
- Risk: Large dependency tree increases surface area

## Architectural Concerns

1. **Monolithic Application**: Single Rails application handles all domains
   - Suitable for current scale but may limit independent deployment
   - Recommendation: Consider service extraction if system grows

2. **SEO Handling**: Heavy reliance on meta tags and content management
   - Good foundation but ensure consistent SEO practices across all pages

3. **Localization (i18n)**: Translation files present
   - Need to verify consistent application across all user-facing strings

## Security Considerations

1. **File Uploads**: Uses ActiveStorage for document and image attachments
   - Ensure proper validation and virus scanning for legal documents

2. **User Input Validation**: Forms present (contacts, beta user registration)
   - Verify CSRF protection and SQL injection prevention

3. **Admin Panel Security**: Admin controllers require access control
   - Ensure role-based authorization is enforced

## Missing Coverage

### Testing Gaps
- No explicit feature/system tests (browser automation)
- Limited visibility into test data fixtures
- No apparent performance testing

### Documentation
- No API documentation if backend serves mobile/external clients
- Limited inline code comments for complex logic

### Infrastructure
- No visible docker-compose for local development
- Deployment configuration in `.kamal` but limited visibility

## Recommendations

### High Priority
1. ✅ Implement comprehensive test coverage with request specs
2. Add performance monitoring and profiling
3. Document authentication and authorization flows
4. Establish CSS class naming conventions (BEM or similar)

### Medium Priority
1. Extract complex business logic into service objects
2. Implement proper error handling and logging
3. Set up monitoring for background jobs
4. Document polymorphic association usage

### Low Priority
1. Consider upgrading frontend framework or justifying Stimulus JS choice
2. Implement API documentation if external clients consume endpoints
3. Add feature flag system for gradual rollouts
4. Consider rate limiting for public API endpoints
