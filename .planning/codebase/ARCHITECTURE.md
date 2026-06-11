# Architecture Overview

**Analysis Date:** 2026-04-08

## Quick Reference

**Architecture documentation is now split into specialized documents:**

- **[ARCHITECTURE-BACKEND.md](ARCHITECTURE-BACKEND.md)** — Rails controllers, models, database, services, async jobs, business logic
- **[ARCHITECTURE-FRONTEND.md](ARCHITECTURE-FRONTEND.md)** — Stimulus controllers, JavaScript, CSS, ERB views, client-side interactivity

---

## Pattern Overview

**Overall:** Monolithic Rails MVC with content management focus

**Key Characteristics:**
- Layered Rails architecture (Controllers → Models → Views)
- Server-rendered HTML with progressive enhancement via Stimulus
- Admin namespace separation with authorization
- Polymorphic content system (Products, Blogs, Case Studies, Legal Documents)
- Multi-product support with product-scoped content
- Hotwire stack (Turbo + Stimulus) for dynamic interactions
- Job-based async processing (Solid Queue)
- SEO-first design with metadata management
- Tailwind CSS for styling
- esbuild + Tailwind CLI for asset pipeline

## Layers (Reference)

### Backend Layers (see [ARCHITECTURE-BACKEND.md](ARCHITECTURE-BACKEND.md) for details)

- **Controller** — Route requests, authorize, coordinate business logic
- **Admin Authorization** — Enforce admin-only access via Admin::BaseController
- **Model/Data** — ActiveRecord models, validations, scopes, associations
- **Service** — External integrations (e.g., Telegram)
- **Background Job** — Async work via Solid Queue
- **Database** — PostgreSQL multi-database setup (primary, cache, queue, cable)

### Frontend Layers (see [ARCHITECTURE-FRONTEND.md](ARCHITECTURE-FRONTEND.md) for details)

- **View (ERB)** — Server-rendered templates with Stimulus integration
- **Stimulus** — Client-side interactivity (progressive enhancement)
- **JavaScript** — esbuild-bundled modules, Tiptap editor (coming)
- **CSS** — Tailwind CSS utility-first styling
- **Asset Pipeline** — Propshaft + esbuild + Tailwind CLI

## Data Flow Summary

**Public Content Request:**
Request → Rails router → Controller → Model query → View render → Response
(See Backend doc for details)

**Admin Content Creation:**
Admin form (Stimulus) → Controller → Strong params → Model → Persist → Response
(See Backend doc for details)

**Async Job Processing:**
Controller enqueues job → Solid Queue → Worker → Service → External API
(See Backend doc for details)

**State Management:**
- Persistent: PostgreSQL via ActiveRecord
- Session: Devise (encrypted cookies)
- View-level: Instance variables from controller
- Client-side: Stimulus (progressive enhancement only)

## Key Business Abstractions

See [ARCHITECTURE-BACKEND.md](ARCHITECTURE-BACKEND.md#key-business-abstractions) for details on:
- **Product** — Aggregate root, core business entity
- **Polymorphic Content** — Blogs, Case Studies, Legal Documents, Partners
- **SEO Metadata** — Page-level configuration keyed by controller#action
- **Beta User Registration** — Early adopter signups per product

## Entry Points

**Backend:**
- `app/controllers/application_controller.rb` — Base controller, SEO setup
- `app/controllers/home_controller.rb` — Homepage
- `app/controllers/blogs_controller.rb` — Public blog
- `app/controllers/admin/dashboard_controller.rb` — Admin entry
- `config/application.rb` — Rails config

**Frontend:**
- `app/javascript/application.js` — JS entry, Turbo + Stimulus + editor
- `app/views/layouts/application.html.erb` — Base layout
- `app/assets/stylesheets/application.tailwind.css` — CSS entry

## Error Handling

See [ARCHITECTURE-BACKEND.md](ARCHITECTURE-BACKEND.md#error-handling-strategy) for details:
- Controller exception handling: `rescue` + logging + user-friendly redirect
- Model validation errors: Prevent invalid data at model layer
- Async job errors: Solid Queue retries with exponential backoff

## Cross-Cutting Concerns

See [ARCHITECTURE-BACKEND.md](ARCHITECTURE-BACKEND.md#cross-cutting-concerns) for:
- **Authentication** — Devise gem (email/password, sessions)
- **Authorization** — Admin boolean flag, namespace-based access
- **Validation** — Model-level + form-level + CAPTCHA
- **Logging** — Rails.logger (info/error levels)

See [ARCHITECTURE-FRONTEND.md](ARCHITECTURE-FRONTEND.md#performance--optimization) for:
- **Asset Pipeline** — Propshaft + esbuild + Tailwind CLI
- **CSS Tree-Shaking** — Tailwind removes unused utilities (~25 KB gzipped)
- **JS Tree-Shaking** — esbuild removes dead code

---

*Architecture analysis: 2026-04-08*
