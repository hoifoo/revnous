---
phase: 02-rich-content-author-profiles
reviewed: 2026-05-22T00:00:00Z
depth: standard
files_reviewed: 26
files_reviewed_list:
  - app/assets/stylesheets/application.tailwind.css
  - app/controllers/admin/blogs_controller.rb
  - app/controllers/admin/users_controller.rb
  - app/helpers/application_helper.rb
  - app/javascript/controllers/tiptap_editor_controller.js
  - app/models/blog.rb
  - app/models/user.rb
  - app/views/admin/blogs/_form.html.erb
  - app/views/admin/users/_form.html.erb
  - app/views/admin/users/edit.html.erb
  - app/views/admin/users/index.html.erb
  - app/views/admin/users/new.html.erb
  - app/views/blogs/_author_card.html.erb
  - app/views/blogs/show.html.erb
  - config/routes.rb
  - db/migrate/20260519201530_add_spacing_to_blogs.rb
  - db/migrate/20260519203520_add_author_profile_to_users.rb
  - db/migrate/20260519210037_add_author_id_to_blogs.rb
  - db/schema.rb
  - package.json
  - spec/factories/blogs.rb
  - spec/factories/users.rb
  - spec/helpers/application_helper_spec.rb
  - spec/models/blog_spec.rb
  - spec/requests/admin/blogs_spec.rb
  - spec/requests/admin/users_spec.rb
findings:
  critical: 5
  warning: 6
  info: 4
  total: 15
status: issues_found
---

# Phase 02: Code Review Report

**Reviewed:** 2026-05-22T00:00:00Z
**Depth:** standard
**Files Reviewed:** 26
**Status:** issues_found

## Summary

This phase delivers Tiptap editor integration, author profile fields on the User model, and a linked `author_id` foreign key on blogs. The overall structure is sound but several issues require attention before shipping. The most serious are: a double-assignment data-loss bug in the blogs controller that silently corrupts the `author` text column on every create/update, an XSS vector where unsanitized user-controlled content is interpolated directly into share-link URLs in the blog show view, `.html_safe` called on JSON output after `json_escape` (double escape context produces raw HTML sink), a self-XSS path via `showInlineError` that inserts an unescaped error message string as raw HTML, and a privilege-escalation risk where any admin can promote another user (including themselves) to admin via the unrestricted `:admin` field in `user_params`. Several warnings around missing N+1 guards, an unvalidated `spacing` enum, an unsafe `URI::DEFAULT_PARSER` regex for URL validation, and image upload MIME-type bypass are also documented.

---

## Critical Issues

### CR-01: Double-assignment of `author` column silently drops or double-writes data in blogs controller

**File:** `app/controllers/admin/blogs_controller.rb:14` and `:27`

**Issue:** In `create`, `blog_params` already permits `:author` (line 47), so `params.require(:blog).permit(...)` populates `@blog[:author]`. The very next line then re-assigns `@blog[:author]` with the `params.dig` value. If `params.dig(:blog, :author)` returns `nil` (e.g., the field was omitted), `.presence` returns `nil`, and the attribute that was just set by `blog_params` is overwritten with `nil`. The same double-write occurs in `update`. The net effect is that the `author` text field is always set from the manual dig call, bypassing the permitted-params pipeline, and any value already set via `blog_params` is discarded.

**Fix:** Remove `:author` from `blog_params`, keeping the explicit assignment as the single source of truth, OR remove the explicit assignment and rely solely on `blog_params`. The clean fix:

```ruby
# blog_params: remove :author from the permitted list
def blog_params
  permitted = %i[title author_id published_at category
                 excerpt body featured featured_on_home image
                 meta_title meta_description spacing]
  permitted << :slug if action_name == 'create'
  params.require(:blog).permit(*permitted, product_ids: [])
end

# In create/update: keep the explicit dig as the only write:
def create
  @blog = Blog.new(blog_params)
  @blog[:author] = params.dig(:blog, :author).presence
  ...
end
```

The `:author` attribute must not appear in both the `permit` list and the manual assignment simultaneously.

---

### CR-02: XSS via unescaped interpolation into share-link `href` attributes

**File:** `app/views/blogs/show.html.erb:71–79`

**Issue:** The Twitter, LinkedIn, and Facebook share links are constructed by interpolating `request.original_url` and `@blog.title` directly into an `href` string in plain ERB:

```erb
<a href="https://twitter.com/intent/tweet?url=<%= request.original_url %>&text=<%= @blog.title %>"
```

ERB's `<%= %>` HTML-encodes the value for HTML attribute context, which handles the injection into the HTML attribute. However `request.original_url` can contain characters that break URL structure (e.g. `&`, `#`, spaces, or a crafted path containing `%22`) which will corrupt the URL or allow parameter injection into the share service's query string. More critically, `@blog.title` can contain `&` and `=` which will break the `text=` parameter boundary. Both values must be URL-encoded before interpolation.

**Fix:**
```erb
<a href="https://twitter.com/intent/tweet?url=<%= CGI.escape(request.original_url) %>&text=<%= CGI.escape(@blog.title) %>"
   target="_blank" ...>
```
Apply the same `CGI.escape` to all three share links.

---

### CR-03: `html_safe` called after `json_escape` in `render_article_schema` creates double-escape inconsistency and unsafe HTML sink

**File:** `app/helpers/application_helper.rb:84`

**Issue:** `render_article_schema` calls `json_escape(schema.to_json).html_safe`, while every other `render_*_schema` method in the same file calls `json_escape(schema.to_json)` without `.html_safe`. Calling `.html_safe` on the string marks it as trusted HTML, causing `content_tag` to skip further escaping — but the string has only been JSON-escaped, not HTML-attribute-escaped. The `json_escape` helper escapes `</` sequences specifically to prevent script-tag injection inside `<script>` blocks; it does **not** produce an HTML-safe string for general attribute contexts. The call to `.html_safe` is incorrect and inconsistent with all other schema helpers. If Rails ever changes how `content_tag` treats its content argument this becomes a direct XSS path. It should be removed.

**Fix:**
```ruby
def render_article_schema(article)
  # ... build schema hash ...
  content_tag :script, json_escape(schema.to_json), type: "application/ld+json"
end
```
Remove `.html_safe` — match the pattern used in `render_organization_schema`, `render_product_schema`, and `render_breadcrumbs_schema`.

---

### CR-04: Self-XSS in `showInlineError` via unescaped HTML interpolation

**File:** `app/javascript/controllers/tiptap_editor_controller.js:252`

**Issue:** `showInlineError` builds an HTML string by directly interpolating the `message` parameter:

```js
const errorHtml = `<p class="text-sm text-red-600">${message}</p>`
this.editor.commands.insertContent(errorHtml)
```

The `message` value is currently only the hardcoded string `'Only image files can be dropped here.'`, so this is not presently exploitable from external input. However, the pattern is dangerous: if `message` ever originates from user-controlled input (e.g., a server error response, file name, or future caller), it will be injected as raw HTML into the document. The method establishes an unsafe pattern that is likely to be copy-pasted for future error messages.

**Fix:**
```js
showInlineError(message) {
  const p = document.createElement('p')
  p.className = 'text-sm text-red-600'
  p.textContent = message   // textContent never parses HTML
  // insert via ProseMirror if possible, otherwise append to editorTarget
  this.editorTarget.appendChild(p)
  setTimeout(() => p.remove(), 4000)
}
```

---

### CR-05: Unrestricted admin privilege escalation — any admin can grant admin to any user

**File:** `app/controllers/admin/users_controller.rb:51–54`

**Issue:** `:admin` is included in the permitted params for both `create` and `update`. This means any authenticated admin can:
1. Promote any non-admin user to admin via `PATCH /admin/users/:id`.
2. Set their own admin flag during profile updates (the `set_user` lookup does not exclude the current user).
3. Create new users with admin privileges directly.

There is no audit trail, no confirmation step, and no check that prevents a lower-trust admin from creating additional admins. The project has an audit log table (`audit_logs`) and an invitation system; admin promotion should go through a deliberate, auditable path — not a checkbox on the shared user form.

**Fix (minimum):** Remove `:admin` from `user_params`. Add a dedicated action or separate strong-params method for role changes that requires an additional confirmation or is restricted to a superadmin role:

```ruby
def user_params
  params.require(:user).permit(
    :first_name, :last_name, :email, :password, :password_confirmation,
    :bio, :job_title, :linkedin_url, :twitter_handle, :avatar
    # :admin intentionally excluded — use a dedicated promote/demote action
  )
end
```

---

## Warnings

### WR-01: N+1 query — `User.order(:first_name)` called directly in the blog form view

**File:** `app/views/admin/blogs/_form.html.erb:29`

**Issue:** `User.order(:first_name)` is called inline in the view inside `form.collection_select`. Every render of the blog form (new and edit) issues a fresh `SELECT * FROM users ORDER BY first_name` query. This is a hidden query in the view layer with no caching, no scope, and no controller assignment. For admin-only forms this is a low-severity availability issue today, but it will silently include all users (including non-admin users) and grows with the user table. It also violates the Rails convention of keeping database queries out of views.

**Fix:** Assign the collection in the controller actions and reference it in the view:
```ruby
# blogs_controller.rb - add to new, edit (via before_action or inline)
def set_author_options
  @author_options = User.order(:first_name, :last_name)
end
```
```erb
<%# _form.html.erb %>
<%= form.collection_select :author_id, @author_options, :id, :full_name, ... %>
```

---

### WR-02: `spacing` column has no model-level validation — arbitrary strings accepted

**File:** `app/models/blog.rb` (missing validation), `db/migrate/20260519201530_add_spacing_to_blogs.rb:3`

**Issue:** The `spacing` column is constrained to `default: "normal", null: false` at the database level, but the Blog model has no `validates :spacing, inclusion: { in: %w[normal relaxed] }` guard. The blog form only presents two choices, but a direct API/curl call can set `spacing` to any arbitrary string (e.g., `"<script>alert(1)</script>`). The view uses the value in a CSS class interpolation:

```erb
class="prose prose-lg max-w-none mb-16 <%= 'prose-paragraph-relaxed' if @blog.spacing == 'relaxed' %>"
```

This specific interpolation is safe because it only adds a class conditionally; however the lack of validation means unexpected values accumulate silently, and any future template that uses `@blog.spacing` directly in a CSS value or attribute would be immediately unsafe.

**Fix:**
```ruby
# app/models/blog.rb
SPACINGS = %w[normal relaxed].freeze
validates :spacing, inclusion: { in: SPACINGS }
```

---

### WR-03: `URI::DEFAULT_PARSER.make_regexp` is not a reliable LinkedIn URL validator

**File:** `app/models/user.rb:12–16`

**Issue:** The `linkedin_url` validation uses `URI::DEFAULT_PARSER.make_regexp(%w[http https])`. This regex accepts any syntactically valid HTTP/HTTPS URL — it does not restrict to `linkedin.com`, does not reject `http://evil.com`, and does not enforce HTTPS-only. While the field is labelled "LinkedIn URL", a user can save `http://attacker.com` and it will pass validation. The `target="_blank"` link in the author card will then open an attacker-controlled URL:

```erb
<%= link_to @blog.author.linkedin_url, target: "_blank", rel: "noopener noreferrer" %>
```

The `rel="noopener noreferrer"` reduces the window-opener risk, but it does not prevent the user from being sent to a phishing page that looks like LinkedIn.

**Fix:**
```ruby
validates :linkedin_url, format: {
  with: /\Ahttps:\/\/(www\.)?linkedin\.com\/.+/i,
  allow_blank: true,
  message: "must be a LinkedIn URL (https://linkedin.com/...)"
}
```

---

### WR-04: Image MIME type check is bypassable — only checks `file.type`, not file magic bytes

**File:** `app/javascript/controllers/tiptap_editor_controller.js:212`

**Issue:** The upload guard `file.type.startsWith('image/')` checks the browser-provided MIME type from the `DataTransfer` API. This value is set by the operating system / browser based on the file extension — it is **not** read from the file's actual bytes. An attacker can rename `exploit.html` to `exploit.png`, drag it into the editor, and the client-side check passes. The file then gets uploaded to ActiveStorage with a spoofed content type. Although ActiveStorage validates content type on the server when image transformations are requested, the raw blob is still stored and a signed URL is inserted into the blog body HTML. If the blob is served back with `Content-Type: text/html`, it could execute JavaScript in the reader's browser.

**Fix (server-side guard is required):** Add an ActiveStorage content type validation on the Blog model or configure a server-side MIME check in the direct upload pipeline. As a defense-in-depth measure on the client side, check against an explicit allow-list rather than a prefix:

```js
const ALLOWED_IMAGE_TYPES = new Set(['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/svg+xml'])
if (!ALLOWED_IMAGE_TYPES.has(file.type)) {
  this.showInlineError('Only JPEG, PNG, GIF, WebP, or SVG images are accepted.')
  return
}
```

---

### WR-05: `author_schema_node` checks `article.author.is_a?(User)` but `blog.author` is already typed as a User association — the guard is misleading and fragile

**File:** `app/helpers/application_helper.rb:133`

**Issue:** The helper checks `article.respond_to?(:author) && article.author.is_a?(User)`. Since `Blog#author` is declared as `belongs_to :author, class_name: "User", optional: true`, calling `article.author` always returns either a `User` instance or `nil`. The `is_a?(User)` check therefore never fires when `author` is a plain string (the old legacy `author` column is a separate raw attribute, accessible only via `article[:author]`). The logic in the view (`blogs/show.html.erb:32`) checks `@blog.author.nil? && @blog[:author].present?` to fall back to the legacy string, but `author_schema_node` has no equivalent fallback — it silently emits an Organization node even when a legacy `author` text is present. This means blogs with a legacy `author` string but no `author_id` produce an incorrect `Organization` schema node instead of a minimal `Person` node.

**Fix:**
```ruby
def author_schema_node(article)
  if article.respond_to?(:author) && article.author.is_a?(User)
    person = { "@type": "Person", "name": article.author.full_name }
    person["url"] = article.author.linkedin_url if article.author.linkedin_url.present?
    person["sameAs"] = ["https://twitter.com/#{article.author.twitter_handle}"] if article.author.twitter_handle.present?
    person
  elsif article.respond_to?(:[]) && article[:author].present?
    # Legacy plain-text author byline
    { "@type": "Person", "name": article[:author] }
  else
    { "@type": "Organization", "name": "Revnous" }
  end
end
```

---

### WR-06: Deleting a user does not protect against deleting the currently signed-in admin (self-deletion)

**File:** `app/controllers/admin/users_controller.rb:39–41`

**Issue:** The `destroy` action calls `@user.destroy` with no guard against `@user == current_user`. An admin can delete their own account. If they are the last admin, the application has no admin accounts at all and admin access is locked out until a new admin is manually seeded via the Rails console. Devise does not automatically prevent this, and the `has_many :authored_blogs, dependent: :nullify` means blogs are silently de-authored without warning.

**Fix:**
```ruby
def destroy
  if @user == current_user
    redirect_to admin_users_path, alert: "You cannot delete your own account."
    return
  end
  @user.destroy
  redirect_to admin_users_path, notice: "User was successfully deleted."
end
```

---

## Info

### IN-01: `teardown` method in Stimulus controller is a no-op duplicate of `disconnect`

**File:** `app/javascript/controllers/tiptap_editor_controller.js:93–95`

**Issue:** Stimulus calls `disconnect()` automatically when a controller is removed from the DOM. A `teardown()` method is not part of the Stimulus lifecycle; it will never be called by the framework. The method body is just `this.disconnect()`, meaning any consumer who manually calls `teardown()` would disconnect the editor twice (the second call on an already-destroyed editor would be a no-op only because of the `if (this.editor)` guard).

**Fix:** Remove `teardown()`. If a manual teardown hook is needed for testing, document the intent in a comment.

---

### IN-02: Blog form renders slug field for both new and edit, but controller only permits slug on create

**File:** `app/views/admin/blogs/_form.html.erb:70–73`, `app/controllers/admin/blogs_controller.rb:50`

**Issue:** The slug `text_field` is rendered unconditionally in the shared `_form` partial. On edit, the controller strips `:slug` from permitted params, so any slug the admin types into the edit form will be silently ignored. The UI gives no indication that the field is read-only on edit, which will confuse operators who expect to be able to correct a slug.

**Fix:** Either conditionally render the slug field only when `@blog.new_record?`, or render it as read-only with explanatory text on edit:
```erb
<% if @blog.new_record? %>
  <%= form.text_field :slug, ... %>
<% else %>
  <p class="text-sm font-mono bg-gray-50 px-3 py-2 border border-gray-200 rounded"><%= @blog.slug %></p>
  <p class="text-sm text-gray-500 mt-1">Slug cannot be changed after creation</p>
<% end %>
```

---

### IN-03: `cover_photo_url` fallback in Blog model produces a relative path, not an absolute URL

**File:** `app/models/blog.rb:34`

**Issue:** The comment says "Fallback for console/tests" but the fallback calls `rails_blob_path(image, only_path: false)`. `rails_blob_path` always returns a relative path regardless of `only_path:` — that option is ignored on path helpers. `rails_blob_url` should be used instead. When `render_article_schema` uses `article.cover_photo_url` as the schema `"image"` value, a relative path is technically invalid for JSON-LD (the spec requires an absolute URL), and schema validators will flag it.

**Fix:**
```ruby
# Fallback for console/tests
Rails.application.routes.url_helpers.rails_blob_url(image, only_path: false, host: "revnous.com")
```
Or better: ensure `default_url_options[:host]` is always set (even in test/console) rather than branching.

---

### IN-04: Test coverage gap — no test for the `body` update path (Tiptap content persistence)

**File:** `spec/requests/admin/blogs_spec.rb`

**Issue:** The request spec covers `meta_title`, `meta_description`, `spacing`, and `author_id` updates, but there is no test that verifies the `body` field is actually saved via the hidden input and survives the `sanitize_body` callback. Given that the body is the primary output of the Tiptap editor and the entire reason the migration from Trix was done, the absence of an integration test for body persistence is a meaningful coverage gap.

**Fix:** Add a test case:
```ruby
it "saves sanitized body content" do
  patch admin_blog_path(blog), params: {
    blog: { body: "<p>Hello <strong>world</strong></p>" }
  }
  blog.reload
  expect(blog.body).to eq("<p>Hello <strong>world</strong></p>")
end
```

---

_Reviewed: 2026-05-22T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
