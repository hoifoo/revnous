# Phase 3: SEO Fields & FAQ Schema - Research

**Researched:** 2026-05-22
**Domain:** Rails model/migration, ApplicationHelper JSON-LD, Stimulus controllers, ActiveStorage
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**FAQ Builder**
- D-01: Dynamic row UI via Stimulus controller — admin uses Add/Remove buttons; each row = one Q+A pair
- D-02: No hard limit on pairs per post
- D-03: FAQPage JSON-LD emitted only when at least one pair exists — no empty schema in head
- D-04: FAQ section placed at bottom of blog form, collapsible (collapsed by default; admin expands when needed)
- D-05: Stored as JSON in a `faq_schema` text column (serialized array of `{question, answer}` objects)

**Keywords**
- D-06: Tag-chip input UI — Enter key creates a chip, delete button removes it — requires a dedicated Stimulus controller
- D-07: Storage: `keywords` jsonb column on blogs table (array of strings `["seo","marketing","b2b"]`)
- D-08: `<meta name="keywords">` suppressed entirely when keywords array is empty/null — no empty tag
- D-09: Layout already has no keywords slot — must add `<meta name="keywords">` to `app/views/layouts/application.html.erb` conditional on a `page_keywords` helper (returns nil when blank)

**OG Image**
- D-10: `has_one_attached :og_image` on Blog model — ActiveStorage upload, same pattern as cover photo and user avatar
- D-11: Fallback chain in `page_og_image` helper (or blogs controller): `blog.og_image` → `blog.image` (cover photo) → site logo
- D-12: Existing `@page_og_image` assignment in blogs controller updated to implement the 3-step fallback; no change to the layout `og:image` meta tag

**Canonical URL**
- D-13: `canonical_url_override` string column on blogs table (nullable)
- D-14: Validation: `URI::DEFAULT_PARSER.make_regexp(%w[http https])` with `allow_blank: true` — same pattern as `linkedin_url` in Phase 2 User model
- D-15: Blank = fall back to `blog_url(@blog.slug)` (existing controller behavior) — no change to default
- D-16: Blogs controller sets `@canonical_url = @blog.canonical_url_override.presence || blog_url(@blog.slug)`

### Claude's Discretion
- Form field ordering within the SEO metadata grid — planner decides based on existing grid layout
- Chip input implementation detail (hidden field strategy for jsonb serialization to form params)
- Exact Stimulus controller names

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SEO-01 | Admin can enter keywords for a blog post; rendered as `<meta name="keywords">` in the page head | jsonb column + `page_keywords` helper + layout insertion point confirmed |
| SEO-02 | Admin can add FAQ question–answer pairs via dynamic form; rendered as FAQPage JSON-LD schema in page head | `render_faq_schema` helper pattern, `content_for :structured_data` hook in show.html.erb, FAQPage spec verified |
| SEO-03 | Admin can override the canonical URL; overrides `request.original_url` in page head | `canonical_url_override` string column, `canonical_url` helper in ApplicationHelper, blogs_controller `@canonical_url` assignment point confirmed |
| SEO-04 | Admin can upload OG image per post; falls back to cover photo, then site logo | `has_one_attached :og_image`, fallback chain in `page_og_image` helper, blogs_controller `@page_og_image` assignment point confirmed |
</phase_requirements>

---

## Summary

Phase 3 extends the existing blog admin form with four SEO fields. All integration points are already established from Phases 1 and 2: the `content_for :structured_data` block in `blogs/show.html.erb` is where FAQ JSON-LD goes, the `ApplicationHelper` already holds all JSON-LD helpers using the `json_escape(schema.to_json)` pattern, and the `blogs_controller.rb` show action already assigns `@canonical_url` and `@page_og_image`. Every change is additive — no existing code requires restructuring.

The most novel piece is the two new Stimulus controllers: `keywords-input` (tag-chip UI with hidden field sync) and `faq-builder` (dynamic add/remove rows from a `<template>` element). Both follow the `tiptap_editor_controller.js` Stimulus pattern already in the codebase. No new npm packages are required.

The database migration adds three columns (`keywords jsonb`, `faq_schema text`, `canonical_url_override string`) and one ActiveStorage attachment (`og_image`). PostgreSQL is already in use (pg 1.6.2); `jsonb` is a native PostgreSQL type requiring no additional extension enablement.

**Primary recommendation:** Implement as four vertical slices in a single wave, each slice touching model → migration → controller → form partial → helper → layout/show view. All four slices are independent of each other after the migration lands.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Keywords storage | Database | — | jsonb column on blogs table |
| Keywords form UI | Frontend (ERB + Stimulus) | — | Tag-chip Stimulus controller serializes to hidden fields; Rails form handles submit |
| `<meta keywords>` emission | Frontend Server (ERB layout) | ApplicationHelper | `page_keywords` helper returns nil when blank; layout conditionally renders tag |
| FAQ storage | Database | — | JSON serialized in `faq_schema` text column; model parses |
| FAQ form UI | Frontend (ERB + Stimulus) | — | `faq-builder` Stimulus controller; `<template>` element for row cloning |
| FAQPage JSON-LD emission | ApplicationHelper | blogs/show.html.erb | `render_faq_schema` helper called in `content_for :structured_data` |
| Canonical URL override | Database + API | ApplicationHelper | Controller reads `@blog.canonical_url_override.presence` and sets `@canonical_url`; helper reads `@canonical_url` |
| OG image storage | ActiveStorage | — | `has_one_attached :og_image` on Blog |
| OG image fallback chain | API (BlogsController) | ApplicationHelper | Controller builds URL and assigns `@page_og_image`; helper reads it |

---

## Standard Stack

### Core (all verified in codebase)

| Library | Version | Purpose | Source |
|---------|---------|---------|--------|
| Rails ActiveRecord migrations | 8.0.3 | Add `keywords jsonb`, `faq_schema text`, `canonical_url_override string` | [VERIFIED: db/schema.rb, existing migrations] |
| ActiveStorage `has_one_attached` | 8.0.3 | OG image attachment — same as `Blog#image` and `User#avatar` | [VERIFIED: app/models/blog.rb, app/models/user.rb] |
| `@hotwired/stimulus` | current (already in package.json) | `keywords-input` and `faq-builder` controllers | [VERIFIED: app/javascript/controllers/index.js] |
| `URI::DEFAULT_PARSER.make_regexp` | Ruby stdlib | Canonical URL validation — copy from `User#linkedin_url` | [VERIFIED: app/models/user.rb:12-16] |
| `json_escape(schema.to_json)` | Rails ActionView | FAQPage JSON-LD emission — established pattern in ApplicationHelper | [VERIFIED: app/helpers/application_helper.rb] |

### No New Dependencies

This phase adds zero new npm packages or Ruby gems. All required capabilities are already present. [VERIFIED: UI-SPEC.md registry safety section]

---

## Architecture Patterns

### System Architecture Diagram

```
Admin form submit
      │
      ▼
Admin::BlogsController#update
      │  strong_params: keywords:[], faq_schema:[[:question,:answer]],
      │                 canonical_url_override, og_image
      │
      ├──▶ Blog model
      │         │ before_save: parse_faq_schema (strip blanks, serialize JSON → faq_schema text)
      │         │ before_save: keywords stored as jsonb array (Rails handles natively)
      │         │ validation: canonical_url_override URI format (allow_blank)
      │         │ has_one_attached :og_image
      │         └──▶ PostgreSQL blogs table
      │
Public GET /blog/:slug
      │
      ▼
BlogsController#show
      │  @canonical_url = blog.canonical_url_override.presence || blog_url(blog.slug)
      │  @page_og_image = og_image_url || cover_photo_url || asset_url("logo.png")
      │  @page_keywords = blog.keywords  (read by page_keywords helper)
      │
      ▼
layouts/application.html.erb
      │  <link rel="canonical" href="<%= canonical_url %>">
      │  <meta property="og:image" content="<%= page_og_image %>">
      │  <meta name="keywords" ...> (conditional on page_keywords helper)
      │
blogs/show.html.erb
      └──▶ content_for :structured_data
                 render_article_schema(@blog)      ← existing
                 render_breadcrumbs_schema(...)    ← existing
                 render_faq_schema(@blog)          ← new, only when faq_schema.present?
```

### Recommended Project Structure (changes only)

```
db/migrate/
└── YYYYMMDD_add_seo_fields_to_blogs.rb   # keywords jsonb, faq_schema text, canonical_url_override string, og_image via has_one_attached

app/models/
└── blog.rb                               # has_one_attached :og_image, validate canonical_url_override, before_save parse_faq_schema

app/controllers/
└── blogs_controller.rb                   # update @canonical_url, @page_og_image with fallback chain

app/controllers/admin/
└── blogs_controller.rb                   # expand blog_params: keywords:[], faq_schema:[[:question,:answer]], :canonical_url_override, :og_image

app/helpers/
└── application_helper.rb                 # add render_faq_schema, page_keywords helpers

app/views/layouts/
└── application.html.erb                  # add <meta name="keywords"> after robots meta

app/views/admin/blogs/
└── _form.html.erb                        # add canonical_url_override input, keywords chip input,
                                          #   og_image file field, FAQ builder section

app/views/blogs/
└── show.html.erb                         # add render_faq_schema(@blog) to content_for :structured_data

app/javascript/controllers/
├── keywords_input_controller.js          # new: tag-chip UI
├── faq_builder_controller.js             # new: dynamic FAQ row add/remove
└── index.js                              # register both controllers
```

---

### Pattern 1: Migration for New SEO Columns

**What:** Single migration adding three scalar columns and one attachment (ActiveStorage handles the attachment via `has_one_attached` — no migration column needed for the attachment itself).

**Important:** `keywords` is a `jsonb` column which requires PostgreSQL. PostgreSQL is confirmed (pg 1.6.2, `adapter: postgresql` in database.yml). jsonb is a native PostgreSQL type — no `enable_extension` call needed. [VERIFIED: config/database.yml, db/schema.rb]

```ruby
# Source: db/migrate/20260519201530_add_spacing_to_blogs.rb (pattern)
class AddSeoFieldsToBlogs < ActiveRecord::Migration[8.0]
  def change
    add_column :blogs, :keywords, :jsonb, default: [], null: false
    add_column :blogs, :faq_schema, :text
    add_column :blogs, :canonical_url_override, :string
  end
end
```

The `og_image` attachment is declared in the model via `has_one_attached :og_image` — ActiveStorage creates its own records in `active_storage_attachments` and `active_storage_blobs`, no column on `blogs` table. [VERIFIED: existing `has_one_attached :image` on Blog, `has_one_attached :avatar` on User — neither has a column in the schema]

---

### Pattern 2: Blog Model Additions

**What:** Four additions to `app/models/blog.rb`: attachment, URL validation, FAQ parsing callback, and keyword accessor.

```ruby
# Source: app/models/user.rb:12-16 (linkedin_url validation pattern)
# Source: app/models/blog.rb (existing structure)

class Blog < ApplicationRecord
  has_one_attached :image
  has_one_attached :og_image    # NEW — D-10

  # ... existing code ...

  # Canonical URL validation (D-14) — identical to User#linkedin_url
  validates :canonical_url_override, format: {
    with: URI::DEFAULT_PARSER.make_regexp(%w[http https]),
    allow_blank: true,
    message: "must be a valid http or https URL"
  }

  before_save :parse_faq_schema    # NEW — D-05

  private

  # Strip blank pairs before serializing FAQ JSON (D-05)
  def parse_faq_schema
    # faq_schema arrives as Array of hashes from strong params
    # but may arrive as JSON string if the model is used directly
    return if faq_schema.blank?

    pairs = faq_schema.is_a?(String) ? JSON.parse(faq_schema) : Array(faq_schema)
    cleaned = pairs.reject { |p| p["question"].blank? && p["answer"].blank? }
    self.faq_schema = cleaned.empty? ? nil : cleaned.to_json
  rescue JSON::ParserError
    self.faq_schema = nil
  end
end
```

**Key detail about `faq_schema` flow:** The form submits `blog[faq_schema][][question]` and `blog[faq_schema][][answer]` — Rails parses these into an array of hashes (`[{"question"=>"...", "answer"=>"..."}]`) before they reach the controller. The strong params permit `faq_schema: [[:question, :answer]]`. The model's `before_save` callback receives this array, strips blanks, and serializes to JSON string for the `text` column.

---

### Pattern 3: ApplicationHelper New Methods

**What:** Two new public helper methods added to `ApplicationHelper`.

```ruby
# Source: app/helpers/application_helper.rb (existing pattern for all JSON-LD helpers)

def render_faq_schema(blog)
  return unless blog.faq_schema.present?

  pairs = JSON.parse(blog.faq_schema)
  return if pairs.blank?

  schema = {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    "mainEntity": pairs.map do |pair|
      {
        "@type": "Question",
        "name": pair["question"],
        "acceptedAnswer": {
          "@type": "Answer",
          "text": pair["answer"]
        }
      }
    end
  }

  content_tag :script, json_escape(schema.to_json), type: "application/ld+json"
rescue JSON::ParserError
  nil
end

def page_keywords
  # Returns nil when empty so layout can suppress the meta tag (D-08)
  keywords = @page_keywords
  return nil if keywords.blank?

  keywords.is_a?(Array) ? keywords.join(", ") : keywords.to_s.presence
end
```

**Note on `render_article_schema`:** Line 84 has a stale `.html_safe` call (`json_escape(schema.to_json).html_safe`) — this is redundant because `content_tag` already marks its output as html_safe. It is not a security issue but is inconsistent with the three other helpers in the file. This phase should clean it up when touching the helper. [VERIFIED: app/helpers/application_helper.rb:84]

---

### Pattern 4: BlogsController#show Updates

**What:** Replace the current two-line `@page_og_image` and `@canonical_url` assignments with the D-11 and D-16 fallback logic.

```ruby
# Source: app/controllers/blogs_controller.rb (current show action)
# Current:
#   @page_og_image = @blog.cover_photo_url if @blog.image.attached?
#   @canonical_url = blog_url(@blog.slug)
#
# Replace with (D-11, D-12, D-16):

def show
  @blog = Blog.find_by!(slug: params[:id])
  @page_title = @blog.seo_title
  @page_description = @blog.seo_description
  @page_og_type = "article"
  @page_og_image = og_image_for(@blog)       # NEW: 3-step fallback
  @canonical_url = @blog.canonical_url_override.presence || blog_url(@blog.slug)  # NEW: D-16
  @page_keywords = @blog.keywords             # NEW: SEO-01

  # ... related_blogs query unchanged ...
end

private

def og_image_for(blog)
  if blog.og_image.attached?
    url_for(blog.og_image)
  elsif blog.image.attached?
    blog.cover_photo_url
  else
    helpers.asset_url("logo.png")
  end
end
```

**Note:** `url_for` is available in controllers directly. `helpers.asset_url` is used inside controller private methods because `asset_url` is a view helper; alternatively, this logic can be moved to a model method or ApplicationHelper. Pattern to use: keep it in the controller using `helpers.asset_url` (matches how `cover_photo_url` delegates to `Rails.application.routes.url_helpers`). [VERIFIED: app/models/blog.rb:30-38 — cover_photo_url uses url_for]

A cleaner approach consistent with the model's existing `cover_photo_url` method: add an `og_image_url` method to the Blog model mirroring `cover_photo_url`, and call it from the controller.

---

### Pattern 5: Strong Parameters Expansion

**What:** `Admin::BlogsController#blog_params` must permit three new scalar fields and the array/nested hash params.

```ruby
# Source: app/controllers/admin/blogs_controller.rb:46-52 (current blog_params)

def blog_params
  permitted = %i[title author_id published_at category
                 excerpt body featured featured_on_home image og_image
                 meta_title meta_description spacing
                 canonical_url_override]
  permitted << :slug if action_name == 'create'
  params.require(:blog).permit(*permitted, product_ids: [], keywords: [],
                                faq_schema: [:question, :answer])
end
```

**Critical detail:** `keywords: []` permits an array of scalars (from multiple `blog[keywords][]` hidden inputs — the Stimulus controller's hidden field strategy). `faq_schema: [:question, :answer]` permits an array of hashes with those two keys. [VERIFIED: CONTEXT.md D-07 hidden field strategy; UI-SPEC.md FAQ param strategy]

---

### Pattern 6: Layout Keywords Meta Tag Insertion

**What:** Add one conditional line after the robots meta tag in `app/views/layouts/application.html.erb`.

```erb
<!-- Robots -->
<meta name="robots" content="<%= page_robots %>">

<%# NEW: Keywords — only rendered when present (D-08, D-09) %>
<% if page_keywords.present? %>
  <meta name="keywords" content="<%= page_keywords %>">
<% end %>
```

Insertion point: line 35 of `app/views/layouts/application.html.erb`, after the robots meta tag. [VERIFIED: app/views/layouts/application.html.erb:34-35]

---

### Pattern 7: show.html.erb FAQ Schema Call

**What:** Add `render_faq_schema(@blog)` to the existing `content_for :structured_data` block.

```erb
<%# Source: app/views/blogs/show.html.erb:1-8 (existing) %>
<% content_for :structured_data do %>
  <%= render_article_schema(@blog) %>
  <%= render_breadcrumbs_schema([
    { name: "Home", url: root_url },
    { name: "Blog", url: blogs_url },
    { name: @blog.title, url: blog_url(@blog.slug) }
  ]) %>
  <%= render_faq_schema(@blog) %><%# NEW — SEO-02; helper returns nil when no pairs %>
<% end %>
```

[VERIFIED: app/views/blogs/show.html.erb:1-8]

---

### Pattern 8: Stimulus `keywords-input` Controller

**What:** Tag-chip controller creating chips from keyboard events, syncing hidden fields for Rails array param.

```javascript
// app/javascript/controllers/keywords_input_controller.js
// Source: Stimulus conventions; UI-SPEC.md interaction contract
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "chipContainer"]

  connect() {
    this.renderChips()
  }

  addChip(event) {
    if (event.key === "Enter" || event.key === ",") {
      event.preventDefault()
      const value = this.inputTarget.value.trim()
      if (value) {
        this.keywords.push(value)
        this.inputTarget.value = ""
        this.renderChips()
      }
    } else if (event.key === "Backspace" && this.inputTarget.value === "") {
      this.keywords.pop()
      this.renderChips()
    }
  }

  removeChip(event) {
    const index = parseInt(event.currentTarget.dataset.index)
    this.keywords.splice(index, 1)
    this.renderChips()
  }

  get keywords() {
    // Read from existing hidden inputs on first call, then cache on element
    if (!this._keywords) {
      this._keywords = Array.from(
        this.element.querySelectorAll("input[type=hidden]")
      ).map(i => i.value)
    }
    return this._keywords
  }

  renderChips() {
    // Remove old hidden inputs and chips, re-render from this._keywords
    // ... implementation detail
  }
}
```

**Hidden field strategy (D-07 + UI-SPEC):** One `<input type="hidden" name="blog[keywords][]" value="...">` per keyword. The controller clears all hidden inputs and re-renders on every add/remove. Rails strong params `keywords: []` collects all values into an array. When no keywords exist, no hidden inputs exist, and Rails receives an empty array or nil — the model stores `[]` (the default).

**ERB wiring:**
```erb
<div data-controller="keywords-input" role="group" aria-label="Keywords">
  <div data-keywords-input-target="chipContainer"
       class="flex flex-wrap items-center gap-2 w-full px-3 py-2 border border-gray-300 rounded-md focus-within:ring-2 focus-within:ring-pink-500 min-h-[42px]">
    <%# Existing chips rendered on page load %>
    <% Array(@blog.keywords).each do |kw| %>
      <input type="hidden" name="blog[keywords][]" value="<%= kw %>">
      <%# chip span with × button ... %>
    <% end %>
    <input type="text"
           data-keywords-input-target="input"
           data-action="keydown->keywords-input#addChip"
           class="flex-1 min-w-[120px] px-2 py-1 text-sm outline-none bg-transparent"
           placeholder="Type a keyword and press Enter...">
  </div>
</div>
```

---

### Pattern 9: Stimulus `faq-builder` Controller

**What:** Dynamic row add/remove using a `<template>` element for row cloning. No index management needed because Rails accepts `blog[faq_schema][][question]` (unbounded array notation).

```javascript
// app/javascript/controllers/faq_builder_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["row", "template", "rowContainer"]

  addRow(event) {
    event.preventDefault()
    const content = this.templateTarget.content.cloneNode(true)
    this.rowContainerTarget.appendChild(content)
  }

  removeRow(event) {
    event.preventDefault()
    event.currentTarget.closest("[data-faq-builder-target='row']").remove()
  }
}
```

**ERB wiring (key pieces):**
```erb
<details <%= @blog.faq_schema.present? ? "open" : "" %> class="border border-gray-200 rounded-md bg-gray-50">
  <summary class="...">FAQ Schema</summary>

  <div class="px-4 pb-4 space-y-4" data-controller="faq-builder">
    <div data-faq-builder-target="rowContainer" class="space-y-4">
      <%# Pre-populate existing pairs %>
      <% (JSON.parse(@blog.faq_schema || "[]") rescue []).each do |pair| %>
        <%# row partial with values pre-filled %>
      <% end %>
    </div>

    <template data-faq-builder-target="template">
      <fieldset data-faq-builder-target="row" class="bg-white border border-gray-200 rounded-md p-4 space-y-3">
        <legend class="sr-only">FAQ pair</legend>
        <div>
          <label class="block text-sm font-semibold text-gray-700 mb-1">Question</label>
          <input type="text" name="blog[faq_schema][][question]"
                 data-faq-builder-target="question"
                 placeholder="e.g., What is Revnous?"
                 class="w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:ring-2 focus:ring-pink-500">
        </div>
        <div>
          <label class="block text-sm font-semibold text-gray-700 mb-1">Answer</label>
          <textarea name="blog[faq_schema][][answer]" rows="2"
                    data-faq-builder-target="answer"
                    placeholder="e.g., Revnous is a revenue optimization tool..."
                    class="w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:ring-2 focus:ring-pink-500"></textarea>
        </div>
        <button type="button" data-action="click->faq-builder#removeRow"
                class="inline-flex items-center gap-1 px-3 py-1 text-xs font-semibold text-red-600 border border-red-200 rounded-md hover:bg-red-50 transition-colors">
          Remove
        </button>
      </fieldset>
    </template>

    <button type="button" data-action="click->faq-builder#addRow"
            class="inline-flex items-center gap-2 px-4 py-2 text-sm font-semibold text-gray-700 border border-gray-300 rounded-md hover:bg-gray-50 transition-colors">
      + Add FAQ Pair
    </button>
  </div>
</details>
```

**Why `<template>` not innerHTML:** `<template>` content is inert (not parsed by the browser until cloned), which avoids duplicate `name` attribute issues and is the standard Stimulus pattern for dynamic row insertion. [ASSUMED — standard web platform pattern; no Stimulus-specific docs needed]

---

### Anti-Patterns to Avoid

- **Generating JSON-LD in views:** All `<script type="application/ld+json">` tags must come from helper methods using `json_escape` — not inline in ERB. [VERIFIED: established pattern in application_helper.rb]
- **Using `.to_json.html_safe` directly:** Rails' `json_escape` (alias: `j`) must wrap `.to_json` to prevent `</script>` injection. The one existing `.html_safe` call in `render_article_schema` is an acknowledged inconsistency — this phase should remove it. [VERIFIED: app/helpers/application_helper.rb:84]
- **Integer indices in FAQ field names:** Do not use `blog[faq_schema][0][question]`. Use `blog[faq_schema][][question]` (unbounded bracket notation) — Rails collects these correctly, and `<template>`-cloned rows don't need index management.
- **Storing keywords as comma-separated string:** CONTEXT.md D-07 is firm: `jsonb` array, not a string. The hidden-field-per-chip approach ensures Rails receives an array, not a joined string.
- **Omitting `allow_blank: true` on canonical URL validation:** Without it, blank canonical URLs (the common case — most posts don't override) fail validation. [VERIFIED: User#linkedin_url pattern in app/models/user.rb:14]
- **Registering Stimulus controllers manually without updating index.js:** The project uses the auto-manifest pattern (`bin/rails stimulus:manifest:update` / auto-import in index.js). New controllers must be registered in `app/javascript/controllers/index.js`. [VERIFIED: app/javascript/controllers/index.js]

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON-LD script tag with XSS protection | Custom escaping | `json_escape(schema.to_json)` in `content_tag :script` | Established pattern in this codebase; `json_escape` escapes `</` sequences |
| URL format validation | Custom regex | `URI::DEFAULT_PARSER.make_regexp(%w[http https])` | Already in User model, proven to reject `javascript:` schemes |
| ActiveStorage file uploads in forms | Custom upload handling | `form.file_field :og_image, accept: "image/*"` | Rails handles blob creation; `has_one_attached` purges old attachment on update |
| Dynamic DOM row insertion | Manual innerHTML | `<template>` element + `content.cloneNode(true)` | Inert until cloned; avoids parser issues with form inputs |
| jsonb array handling in Rails | Manual JSON encoding | Native ActiveRecord jsonb support | Rails 5+ with pg adapter handles jsonb automatically; query with `.where("keywords @> ?", ["seo"].to_json)` |

---

## Runtime State Inventory

Step 2.5 SKIPPED — this is a greenfield feature addition, not a rename/refactor/migration phase.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| PostgreSQL (pg adapter) | `keywords jsonb` column | Confirmed | pg 1.6.2 | — (no fallback; jsonb is PostgreSQL-only) |
| Ruby | Rails migrations, model | Confirmed | 3.4.2 | — |
| Node.js | Stimulus build (esbuild) | Confirmed | 24.2.0 | — |
| ActiveStorage | `has_one_attached :og_image` | Confirmed (already in use) | Rails 8.0.3 | — |
| Stimulus (`@hotwired/stimulus`) | New Stimulus controllers | Confirmed (in package.json, used by tiptap_editor_controller.js) | Current | — |

**Missing dependencies with no fallback:** None — all required tools are confirmed present.

---

## Common Pitfalls

### Pitfall 1: `keywords` jsonb Column Returns `nil` vs `[]` After Load

**What goes wrong:** When `keywords` is `nil` (existing rows before migration) or when no keywords are entered and the form submits no hidden inputs, `@blog.keywords` is `nil`, not `[]`. Calling `.join(", ")` on nil raises `NoMethodError`.

**Why it happens:** The migration sets `default: []` and `null: false` for new rows, but existing rows before migration have a nil value until the default back-fills.

**How to avoid:**
- In the migration, use `change_column_default` or add `null: false, default: []` and run `update_all` to back-fill existing rows. The simpler approach: use `Array(@blog.keywords)` anywhere the array is used in views/helpers. The `page_keywords` helper already guards with `.blank?`.
- In `ApplicationHelper#page_keywords`, use `Array(keywords).presence` — `Array(nil)` returns `[]`, and `[].presence` returns nil.

**Warning signs:** `NoMethodError: undefined method 'join' for nil` in the `page_keywords` helper or in the chip-rendering ERB.

---

### Pitfall 2: FAQ Rows Pre-populated Incorrectly on Edit

**What goes wrong:** On the edit form, existing FAQ pairs fail to render because `@blog.faq_schema` is a JSON string but the ERB tries to iterate it directly without parsing.

**Why it happens:** The `faq_schema` column stores a JSON string (text column, not jsonb). The model stores it serialized; the view must parse it.

**How to avoid:** Add a model convenience method:

```ruby
def faq_pairs
  return [] if faq_schema.blank?
  JSON.parse(faq_schema)
rescue JSON::ParserError
  []
end
```

Use `@blog.faq_pairs` in the form partial to iterate existing pairs for pre-population.

**Warning signs:** `NoMethodError: undefined method 'each' for "..."` in the form ERB, or completely empty FAQ section on edit of a post with existing FAQs.

---

### Pitfall 3: OG Image Not Replaced on Update (ActiveStorage Duplication)

**What goes wrong:** Uploading a new OG image creates a second attachment instead of replacing the old one, resulting in the old image being shown.

**Why it happens:** Without purging the previous attachment, `has_one_attached` accumulates attachments in edge cases.

**How to avoid:** Rails `has_one_attached` automatically handles replacement — assigning a new file via the form replaces the existing blob when `update` is called with the `:og_image` param. This is the standard behavior confirmed by the existing `has_one_attached :image` on Blog (cover photo upload never accumulates). [VERIFIED: existing cover photo behavior in prod — same attachment pattern]

**Warning signs:** `og_image.attached?` returns true but the image shown is the old one — investigate whether the attachment count > 1 in the database.

---

### Pitfall 4: Canonical URL Override Validation Error on Blank Existing Posts

**What goes wrong:** Adding the `canonical_url_override` validation without `allow_blank: true` breaks saves for all existing posts that have no canonical override set.

**Why it happens:** `validates :canonical_url_override, format: { with: ... }` without `allow_blank: true` runs the regex against an empty string, which fails the URI match.

**How to avoid:** Always include `allow_blank: true` — this is already the pattern on `User#linkedin_url`. [VERIFIED: app/models/user.rb:12-16]

**Warning signs:** "Canonical url override must be a valid http or https URL" validation errors on every blog save even when the field is blank.

---

### Pitfall 5: `<template>` Content Not Accessible to Stimulus Until Cloned

**What goes wrong:** Stimulus `targets` scan inside `<template>` content and falsely detect targets that are not yet in the live DOM, causing errors in methods that iterate `this.rowTargets`.

**Why it happens:** By default, Stimulus does not scan `<template>` content for targets — the content is inert. However, if the template element itself is inside the controller element, some Stimulus versions may scan it.

**How to avoid:** Place the `<template>` as a direct child of the controller element but ensure the Stimulus controller only queries `rowTargets` (live DOM nodes appended via `addRow`), not the template's internal targets. The `<template>` element itself should not be a target. [ASSUMED — based on known Stimulus behavior; verify during implementation if unexpected target counts appear]

**Warning signs:** `removeRow` removes the template element itself instead of a live row.

---

### Pitfall 6: FAQPage JSON-LD Fails Google Rich Results Test if FAQ Not Visible on Page

**What goes wrong:** Google's FAQPage rich result requires the questions and answers to also be visible on the rendered page, not only in JSON-LD. If FAQ pairs are only in the schema and not displayed in the blog body, Google may reject the structured data with a "Page content doesn't match" violation.

**Why it happens:** Google's FAQPage guidelines require FAQ content to be accessible to users on the page.

**How to avoid:** This phase does not render FAQ pairs as visible HTML on the show page — only the JSON-LD schema is emitted. This is a known limitation. Options: (a) add a visible FAQ section to `blogs/show.html.erb` that renders pairs from `@blog.faq_pairs`, or (b) inform the marketing team that Google may not surface rich results for posts where FAQ pairs are not also visible in the body.

**Recommendation:** Add a visible FAQ section partial below the blog content in `blogs/show.html.erb` that renders only when `@blog.faq_pairs.any?`. This is a required companion to the JSON-LD emission and should be included in the plan. [CITED: https://developers.google.com/search/docs/appearance/structured-data/faqpage]

**Warning signs:** Google Search Console "Enhancement: FAQs" showing "Invalid items detected" with "Page content doesn't match structured data."

---

## Code Examples

### FAQPage JSON-LD — Correct Structure

```json
{
  "@context": "https://schema.org",
  "@type": "FAQPage",
  "mainEntity": [
    {
      "@type": "Question",
      "name": "What is Revnous?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "Revnous is a revenue optimization tool for Shopify merchants."
      }
    }
  ]
}
```

Required properties per Google: `@type: FAQPage`, `mainEntity` array, each item `@type: Question`, `name` (question text), `acceptedAnswer.@type: Answer`, `acceptedAnswer.text`. [CITED: https://developers.google.com/search/docs/appearance/structured-data/faqpage]

---

### jsonb Column in Rails 8 + PostgreSQL

```ruby
# Migration (no enable_extension needed — jsonb is native PostgreSQL)
add_column :blogs, :keywords, :jsonb, default: [], null: false

# Model — no serialize needed; ActiveRecord handles jsonb natively
# blog.keywords returns Array (e.g., ["seo", "marketing"])
# blog.keywords = ["seo", "marketing"]  # assigns and saves correctly

# Safe access in views
Array(@blog.keywords).each { |kw| ... }   # nil-safe
```

[VERIFIED: PostgreSQL is the primary database (config/database.yml adapter: postgresql); pg 1.6.2 confirmed in Gemfile.lock]

---

### Strong Parameters for Array + Nested Hash

```ruby
# Permits: keywords[] (array of strings) + faq_schema[][question] + faq_schema[][answer]
params.require(:blog).permit(
  :title, :canonical_url_override, :og_image,
  keywords: [],
  faq_schema: [:question, :answer]
)
```

Rails collects `blog[keywords][]` into `params[:blog][:keywords]` as `Array<String>`. Rails collects `blog[faq_schema][][question]` and `blog[faq_schema][][answer]` into `params[:blog][:faq_schema]` as `Array<ActionController::Parameters>`. [VERIFIED: existing blog_params pattern in admin/blogs_controller.rb uses `product_ids: []` for array permit]

---

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| `schema.to_json.html_safe` | `json_escape(schema.to_json)` | SEC-02 fix already applied in Phases 1/2; `render_article_schema` still has a stale `.html_safe` on line 84 — should be cleaned in this phase |
| ActionText attachment for images | `has_one_attached` + plain URL | Established since Phase 1; og_image follows same pattern |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `<template>` element cloning via `content.cloneNode(true)` is the correct pattern for Stimulus dynamic rows and does not produce false target detections | Pattern 9, Pitfall 5 | Low — standard web platform feature; if issues arise, use a different template strategy (hidden div with `display:none`) |
| A2 | `og_image_url` helper should live on the Blog model (mirroring `cover_photo_url`) rather than inline in the controller private method | Pattern 4 | Low — either location works; model method is more testable and consistent |
| A3 | The visible FAQ section on the blog show page is required by Google for FAQPage rich results eligibility | Pitfall 6 | Medium — if Google's current policy only requires JSON-LD without visible content, this is extra work; but Google's documented guidelines state content must be accessible to users |

---

## Open Questions (RESOLVED)

1. **Visible FAQ HTML on show page**
   - What we know: Google FAQPage guidelines say content must be visible on the page
   - What's unclear: Whether the plan should include a visible FAQ section partial in `blogs/show.html.erb` as part of this phase or defer it
   - RESOLVED: Include it — it is a small addition (`@blog.faq_pairs.any?` guard + simple `<dl>` or `<details>` rendering below the body) and is required for rich results to work correctly. The planner should add this as a task alongside the JSON-LD emission task.

2. **`@blog[:author]` vs `@blog.author` collision in form**
   - What we know: The admin form has both `blog[:author]` (legacy string) and `blog.author` (User association via `author_id`). The controller handles this separately (`@blog[:author] = params.dig(:blog, :author).presence`).
   - What's unclear: No conflict with Phase 3 fields — this is noted as context only, not a blocker.
   - RESOLVED: No action needed; preserve the existing pattern.

---

## Project Constraints (from CLAUDE.md)

These directives are extracted from `./CLAUDE.md` and apply to all planning and implementation:

- Must stay on Rails/Stimulus/esbuild — NO React/Vue frontend frameworks
- Tiptap output stored as sanitized HTML in plain `text` column — not ActionText
- Image uploads: ActiveStorage direct uploads; use existing Rails blob endpoint
- No external SEO plugins — all SEO/schema logic stays server-side in Rails helpers
- Ruby naming: snake_case methods, PascalCase classes, `@blog` instance variables
- Controllers under `Admin::` namespace inherit from `Admin::BaseController`
- Strong parameters via `def blog_params` private method in controller
- Use `URI::DEFAULT_PARSER.make_regexp` for URL validation (not custom regex)
- Error handling: rescue with `Rails.logger.error`, redirect with flash alert
- Test framework: RSpec + FactoryBot + Capybara (specs in `spec/` directory)
- Two-tier admin auth: Devise + `User#admin?` boolean — all admin routes require authenticated admin

---

## Validation Architecture

> Skipped — `workflow.nyquist_validation` is explicitly `false` in `.planning/config.json`.

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V5 Input Validation | yes | URI::DEFAULT_PARSER for canonical URL; strong params whitelist for all new fields |
| V5 Output Encoding | yes | `json_escape` in all JSON-LD helpers; `sanitize` helper for blog body (existing) |
| V6 Cryptography | no | — |
| V2 Authentication | no | Admin authentication already enforced by `Admin::BaseController` |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| `</script>` injection in FAQ text | Tampering | `json_escape(schema.to_json)` in `render_faq_schema` — same pattern as all other JSON-LD helpers |
| `javascript:` scheme in canonical_url_override | Tampering | `URI::DEFAULT_PARSER.make_regexp(%w[http https])` validation rejects non-http(s) schemes at model layer |
| XSS via keywords rendered into meta tag | Tampering | ERB auto-escaping handles `<%= page_keywords %>` in `content=` attribute — no `raw` or `html_safe` needed |
| Overly permissive strong params for faq_schema | Tampering | `faq_schema: [:question, :answer]` allows only those two keys per hash — no arbitrary key injection |

---

## Sources

### Primary (HIGH confidence)
- [VERIFIED: app/helpers/application_helper.rb] — existing JSON-LD helpers, `json_escape` pattern, `canonical_url` helper, `page_og_image` helper
- [VERIFIED: app/controllers/blogs_controller.rb] — `@canonical_url` and `@page_og_image` assignment points in show action
- [VERIFIED: app/controllers/admin/blogs_controller.rb] — strong params structure, `blog_params` method
- [VERIFIED: app/models/blog.rb] — existing columns, `has_one_attached :image`, ALLOWED_TAGS/ALLOWED_ATTRIBUTES
- [VERIFIED: app/models/user.rb] — `URI::DEFAULT_PARSER.make_regexp` validation pattern for `linkedin_url`
- [VERIFIED: app/views/layouts/application.html.erb] — robots meta tag insertion point (line 35), `page_og_image` and `canonical_url` usage
- [VERIFIED: app/views/blogs/show.html.erb] — `content_for :structured_data` block, existing JSON-LD calls
- [VERIFIED: app/views/admin/blogs/_form.html.erb] — existing grid structure, cover photo field pattern
- [VERIFIED: app/views/admin/users/_form.html.erb] — `has_one_attached :avatar` form pattern
- [VERIFIED: db/schema.rb] — current blogs table columns, no jsonb columns yet
- [VERIFIED: config/database.yml] — PostgreSQL adapter confirmed
- [VERIFIED: Gemfile.lock] — pg 1.6.2 confirmed
- [VERIFIED: .planning/config.json] — `nyquist_validation: false`
- [VERIFIED: app/javascript/controllers/index.js] — Stimulus controller registration pattern

### Secondary (MEDIUM confidence)
- [CITED: https://developers.google.com/search/docs/appearance/structured-data/faqpage] — FAQPage JSON-LD required properties: `FAQPage`, `mainEntity`, `Question.name`, `acceptedAnswer.text`; visible content requirement

### Tertiary (LOW confidence)
None.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries are existing project dependencies, verified in lockfile and source
- Architecture: HIGH — all integration points verified in actual source files (controller, helper, views, schema)
- Pitfalls: HIGH for Rails patterns (verified); MEDIUM for Google FAQPage content requirement (cited from official docs); LOW for Stimulus `<template>` edge case (A1 assumed)
- FAQPage spec: HIGH — cited from Google Search Central docs

**Research date:** 2026-05-22
**Valid until:** 2026-08-22 (stable Rails/Stimulus stack; Google structured data guidelines change infrequently)
