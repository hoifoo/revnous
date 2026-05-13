---
phase: 01-editor-foundation
reviewed: 2026-05-13T12:00:00Z
depth: standard
files_reviewed: 14
files_reviewed_list:
  - app/assets/stylesheets/application.tailwind.css
  - app/controllers/admin/blogs_controller.rb
  - app/helpers/application_helper.rb
  - app/javascript/application.js
  - app/javascript/controllers/index.js
  - app/javascript/controllers/tiptap_editor_controller.js
  - app/models/blog.rb
  - app/views/admin/blogs/_form.html.erb
  - app/views/blogs/show.html.erb
  - db/migrate/20260513121220_add_body_to_blogs.rb
  - db/schema.rb
  - lib/tasks/blogs.rake
  - package.json
  - spec/factories/blogs.rb
findings:
  critical: 4
  warning: 5
  info: 3
  total: 12
status: issues_found
---

# Phase 01: Code Review Report

**Reviewed:** 2026-05-13T12:00:00Z
**Depth:** standard
**Files Reviewed:** 14
**Status:** issues_found

## Summary

This phase delivers the Trix-to-Tiptap editor migration, a new plain-text `body` column, an ActionText migration rake task, and supporting model/controller/view changes. The scope is well-defined and largely correct, but four blockers must be fixed before shipping: two crash vectors in public-facing views, one undeclared npm package that will cause build failures in clean environments, and an XSS path in the link-insertion prompt. Five additional warnings cover data integrity gaps in the sanitizer whitelist, an unguarded nil in the related-blogs query, a missing slug uniqueness guard on update, duplicate teardown logic, and the `raw` output of body content on the show page. Three informational items are also noted.

---

## Critical Issues

### CR-01: `published_at.strftime` crashes on draft posts — public show view

**File:** `app/views/blogs/show.html.erb:30` and `app/views/blogs/show.html.erb:113`
**Issue:** `@blog.published_at.strftime(...)` (line 30) and `related_blog.published_at.strftime(...)` (line 113) are called without a nil guard. The `published_at` column has no `NOT NULL` constraint (confirmed in schema.rb line 125) and the admin form explicitly allows it to be blank for drafts ("Leave blank for draft", `_form.html.erb:34`). Any blog with `published_at: nil` that is directly accessed via its slug, or appears in a related-blogs list, will raise `NoMethodError: undefined method 'strftime' for nil` and return a 500 to the visitor.

**Fix:**
```erb
<%# line 30 — main post date %>
<%= @blog.published_at&.strftime("%B %d, %Y") %>

<%# line 113 — related post date %>
<%= related_blog.published_at&.strftime("%b %d, %Y") %>
```

---

### CR-02: XSS via unsanitized URL in link-insertion prompt

**File:** `app/javascript/controllers/tiptap_editor_controller.js:109`
**Issue:** The `setLink` method accepts any string from `window.prompt` and passes it directly to `setLink({ href: url })` without validation:
```js
this.editor.chain().focus().extendMarkRange('link').setLink({ href: url }).run()
```
Tiptap will embed the raw value into the rendered HTML as `href`. An admin who pastes a `javascript:` URI will produce `<a href="javascript:alert(1)">` in the stored body HTML. The model sanitizer in `Blog#sanitize_body` strips disallowed *tags* but its `ALLOWED_ATTRIBUTES` list includes `href` without any protocol filtering, so the stored value passes sanitization unchanged. When rendered with `raw @blog.body` on the public show page, the link is live. While the threat actor is an admin user, stored XSS accessible by any site visitor is still a blocker.

**Fix:**
```js
setLink(event) {
  event.preventDefault()
  const previousUrl = this.editor.getAttributes('link').href || ''
  const url = window.prompt("Enter URL:", previousUrl)
  if (url === null) return
  if (url === '') {
    this.editor.chain().focus().extendMarkRange('link').unsetLink().run()
  } else {
    // Block javascript: and data: URIs
    const normalized = url.trim().toLowerCase()
    if (normalized.startsWith('javascript:') || normalized.startsWith('data:')) {
      window.alert("Only http/https/mailto URLs are allowed.")
      return
    }
    this.editor.chain().focus().extendMarkRange('link').setLink({ href: url }).run()
  }
}
```
Additionally, add `'javascript:'` protocol filtering in `Blog#sanitize_body` by using Rails' `Loofah::Scrubber` or ensure `href` values are validated server-side before storage.

---

### CR-03: `@tiptap/extension-underline` and `@tiptap/extension-link` are undeclared dependencies

**File:** `package.json` (all lines) + `app/javascript/controllers/tiptap_editor_controller.js:5-6`
**Issue:** `tiptap_editor_controller.js` imports:
```js
import Underline from "@tiptap/extension-underline"
import Link from "@tiptap/extension-link"
```
Neither `@tiptap/extension-underline` nor `@tiptap/extension-link` appears in `package.json` dependencies. They happen to be installed transitively (as peer dependencies of `@tiptap/starter-kit` or `@tiptap/extensions`), but transitive dependencies are not guaranteed to remain available across `npm install` runs on a clean machine, Dockerfile build, or version bump of the parent package. On any fresh deploy that does not have the existing `node_modules`, the esbuild step will fail with a module-not-found error and the application will ship without a JS bundle.

**Fix:** Add both packages explicitly to `package.json` dependencies:
```json
"@tiptap/extension-link": "^3.23.2",
"@tiptap/extension-underline": "^3.23.2"
```

---

### CR-04: Related-blogs query calls `.count` after `.limit(3)` — wrong count, wrong fallback logic

**File:** `app/controllers/blogs_controller.rb:24-26`
**Issue:** The fallback logic reads:
```ruby
if @related_blogs.count < 3
  @related_blogs = Blog.published.where.not(id: @blog.id).limit(3)
end
```
`@related_blogs` is already `limit(3)`, so `@related_blogs.count` issues `SELECT COUNT(*) FROM blogs WHERE ... LIMIT 3`. PostgreSQL honours the `LIMIT` in a `COUNT` subquery in some configurations; in others it is stripped by ActiveRecord. More importantly, the intent — "fall back to any 3 posts if fewer than 3 share the same category" — is broken: even when there are 2 same-category posts (i.e., the intent to fall back correctly) this fires, but when 0 or 1 category match is found it also replaces the query unnecessarily, always landing on the fallback for categories with ≤ 2 matching posts. The `count` call against an already-`limit`-ed relation also costs an extra DB round-trip. The correct check is `.length` (or load the relation once):

**Fix:**
```ruby
@related_blogs = Blog.published
                     .where(category: @blog.category)
                     .where.not(id: @blog.id)
                     .limit(3)
                     .to_a

if @related_blogs.length < 3
  @related_blogs = Blog.published.where.not(id: @blog.id).limit(3).to_a
end
```

---

## Warnings

### WR-01: `sanitize_body` whitelist strips `<img>` but allows orphan attributes — data integrity loss for future images

**File:** `app/models/blog.rb:5-6`
**Issue:** `ALLOWED_TAGS` does not include `img`, `figure`, `figcaption`, or `table`. The Tiptap editor already has stub toolbar buttons for image and table (marked "coming soon" in the form), and the project plan calls for image uploads via ActiveStorage. When those features are implemented, any `<img>` tags written by the editor will be silently stripped on save without warning. The content will visually disappear from the editor after a round-trip save, which is a data-loss scenario for editors who upload images before this list is updated.

**Fix:** Proactively add image-related tags now, or add a comment explicitly documenting that the list must be extended when image support ships:
```ruby
ALLOWED_TAGS = %w[
  p br h1 h2 h3 h4 h5 h6 ul ol li strong em a blockquote code pre
  img figure figcaption
].freeze
ALLOWED_ATTRIBUTES = %w[href target rel src alt width height].freeze
```

---

### WR-02: `raw @blog.body` in public show view outputs body without secondary HTML escaping

**File:** `app/views/blogs/show.html.erb:62`
**Issue:** The body is rendered with `raw`, bypassing Rails' default HTML escaping:
```erb
<%= raw @blog.body %>
```
The model's `sanitize_body` callback is the sole XSS defence. If the sanitizer is ever bypassed (direct DB write, Rails console, seed data, the migration rake task which uses `update_column` and skips callbacks), the stored HTML renders unescaped to all visitors. The rake task in `lib/tasks/blogs.rake` already uses `update_column` which skips the `before_save` callback entirely, meaning migrated content is *never* run through `sanitize_body`.

**Fix:** Replace `raw` with Rails' `sanitize` helper so that even content written outside the model callback is safe at the point of rendering:
```erb
<div class="prose prose-lg max-w-none mb-16">
  <%= sanitize @blog.body, tags: Blog::ALLOWED_TAGS, attributes: Blog::ALLOWED_ATTRIBUTES %>
</div>
```

---

### WR-03: Slug is permitted in `blog_params` on update — allows arbitrary slug rewrites, breaking existing URLs

**File:** `app/controllers/admin/blogs_controller.rb:44-51`
**Issue:** `:slug` is in the permitted params list for both create and update actions (a single `blog_params` method is used for both). On update, submitting a new slug rewrites it without checking if it is already taken by another post, and without any redirect or canonical redirect for the old URL. The model validates `uniqueness: true` on slug (which will produce a validation error on collision), but changing a published post's slug silently breaks all inbound links, bookmarks, and Google-indexed URLs.

**Fix:** Remove `:slug` from `blog_params` for the update path by splitting into separate param methods, or add a warning to the form:
```ruby
def blog_params
  permitted = %i[title author published_at category excerpt body
                 featured featured_on_home image meta_title meta_description]
  permitted << :slug if action_name == 'create'
  params.require(:blog).permit(*permitted, product_ids: [])
end
```

---

### WR-04: `disconnect` and `teardown` are identical — one will silently go unexercised

**File:** `app/javascript/controllers/tiptap_editor_controller.js:42-54`
**Issue:** `disconnect()` (lines 42-47) and `teardown()` (lines 49-54) contain identical code:
```js
disconnect() {
  if (this.editor) { this.editor.destroy(); this.editor = null }
}
teardown() {
  if (this.editor) { this.editor.destroy(); this.editor = null }
}
```
`disconnect` is the standard Stimulus lifecycle hook called when the element leaves the DOM. `teardown` is the custom hook called from `application.js` on `turbo:before-cache`. If both run in sequence (Turbo cache then DOM removal), `editor.destroy()` is called twice — the second call on `null` is guarded, but any future additions to `teardown` will need to be duplicated or the pattern breaks.

**Fix:** Have `teardown` delegate to `disconnect`:
```js
teardown() {
  this.disconnect()
}
```

---

### WR-05: Migration rake task uses `update_column` — bypasses `sanitize_body` callback

**File:** `lib/tasks/blogs.rake:35`
**Issue:** 
```ruby
blog.update_column(:body, clean_html)
```
`update_column` bypasses all ActiveRecord callbacks including `before_save :sanitize_body`. The migrated HTML is Nokogiri-cleaned to remove `<action-text-attachment>` elements, but it is **not** run through `Rails::Html::SafeListSanitizer`. Any other disallowed tags present in legacy ActionText content (e.g., `<div>`, `<span>`, `<script>`, `<iframe>`) will be stored raw and will be output via `raw @blog.body` on the public page.

**Fix:** Use `update_columns` only for performance-critical batch operations where callbacks are intentionally skipped. Either call `blog.update!(body: clean_html)` so `sanitize_body` runs, or explicitly sanitize inline before the update:
```ruby
sanitizer = Rails::Html::SafeListSanitizer.new
sanitized = sanitizer.sanitize(clean_html, tags: Blog::ALLOWED_TAGS, attributes: Blog::ALLOWED_ATTRIBUTES)
blog.update_column(:body, sanitized)
```

---

## Info

### IN-01: `HelloController` is dead code registered in `index.js`

**File:** `app/javascript/controllers/index.js:7-8`
**Issue:** `HelloController` is imported and registered but there is no `hello_controller.js` usage in any template reviewed. It appears to be a Rails generator scaffold artifact that was never removed.
**Fix:** Remove the import and registration, and delete `hello_controller.js` if it is not used elsewhere.

---

### IN-02: `article.cover_photo_url` in `render_article_schema` may return `nil`

**File:** `app/helpers/application_helper.rb:71`
**Issue:** `article.cover_photo_url` can return `nil` (the method rescues and returns `nil` on error, and returns `nil` when no image is attached). The JSON-LD schema will include `"image": null`, which is technically valid JSON but invalid for Google's Article structured data validator (the `image` field must be a URL string when present).
**Fix:** Conditionally include the image field:
```ruby
schema["image"] = article.cover_photo_url if article.cover_photo_url.present?
```

---

### IN-03: `build` and `build:dev` scripts in `package.json` are identical

**File:** `package.json:8-9`
**Issue:** Both `build` and `build:dev` produce the same minified, tree-shaken output. There is no distinction between development and production builds — `build:dev` does not include source maps that are easier to use in development (both include `--sourcemap` but also `--minify`).
**Fix:** Remove `--minify` from `build:dev` so that development builds produce readable output:
```json
"build:dev": "esbuild app/javascript/*.* --bundle --sourcemap --format=esm --outdir=app/assets/builds --target=es2020"
```

---

_Reviewed: 2026-05-13T12:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
