# Phase 3: SEO Fields & FAQ Schema - Context

**Gathered:** 2026-05-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Add 4 new per-post SEO fields to the blog admin form and wire them into the page head and JSON-LD:
- **Keywords** — jsonb column, tag-chip UI (Stimulus), emits `<meta name="keywords">` when present
- **FAQ pairs** — JSON serialized in `faq_schema` text column, dynamic add/remove rows (Stimulus), emits FAQPage JSON-LD only when pairs exist
- **Canonical URL override** — string column, overrides `@canonical_url` in controller when present, falls back to `blog_url(blog.slug)`
- **OG image** — `has_one_attached :og_image`, overrides cover photo in `@page_og_image` fallback chain

</domain>

<decisions>
## Implementation Decisions

### FAQ Builder
- **D-01:** Dynamic row UI via Stimulus controller — admin uses Add/Remove buttons; each row = one Q+A pair
- **D-02:** No hard limit on pairs per post
- **D-03:** FAQPage JSON-LD emitted **only** when at least one pair exists — no empty schema in head
- **D-04:** FAQ section placed at **bottom of blog form, collapsible** (collapsed by default; admin expands when needed)
- **D-05:** Stored as JSON in a `faq_schema` text column (serialized array of `{question, answer}` objects)

### Keywords
- **D-06:** Tag-chip input UI — Enter key creates a chip, delete button removes it — requires a dedicated Stimulus controller
- **D-07:** Storage: `keywords` **jsonb column** on blogs table (array of strings `["seo","marketing","b2b"]`)
- **D-08:** `<meta name="keywords">` suppressed entirely when keywords array is empty/null — no empty tag
- **D-09:** Layout already has no keywords slot — must add `<meta name="keywords">` to `app/views/layouts/application.html.erb` conditional on a `page_keywords` helper (returns nil when blank)

### OG Image
- **D-10:** `has_one_attached :og_image` on Blog model — ActiveStorage upload, same pattern as cover photo and user avatar
- **D-11:** Fallback chain in `page_og_image` helper (or blogs controller): `blog.og_image` → `blog.image` (cover photo) → site logo
- **D-12:** Existing `@page_og_image` assignment in blogs controller updated to implement the 3-step fallback; no change to the layout `og:image` meta tag

### Canonical URL
- **D-13:** `canonical_url_override` string column on blogs table (nullable)
- **D-14:** Validation: `URI::DEFAULT_PARSER.make_regexp(%w[http https])` with `allow_blank: true` — same pattern as `linkedin_url` in Phase 2 User model
- **D-15:** Blank = fall back to `blog_url(@blog.slug)` (existing controller behavior) — no change to default; override only applied when present
- **D-16:** Blogs controller sets `@canonical_url = @blog.canonical_url_override.presence || blog_url(@blog.slug)`

### Claude's Discretion
- Form field ordering within the SEO metadata grid — planner decides based on existing grid layout
- Chip input implementation detail (hidden field strategy for jsonb serialization to form params)
- Exact Stimulus controller names

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing SEO Infrastructure
- `app/helpers/application_helper.rb` — `canonical_url`, `page_og_image`, `page_keywords` hooks; `render_article_schema`; `json_escape` pattern
- `app/views/layouts/application.html.erb` — head meta tags; where `<meta name="keywords">` must be inserted
- `app/controllers/blogs_controller.rb` — `@canonical_url` and `@page_og_image` assignments to override

### Phase Context
- `app/models/blog.rb` — ALLOWED_TAGS/ALLOWED_ATTRIBUTES, existing validations, `generate_slug`; `linkedin_url` URL validation pattern to reuse for canonical
- `app/models/user.rb` — `linkedin_url` URI::DEFAULT_PARSER validation pattern (reuse for canonical_url_override)
- `app/views/admin/blogs/_form.html.erb` — current form structure; metadata grid layout; existing collapsible patterns if any
- `db/schema.rb` — blogs table columns (add: keywords jsonb, faq_schema text, canonical_url_override string)

### Requirements
- `.planning/REQUIREMENTS.md` — SEO-01, SEO-02, SEO-03, SEO-04

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `URI::DEFAULT_PARSER.make_regexp(%w[http https])` validation — already in `user.rb` for `linkedin_url`; copy for `canonical_url_override`
- `has_one_attached` pattern — already on Blog (`:image`) and User (`:avatar`); copy for `:og_image`
- Stimulus controllers — `tiptap_editor_controller.js` shows add/remove row pattern for FAQ; tag chip needs new controller
- `json_escape(schema.to_json)` — established pattern in `application_helper.rb` for all JSON-LD

### Established Patterns
- All JSON-LD via server-side Rails helpers, no client-side schema generation
- `content_for :structured_data` block in `blogs/show.html.erb` — FAQ schema goes here alongside article schema
- Metadata grid: `<div class="grid grid-cols-1 md:grid-cols-2 gap-6">` in `_form.html.erb` — new fields slot in here
- Helper pattern: `@page_var || fallback` in `application_helper.rb`

### Integration Points
- `app/views/layouts/application.html.erb` line 35 — add `<meta name="keywords">` after robots tag, conditional on `page_keywords`
- `app/controllers/blogs_controller.rb` show action — update `@page_og_image` and `@canonical_url` assignments
- `app/views/blogs/show.html.erb` `content_for :structured_data` — add `render_faq_schema(@blog)` call
- `app/helpers/application_helper.rb` — add `render_faq_schema`, `page_keywords` helpers

</code_context>

<specifics>
## Specific Ideas

- FAQ section collapsible — a `<details>`/`<summary>` element or Stimulus toggle, not a modal
- Keywords stored as jsonb array (not comma string) — chip UI serializes array to hidden field before form submit
- OG image dimensions not constrained — admin responsible; no server-side resize required (consistent with cover photo)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 3-SEO Fields & FAQ Schema*
*Context gathered: 2026-05-22*
