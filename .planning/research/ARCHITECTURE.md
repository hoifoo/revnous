# Architecture: ActionText → Tiptap Migration

**Domain:** Rails 8 blog CMS, editor-to-storage-to-rendering pipeline
**Researched:** 2026-05-13
**Confidence:** HIGH — based on direct codebase inspection + established Rails/Tiptap patterns

---

## 1. Current State (Baseline)

### What exists today

- `blogs` table has no `body` column — content lives in `action_text_rich_texts` (polymorphic, `record_type = 'Blog'`, `name = 'content'`)
- `Blog` model: `has_rich_text :content` + `validates :title, :content, presence: true`
- Form: `form.rich_text_area :content` — renders the Trix editor
- Show page: `<%= @blog.content %>` inside `.prose.prose-lg` — ActionText renders its own `<action-text-attachment>` elements via a built-in renderer
- `application.js` imports both `trix` and `@rails/actiontext`
- `seo_description` uses `ActionController::Base.helpers.strip_tags(content)` — calling `.strip_tags` on an ActionText::RichText object implicitly calls `.to_s` first (returns HTML), then strips tags. This breaks the moment `content` is a plain string.
- No existing Stimulus controllers beyond `hello_controller`
- `users` table has no `bio`, `display_role`, `linkedin_url`, `twitter_url` columns; no `author_id` FK on `blogs`

---

## 2. Migration Strategy: ActionText Content → Plain HTML Column

### Step 1 — Add the new column before touching the model

```ruby
# Migration: add_body_to_blogs
add_column :blogs, :body, :text
add_column :blogs, :author_id, :bigint
add_foreign_key :blogs, :users, column: :author_id

add_column :blogs, :keywords, :string
add_column :blogs, :canonical_url, :string
add_column :blogs, :faq_schema, :text   # JSON array of {q, a} pairs

# og_image stored via ActiveStorage — no column needed, just has_one_attached
```

### Step 2 — Data migration (separate migration or rake task)

ActionText stores HTML in `action_text_rich_texts.body`. Extract and sanitize it in the same migration:

```ruby
# Migration: migrate_actiontext_to_body
class MigrateActiontextToBody < ActiveRecord::Migration[8.0]
  def up
    Blog.find_each do |blog|
      rich_text = ActionText::RichText.find_by(
        record_type: 'Blog',
        record_id: blog.id,
        name: 'content'
      )
      next unless rich_text

      # ActionText body is already sanitized HTML; extract inner HTML
      raw_html = rich_text.body.to_html
      # Sanitize to strip ActionText-specific custom elements
      clean_html = ActionController::Base.helpers.sanitize(
        raw_html,
        tags: %w[p br strong em u s h1 h2 h3 h4 h5 h6
                 ul ol li blockquote a img table thead tbody tr th td
                 figure figcaption],
        attributes: %w[href src alt class target rel]
      )
      blog.update_column(:body, clean_html)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
```

Key points:
- `rich_text.body.to_html` returns sanitized HTML that ActionText already processed. `<action-text-attachment>` elements for inline images will be present — the sanitizer strips them since they are not in the allowed tags list. This is acceptable: inline images in existing ActionText content are rare in this app (no uploads were wired up).
- Run this migration against a database backup first.
- After confirming all `body` values are populated, the `has_rich_text :content` line and the `content` validation can be removed in a follow-up model change.
- Do NOT drop `action_text_rich_texts` rows — leave them as a rollback safety net until the release is stable.

### Step 3 — Remove ActionText from Blog model

```ruby
# After migration confirms body is populated:
# - Remove: has_rich_text :content
# - Remove: validates :title, :content, presence: true
# - Add:    validates :title, :body, presence: true
# - Update: seo_description to use strip_tags(body)
```

### Step 4 — Remove Trix/ActionText from JS bundle (after model is clean)

```js
// application.js — remove these two lines:
// import "trix"
// import "@rails/actiontext"
```

Removing them cuts ~150 KB from the bundle. Do this last, after confirming the admin form no longer uses `rich_text_area`.

---

## 3. Database Changes

### blogs table additions

| Column | Type | Purpose |
|--------|------|---------|
| `body` | `text` | Tiptap HTML output, sanitized server-side |
| `author_id` | `bigint` (FK → users) | Linked author profile |
| `keywords` | `string` | Comma-separated keywords for meta keywords tag |
| `canonical_url` | `string` | Override canonical; null = use request URL |
| `faq_schema` | `text` | JSON: `[{"q": "...", "a": "..."}, ...]` |

OG image uses ActiveStorage: `has_one_attached :og_image` on Blog. No column needed.

### users table additions

| Column | Type | Purpose |
|--------|------|---------|
| `display_name` | `string` | Public author name (may differ from first/last) |
| `bio` | `text` | Author bio for profile card |
| `author_role` | `string` | Job title / role shown on posts |
| `linkedin_url` | `string` | LinkedIn profile URL |
| `twitter_url` | `string` | Twitter/X profile URL |

Avatar uses ActiveStorage: `has_one_attached :avatar` on User. No column needed.

Use `author_role` not `role` to avoid collision with the existing `roles` text column (JSON array of membership roles used by the other parts of the system).

### Model associations

```ruby
# app/models/blog.rb
belongs_to :author, class_name: 'User', foreign_key: 'author_id', optional: true
has_one_attached :og_image

# app/models/user.rb
has_many :blogs, foreign_key: 'author_id'
has_one_attached :avatar
```

`optional: true` on `belongs_to :author` — existing blogs have no author_id, a hard presence validation would break all existing records on save.

---

## 4. Stimulus Controller Design

### Single controller, single responsibility

Use **one** `editor_controller.js`. Do not split into multiple controllers. The editor, upload, and form-sync responsibilities are tightly coupled and there is only one editor surface in this app.

```
data-controller="editor"
data-editor-content-value="<%= @blog.body.to_s %>"   ← hydration value
```

The Stimulus Values API (not a plain data attribute) is the right mechanism for hydration: it triggers `contentValueChanged()` which can set initial editor state, and it is type-safe.

### Controller lifecycle

```
connect()
  → instantiate Tiptap Editor on this.editorTarget
  → call this.editor.commands.setContent(this.contentValue) if contentValue present
  → attach 'submit' listener on closest form

disconnect()
  → call this.editor.destroy()

submit handler (before form submit fires)
  → this.bodyTarget.value = this.editor.getHTML()
  → allow submit to proceed
```

### Targets

```js
static targets = ["editor", "body"]  // editor = div mount point, body = hidden field
static values  = { content: String }
```

### Form HTML structure

```erb
<div data-controller="editor"
     data-editor-content-value="<%= @blog.body.to_s.gsub('"', '&quot;') %>">

  <%# Hidden field that gets populated before submit %>
  <%= form.hidden_field :body, data: { editor_target: "body" } %>

  <%# Toolbar rendered by ERB or by the controller dynamically %>
  <div id="editor-toolbar">...</div>

  <%# Tiptap mount point %>
  <div data-editor-target="editor"
       class="prose prose-lg min-h-[400px] border rounded-md p-4 focus:outline-none">
  </div>
</div>
```

The hidden field carries `:body` through the standard Rails form params. No custom AJAX submission needed.

### Turbo compatibility

Stimulus controllers must handle Turbo Drive page transitions. `disconnect()` destroying the editor is the correct cleanup hook. Do NOT store the editor instance on `window` — it leaks across navigations.

### Hydration on edit

```js
contentValueChanged(value) {
  if (this.editor && value) {
    this.editor.commands.setContent(value, false) // false = do not emit update
  }
}
```

The `false` second argument prevents the editor from firing its `onUpdate` handler during initial hydration, which would incorrectly mark the form dirty.

---

## 5. Image Upload Flow

### End-to-end flow

```
User drops/pastes image into Tiptap editor
  ↓
editor_controller.js intercepts via Tiptap's Image extension drop/paste handler
  ↓
JS creates a File object from the event
  ↓
JS calls Rails ActiveStorage DirectUpload API:
  new DirectUpload(file, '/rails/active_storage/direct_uploads')
  ↓
DirectUpload POSTs to /rails/active_storage/direct_uploads → returns blob JSON
  { signed_id, filename, content_type, ... }
  ↓
DirectUpload uploads file bytes to storage (local disk or S3) via PUT
  ↓
On success: insert image node into Tiptap:
  editor.commands.setImage({ src: `/rails/active_storage/blobs/redirect/${blob.signed_id}/${blob.filename}` })
  ↓
Tiptap HTML stored in body column contains:
  <img src="/rails/active_storage/blobs/redirect/SIGNED_ID/filename.jpg" alt="">
```

### Why `/blobs/redirect/` not `/blobs/proxy/`

`redirect` URLs are shorter and work with CDN setups. They issue a redirect to the actual storage URL. `proxy` streams bytes through Rails — do not use proxy for user-generated images in a production setup.

### URL stability concern (CRITICAL)

`signed_id` in blob redirect URLs expires or rotates with `secret_key_base` rotation. If you ever rotate secrets or re-sign blobs, stored `<img src="...signed_id...">` in the `body` column will break.

**Prevention:** Store the blob's permanent `key` in the src, and build a controller action that looks up by key:

```
GET /blog_images/:key → redirects to rails_blob_url(blob)
```

This adds a layer of indirection but protects stored content from signed_id expiry. This is the same pattern ActionText uses internally via `rails_blob_representation_url`.

Alternatively: accept the risk for now and document that `secret_key_base` must not be rotated without re-signing stored blob URLs. For a small content team this is a reasonable tradeoff.

**Recommendation:** Start with direct signed_id URLs. Add the indirection layer in a follow-on phase if secret rotation becomes a concern. Annotate in code with a comment.

### Server-side sanitization

Before saving `body` in the controller, sanitize the HTML. Do NOT use `raw` with unsanitized input even from your own editor, because a compromised admin session is a real attack surface.

```ruby
# app/controllers/admin/blogs_controller.rb
ALLOWED_TAGS = %w[
  p br strong em u s del
  h1 h2 h3 h4 h5 h6
  ul ol li
  blockquote
  a img
  table thead tbody tr th td
  figure figcaption
  hr
].freeze

ALLOWED_ATTRIBUTES = %w[href src alt class target rel width height].freeze

def sanitize_body(html)
  ActionController::Base.helpers.sanitize(
    html,
    tags: ALLOWED_TAGS,
    attributes: ALLOWED_ATTRIBUTES
  )
end
```

Call this in `blog_params` or a `before_action`. Store the sanitized result.

### Tiptap packages required

```
@tiptap/core
@tiptap/starter-kit      (Document, Paragraph, Text, Bold, Italic, Strike, Code, Blockquote, HardBreak, Heading, BulletList, OrderedList, ListItem, HorizontalRule, History)
@tiptap/extension-image
@tiptap/extension-table
@tiptap/extension-table-row
@tiptap/extension-table-header
@tiptap/extension-table-cell
@tiptap/extension-link
@tiptap/extension-underline
@tiptap/extension-character-count  (optional, useful for SEO copy limits)
@rails/activestorage               (for DirectUpload)
```

`@tiptap/starter-kit` already bundles most common extensions. Import individually only the ones that are not in StarterKit to avoid duplication.

---

## 6. Rendering Pipeline

### Current: ActionText rendering

```erb
<div class="prose prose-lg max-w-none mb-16">
  <%= @blog.content %>   <%# ActionText::RichText renders via its own renderer %>
</div>
```

ActionText's `to_s` calls `render` which processes `<action-text-attachment>` elements server-side. This is irrelevant for plain HTML.

### Target: plain HTML rendering

```erb
<div class="prose prose-lg max-w-none mb-16">
  <%= sanitize @blog.body, tags: ALLOWED_TAGS, attributes: ALLOWED_ATTRIBUTES %>
</div>
```

Do NOT use `raw @blog.body`. Even though the body was sanitized on write, defense in depth means also sanitizing on read. Use the same allowlist constant to keep them in sync.

Define the allowlist as a constant on the Blog model or in a concern so controller and view share it:

```ruby
# app/models/blog.rb
BODY_ALLOWED_TAGS = %w[p br strong em u s h1 h2 h3 h4 h5 h6
                        ul ol li blockquote a img table thead
                        tbody tr th td figure figcaption hr].freeze
BODY_ALLOWED_ATTRIBUTES = %w[href src alt class target rel width height].freeze
```

Then in the view:

```erb
<%= sanitize @blog.body,
      tags: Blog::BODY_ALLOWED_TAGS,
      attributes: Blog::BODY_ALLOWED_ATTRIBUTES %>
```

### Tailwind prose compatibility

Tiptap's default HTML output is semantically standard: `<h2>`, `<p>`, `<ul>`, `<strong>`, etc. Tailwind Typography's `prose` class styles these elements directly — no custom class injection needed on the Tiptap output. The editor and show page will render identically if the editor container also carries the `prose` class.

**Editor container styling:**

```html
<div data-editor-target="editor"
     class="prose prose-lg max-w-none min-h-[400px] border rounded-md p-4">
</div>
```

This makes the WYSIWYG editing experience match the public rendering exactly.

### seo_description update

```ruby
# app/models/blog.rb
def seo_description
  meta_description.presence ||
    ActionController::Base.helpers.strip_tags(body).truncate(160)
end
```

Replace `strip_tags(content)` (which calls ActionText::RichText#to_s) with `strip_tags(body)` (plain string). The behavior is identical — strip HTML tags, truncate to 160 chars.

---

## 7. SEO Helper Updates

### render_article_schema — Person author support

```ruby
def render_article_schema(article)
  schema = {
    "@context": "https://schema.org",
    "@type": "Article",
    "headline": article.title,
    "description": article.seo_description,
    "image": article.cover_photo_url,
    "datePublished": article.published_at&.iso8601 || article.created_at.iso8601,
    "dateModified": article.updated_at.iso8601,
    "author": build_author_schema(article),
    "publisher": {
      "@type": "Organization",
      "name": "Revnous",
      "logo": { "@type": "ImageObject", "url": asset_url("logo.png") }
    }
  }

  # Canonical URL override
  schema["mainEntityOfPage"] = {
    "@type": "WebPage",
    "@id": article.canonical_url.presence || request.original_url.split("?").first
  }

  # Keywords
  schema["keywords"] = article.keywords if article.keywords.present?

  content_tag :script, schema.to_json.html_safe, type: "application/ld+json"
end

private

def build_author_schema(article)
  author = article.author  # User or nil
  if author
    schema = { "@type": "Person", "name": author.display_name.presence || "#{author.first_name} #{author.last_name}".strip }
    schema["url"] = author.linkedin_url if author.linkedin_url.present?
    schema["sameAs"] = [author.linkedin_url, author.twitter_url].compact if author.linkedin_url.present? || author.twitter_url.present?
    if author.avatar.attached?
      schema["image"] = url_for(author.avatar)
    end
    schema
  else
    { "@type": "Organization", "name": "Revnous" }
  end
end
```

Note: `article.published_at` is the correct date for `datePublished` in Article schema, not `created_at`. The current helper uses `created_at` — this is a bug that should be fixed in this migration.

### render_faq_schema — new helper

```ruby
def render_faq_schema(article)
  return unless article.faq_schema.present?

  pairs = JSON.parse(article.faq_schema) rescue []
  return if pairs.empty?

  schema = {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    "mainEntity": pairs.map do |pair|
      {
        "@type": "Question",
        "name": pair["q"],
        "acceptedAnswer": {
          "@type": "Answer",
          "text": pair["a"]
        }
      }
    end
  }

  content_tag :script, schema.to_json.html_safe, type: "application/ld+json"
end
```

Call from the show view inside `content_for :structured_data`:

```erb
<% content_for :structured_data do %>
  <%= render_article_schema(@blog) %>
  <%= render_faq_schema(@blog) %>
  <%= render_breadcrumbs_schema([...]) %>
<% end %>
```

### canonical_url helper update

The existing `canonical_url` helper in ApplicationHelper already checks `@page_og_image` first. Set `@canonical_url` in the blogs controller:

```ruby
# app/controllers/blogs_controller.rb — show action
@canonical_url = @blog.canonical_url.presence || request.original_url.split("?").first
```

### og_image override

```ruby
# app/controllers/blogs_controller.rb — show action
if @blog.og_image.attached?
  @page_og_image = url_for(@blog.og_image)
elsif @blog.image.attached?
  @page_og_image = @blog.cover_photo_url
end
```

The existing `page_og_image` helper in ApplicationHelper already reads `@page_og_image` — no helper changes needed.

---

## 8. Component Boundaries

```
┌─────────────────────────────────────────────────────────┐
│                   ADMIN FORM (ERB)                       │
│                                                         │
│  form_with model: [:admin, @blog]                       │
│    hidden_field :body  ◄──── synced by Stimulus          │
│    div[data-controller="editor"]                        │
│      div[data-editor-target="editor"]  ◄── Tiptap mounts│
│      toolbar buttons (call editor.chain()...)           │
│                                                         │
│  Other fields: author_id select, keywords text,         │
│  canonical_url text, faq_schema (dynamic Q&A rows),     │
│  og_image file, cover image file                        │
└────────────────────┬────────────────────────────────────┘
                     │ POST /admin/blogs
                     ▼
┌─────────────────────────────────────────────────────────┐
│            Admin::BlogsController                        │
│                                                         │
│  sanitize_body(params[:blog][:body])                    │
│  blog.update(sanitized_blog_params)                     │
└────────────────────┬────────────────────────────────────┘
                     │ stored in blogs.body (text column)
                     ▼
┌─────────────────────────────────────────────────────────┐
│               blogs table (PostgreSQL)                   │
│                                                         │
│  body TEXT  — sanitized HTML                            │
│  author_id BIGINT FK → users                            │
│  keywords STRING                                        │
│  canonical_url STRING                                   │
│  faq_schema TEXT (JSON)                                 │
│  + has_one_attached :og_image (active_storage)          │
└────────────────────┬────────────────────────────────────┘
                     │ read in BlogsController#show
                     ▼
┌─────────────────────────────────────────────────────────┐
│              blogs/show.html.erb                         │
│                                                         │
│  sanitize(@blog.body, tags: ..., attributes: ...)       │
│    inside .prose.prose-lg div                           │
│                                                         │
│  Author card: @blog.author (User) → avatar, bio, role  │
│  JSON-LD: render_article_schema + render_faq_schema     │
│  OG/canonical: set via @page_og_image, @canonical_url   │
└─────────────────────────────────────────────────────────┘
```

### Image upload sub-flow (within admin form)

```
editor_controller.js
  → handles Tiptap drop/paste event
  → new DirectUpload(file, '/rails/active_storage/direct_uploads')
  → on complete: editor.commands.setImage({ src: blob_redirect_url })
  → img tag written into Tiptap HTML state
  → on form submit: getHTML() synced to hidden :body field
  → body sanitized server-side (img src allowed, img alt allowed)
```

---

## 9. Migration Sequence (Phase Order)

Execute in this order to avoid broken states:

1. **DB migration** — add `body`, `author_id`, `keywords`, `canonical_url`, `faq_schema` columns; add `display_name`, `bio`, `author_role`, `linkedin_url`, `twitter_url` to users
2. **Data migration** — extract ActionText HTML into `body` column for all existing blogs
3. **Model update** — swap `has_rich_text :content` for `body` plain attribute; update validations; add associations; add `serialize :faq_schema, JSON` or parse manually
4. **Controller update** — add `sanitize_body`, permit new params, set `@canonical_url` and `@page_og_image`
5. **Form update** — replace `rich_text_area :content` with Tiptap editor scaffold; add new fields
6. **Stimulus controller** — implement `editor_controller.js` with Tiptap init, hydration, submit sync, image upload
7. **Show page update** — swap `@blog.content` for `sanitize(@blog.body, ...)`; add author card partial; update structured_data block
8. **ApplicationHelper update** — update `render_article_schema` for Person schema; add `render_faq_schema`
9. **Remove Trix/ActionText imports** from `application.js` and remove from package.json

---

## 10. Known Risks and Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Signed blob URLs break on secret rotation | Medium | Document constraint; add `/blog_images/:key` indirection later |
| Existing blogs with inline ActionText attachments lose images in migration | Low | Inspect `action_text_rich_texts` rows before migration; this app had no upload wiring so inline images don't exist |
| `faq_schema` JSON malformed on save | Low | Validate JSON in model before save; rescue JSON.parse in helper |
| `author_id` FK breaks if User is deleted | Medium | Use `optional: true`; add `on_delete: :nullify` to FK migration |
| XSS via Tiptap body if sanitize step is bypassed | High | Sanitize in controller AND in view (double defense); never use `raw` |
| Tiptap bundle size with all extensions | Low | esbuild tree-shakes; import only used extensions; StarterKit already bundles most |
| Turbo Drive cache serving stale editor state | Low | `disconnect()` destroys editor; Turbo cache serves static HTML; editor reinitializes on `connect()` |

---

## Sources

- Direct codebase inspection: `db/schema.rb`, `app/models/blog.rb`, `app/views/admin/blogs/_form.html.erb`, `app/views/blogs/show.html.erb`, `app/helpers/application_helper.rb`, `app/javascript/application.js`
- Confidence level: HIGH for Rails/ActiveStorage patterns (established Rails 7/8 conventions); HIGH for Tiptap integration pattern (Stimulus Values API, getHTML/setContent lifecycle); MEDIUM for signed_id URL stability concern (known Rails convention, not tested against this specific deployment)
