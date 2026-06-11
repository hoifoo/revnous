# Frontend Architecture

**Analysis Date:** 2026-04-08  
**Focus:** Stimulus controllers, JavaScript, CSS, views, client-side interactivity

## Pattern Overview

**Overall:** Server-rendered Rails views with progressive enhancement via Stimulus

**Key Characteristics:**
- Server-rendered HTML (ERB templates)
- Hotwire stack: Turbo (SPA-like behavior) + Stimulus (interactivity)
- Client-side state: Minimal — Stimulus controllers for progressive enhancement only
- No JavaScript framework (React/Vue) — staying with Rails/Stimulus
- CSS: Tailwind CSS utility-first styling
- Asset pipeline: esbuild for JS bundling, Tailwind CLI for CSS
- Rich text editor: Trix + ActionText (content stored in action_text_rich_texts table)

## View Layer (ERB Templates)

**Location:** `app/views/`

**Structure:**
- Layouts: `app/views/layouts/application.html.erb`, `admin.html.erb`
- Public views: `app/views/blogs/`, `app/views/products/`, etc.
- Admin views: `app/views/admin/blogs/`, `app/views/admin/dashboard/`, etc.
- Partials: Shared across views for DRY rendering

**Responsibilities:**
- Render HTML from data passed by controllers (instance variables)
- Call view helpers for SEO (structured data, meta tags), content formatting
- Attach Stimulus controllers via `data-controller`, `data-action`, `data-target`
- Emit JavaScript via `content_for` blocks (e.g., `content_for :structured_data`)

**ERB Helper Usage:**
- `form_with` — Rails form builder with CSRF tokens, nested fields
- `link_to` — Rails link helper with Turbo integration
- `image_tag` — Rails asset helper with cache-busting
- Custom helpers from `app/helpers/` — `page_title`, `render_article_schema`, etc.

**View-Level State:**
- Instance variables set by controller actions (e.g., `@blog`, `@products`)
- Instance variables for SEO context (e.g., `@page_og_image`, `@canonical_url`)
- Rails session/cookies accessed via `session[]` and `cookies[]`

## Stimulus Controller Layer

**Location:** `app/javascript/controllers/`

**Framework:** Stimulus.js (lightweight MVC framework)
- Purpose: Attach behavior to DOM elements without full SPA
- Pattern: `data-controller`, `data-action`, `data-target` attributes on HTML
- Lifecycle: `connect()`, `disconnect()`, stimulus Values API

**Current Controllers (minimal):**
- `hello_controller.js` — example, minimal functionality
- (Additional controllers pending Tiptap editor migration)

**Future: Editor Controller (Tiptap Integration):**

```js
// app/javascript/controllers/editor_controller.js
export default class extends Controller {
  static targets = ["editor", "body"];
  static values = { content: String };

  connect() {
    // Initialize Tiptap editor on this.editorTarget
    // Call this.editor.commands.setContent(this.contentValue)
    // Attach form submit listener
  }

  disconnect() {
    // Cleanup: this.editor.destroy()
  }

  submit(event) {
    // Sync editor HTML to hidden field before form submit
    this.bodyTarget.value = this.editor.getHTML();
  }
}
```

**Stimulus Values & Targets:**
- Values: Type-safe data binding (String, Number, Boolean, Array, Object)
- Targets: References to specific DOM elements within the controller scope
- Actions: Event listeners declared in HTML (e.g., `data-action="change->editor#update"`)

**Stimulus + Turbo Compatibility:**
- Controllers must handle Turbo Drive page transitions
- `disconnect()` is the cleanup hook (called before navigation)
- Do NOT store state on `window` — leaks across Turbo navigations

## JavaScript Bundle & Module System

**Entry Point:** `app/javascript/application.js`

**Current Imports:**
```js
import "@hotwired/turbo-rails"        // Turbo Drive (SPA-like nav)
import "@stimulus/webpack-helpers"    // Stimulus auto-loader
import * as Stimulus from "@stimulus/core"
import { Application } from "@stimulus/core"
import { definitionsFromContext } from "@stimulus/webpack-helpers"
import "trix"                         // Trix editor (pre-Tiptap)
import "@rails/actiontext"            // ActionText helpers
import "altcha"                       // CAPTCHA client lib
```

**Future Changes (Tiptap migration):**
```js
// Remove: import "trix"
// Remove: import "@rails/actiontext"
// Add: import @tiptap/core, @tiptap/starter-kit, extensions
// Add: import DirectUpload from @rails/activestorage
```

**Bundler:** esbuild
- Config: `esbuild.config.mjs` (import from npm, minify in prod, tree-shake)
- Output: `app/assets/builds/application.js` (served by Propshaft)
- Tree-shaking: Unused code removed, reducing bundle size

**Module System:** ES6 imports/exports
- Each Stimulus controller is a module
- Stimulus application auto-discovers controllers via Webpack context
- No custom module orchestration — Stimulus handles it

## CSS & Styling Layer

**Framework:** Tailwind CSS 4.x
- Utility-first approach: compose classes like `flex items-center gap-4`
- No custom CSS files (beyond Tailwind config) — keep styling in HTML

**CSS Pipeline:**
- Input: `app/assets/stylesheets/application.tailwind.css`
- Config: `tailwind.config.js` (custom colors, fonts, breakpoints)
- Build tool: Tailwind CLI via npm script
- Output: `app/assets/builds/application.css` (served by Propshaft)
- Production: Minified, tree-shaken to remove unused utilities

**Custom CSS (minimal):**
- Prose utilities: `prose prose-lg` classes for semantic blog content
- Layout utilities: `flex`, `grid`, `container` for page structure
- Responsive design: `sm:`, `md:`, `lg:` breakpoints built-in

**Asset Pipeline:**
- Manager: Propshaft (Rails 7+ modern asset pipeline)
- Input: `app/assets/builds/` (generated by bundlers)
- Output: `/assets/` served with cache-busting hashes
- Fingerprinting: Rails auto-adds hash to filenames in production

## HTTP & Network Behavior

**Navigation:** Turbo Drive (automatic SPA-like behavior)
- Pattern: Turbo intercepts link clicks and form submissions
- Requests: AJAX with `Accept: text/vnd.turbo-stream.html`
- Response: HTML fragment inserted into DOM (no full page reload)
- Fallback: Full page reload for non-Turbo links (data-turbo="false")

**Form Submission:**
- Rails forms use Turbo by default (unless `local: true`)
- CSRF tokens: Rails form helpers add automatically
- Validation errors: Form re-renders with `@model.errors` displayed

**Page Caching:**
- Turbo cache: Stores previous page HTML for instant back navigation
- Cache invalidation: Turbo clears on form submit, manual nav
- Stimulus cleanup: `disconnect()` fires before cache eviction (safe to destroy editors)

## View-Level Data Binding

**Instance Variables → HTML:**
```erb
<%= @blog.title %>  <%# Renders blog title %>
<%= sanitize @blog.content %>  <%# Renders ActionText HTML (sanitized) %>
```

**Form Binding (Rails form helpers):**
```erb
<%= form_with model: [:admin, @blog], local: false do |form| %>
  <%= form.text_field :title %>
  <%= form.rich_text_area :content %>
<% end %>
```

**Stimulus Value Binding (hydration):**
```erb
<div data-controller="editor"
     data-editor-content-value="<%= @blog.body.gsub('"', '&quot;') %>">
  <%= form.hidden_field :body, data: { editor_target: "body" } %>
</div>
```

## Layout Structure

**Base Layout:** `app/views/layouts/application.html.erb`
- `<head>` — meta tags, stylesheets, scripts
- `<nav>` — global navigation
- `<main>` — content area (replaced by Turbo)
- Footer — global footer
- Rails helpers: `csrf_meta_tags`, `csp_meta_tag`, content_for blocks

**Admin Layout:** `app/views/layouts/admin.html.erb`
- Same as base, but with admin-specific sidebar navigation
- Admin styling: Different color scheme, layout
- Authentication check: Enforced by Admin::BaseController

**Partials & Components:**
- Author card: `app/views/shared/_author_card.html.erb`
- Blog preview: `app/views/shared/_blog_preview.html.erb`
- Form errors: `app/views/shared/_form_errors.html.erb`
- Reused across layouts via `<%= render 'shared/author_card', author: @blog.author %>`

## Rich Text Editor (Current: Trix → Future: Tiptap)

**Current Stack (Trix + ActionText):**
- Editor DOM: `form.rich_text_area :content` renders Trix editor
- Storage: `action_text_rich_texts` table (polymorphic, `record_type='Blog'`)
- Output: ActionText renders `<action-text-attachment>` elements
- Bundle size: ~150 KB (Trix + ActionText)

**Future Stack (Tiptap + Plain HTML):**
- Editor DOM: `<div data-editor-target="editor">` (Stimulus mount point)
- Storage: `blogs.body` text column (plain sanitized HTML)
- Stimulus lifecycle: `editor_controller.js` manages init, hydration, cleanup
- Output: Plain HTML (`<h1>`, `<p>`, `<img>`, etc.) — Tailwind prose styles directly
- Image uploads: Tiptap image extension → Rails ActiveStorage DirectUpload API
- Bundle size: ~50 KB (Tiptap + extensions, smaller than Trix)

## ActiveStorage & File Uploads

**Current Usage:**
- Blog cover images: Stored via ActiveStorage `has_one_attached :image`
- User avatars: Future, stored via `has_one_attached :avatar`
- OG image overrides: Future, stored via `has_one_attached :og_image`

**Direct Upload Flow:**
1. JavaScript `new DirectUpload(file, '/rails/active_storage/direct_uploads')`
2. Server returns blob metadata + signed upload URL
3. Browser POSTs file to upload endpoint
4. On success: Insert image into editor with signed_id URL

**URL Patterns:**
- Redirect: `/rails/active_storage/blobs/redirect/{signed_id}/{filename}`
- Proxy: `/rails/active_storage/blobs/proxy/{signed_id}/{filename}` (avoid in prod)
- URL stability: Signed IDs can expire — consider blob key indirection for long-term content

## SEO & Meta Tags (Server-Rendered)

**Location:** `app/views/layouts/application.html.erb` head section

**Generated by Helpers:** `app/helpers/application_helper.rb`
- `page_title` — `<title>` tag
- `page_description` — `<meta name="description">`
- `page_og_image` — `<meta property="og:image">`
- `canonical_url` — `<link rel="canonical">`
- `render_article_schema(blog)` — JSON-LD structured data
- `render_breadcrumbs_schema` — Breadcrumb structured data

**Data Source:**
- Controller sets instance vars: `@page_title`, `@page_description`, `@page_og_image`, `@canonical_url`
- ApplicationController loads SeoMetadatum per page (keyed by controller#action)
- Fallback: Derived from content if not explicitly set

**Rendering:**
```erb
<head>
  <title><%= page_title %></title>
  <meta name="description" content="<%= page_description %>">
  <meta property="og:image" content="<%= page_og_image %>">
  <link rel="canonical" href="<%= canonical_url %>">
  <%= render_article_schema(@blog) %>
  <%= render_breadcrumbs_schema(...) %>
</head>
```

## Browser Compatibility

**Target:** Modern browsers only (ES6+)
- Chrome/Edge 90+
- Firefox 88+
- Safari 14+
- No IE11 support

**Build & Polyfills:**
- esbuild target: `es2020` (no polyfills needed)
- Tailwind: CSS 3 features used (not all old browsers supported)
- Stimulus: ES6 classes required

**Fallback:** Non-Turbo-capable browsers receive full page reloads (works fine, just slower)

## Development & Hot Reloading

**CSS Hot Reload:**
```bash
yarn build:css --watch
```
Watches `app/assets/stylesheets/`, rebuilds to `app/assets/builds/application.css`

**JS Hot Reload:**
```bash
yarn build --watch
```
Watches `app/javascript/`, rebuilds to `app/assets/builds/application.js`

**Rails Server:**
```bash
./bin/dev
```
Runs Puma + CSS watcher + JS watcher in parallel (via Procfile.dev)

## Performance & Optimization

**Asset Fingerprinting:**
- Production: Rails adds content hash to filenames
- Browsers: 1-year cache headers on hashed assets
- Cache busting: Automatic on content change

**CSS Tree-Shaking:**
- Tailwind CLI scans HTML/JS for class usage
- Removes unused utilities from production CSS
- Result: ~25 KB gzipped (vs. full Tailwind 500+ KB)

**JS Tree-Shaking:**
- esbuild auto-detects unused imports
- Removes dead code paths
- Stimulus controllers: Only loaded if HTML has `data-controller`

**Lazy Loading:**
- Images: `loading="lazy"` on `<img>` tags
- JS modules: ES6 dynamic imports (future optimization)

---

*Frontend architecture documentation: 2026-04-08*
