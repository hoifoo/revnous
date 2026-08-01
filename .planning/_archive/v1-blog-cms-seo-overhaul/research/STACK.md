# Technology Stack: Tiptap + Rails 8 + Stimulus + esbuild

**Project:** Blog CMS — Trix-to-Tiptap migration
**Researched:** 2026-05-13
**Overall confidence:** HIGH (Tiptap 2.x packages, Stimulus wiring, ActiveStorage pattern) / MEDIUM (exact patch versions — verify at install time)

> **Note on sources:** Web search and WebFetch were unavailable in this research session. All findings are from training knowledge through August 2025 plus codebase inspection. Tiptap 2.x has been stable since 2023; the package surface below matches official tiptap.dev documentation as of that date. Verify exact patch versions with `npm info @tiptap/<package> version` before pinning.

---

## Recommended Stack

### Core Tiptap Packages

| Package | Version (range) | Purpose | Why |
|---------|----------------|---------|-----|
| `@tiptap/core` | `^2.11` | Editor engine, extension API, commands | Required — everything else depends on it |
| `@tiptap/pm` | `^2.11` | ProseMirror peer dependency bundle | Tiptap 2.x re-exports ProseMirror under its own namespace to avoid version conflicts with esbuild |
| `@tiptap/starter-kit` | `^2.11` | Bold, Italic, Strike, Code, Blockquote, HorizontalRule, BulletList, OrderedList, ListItem, Paragraph, HardBreak, History | Single package for the "base" set — use it as a foundation, then override/add extensions |

**Why `@tiptap/pm` is required:** esbuild tree-shaking can break if ProseMirror is imported from multiple source paths. `@tiptap/pm` provides a single unified re-export of `prosemirror-state`, `prosemirror-view`, `prosemirror-model`, `prosemirror-commands`, `prosemirror-schema-list`, `prosemirror-transform`. Do **not** install raw `prosemirror-*` packages separately alongside Tiptap unless you pin them to exact matching versions.

### Extension Packages

| Package | Version | Purpose | Notes |
|---------|---------|---------|-------|
| `@tiptap/extension-heading` | `^2.11` | H1–H6 with configurable levels | `StarterKit` excludes Heading; must be added separately. Configure `levels: [1,2,3,4,5,6]` |
| `@tiptap/extension-image` | `^2.11` | `<img>` node with src/alt/title attrs | Base image support; does not handle upload — upload is wired in the Stimulus controller |
| `@tiptap/extension-link` | `^2.11` | Anchor tags with href/target/rel | Set `openOnClick: false` in admin context so clicking does not navigate |
| `@tiptap/extension-table` | `^2.11` | Table node | Required parent for TableRow/TableCell/TableHeader |
| `@tiptap/extension-table-row` | `^2.11` | `<tr>` node | Must be installed alongside Table |
| `@tiptap/extension-table-cell` | `^2.11` | `<td>` node | Must be installed alongside Table |
| `@tiptap/extension-table-header` | `^2.11` | `<th>` node | Must be installed alongside Table |
| `@tiptap/extension-text-align` | `^2.11` | Left / center / right / justify alignment | Adds `style="text-align: ..."` to block nodes |
| `@tiptap/extension-underline` | `^2.11` | `<u>` tag | Not in StarterKit; frequently expected by non-technical editors |
| `@tiptap/extension-color` | `^2.11` | Text colour via `style="color: ..."` | Optional — include if editors need colour control |
| `@tiptap/extension-text-style` | `^2.11` | Required peer for Color and other mark extensions | Color will not work without TextStyle |
| `@tiptap/extension-typography` | `^2.11` | Smart quotes, em dashes, ellipsis auto-replacement | Quality-of-life for prose writers |
| `@tiptap/extension-placeholder` | `^2.11` | CSS placeholder text in empty editor | Wired via CSS, zero runtime cost |
| `@tiptap/extension-character-count` | `^2.11` | Word / character count | Optional; useful for SEO meta length guidance |

**StarterKit already includes:** Bold, Italic, Strike, Code, CodeBlock, Blockquote, BulletList, OrderedList, ListItem, Paragraph, HardBreak, HorizontalRule, History (undo/redo).

**Do not re-register extensions already in StarterKit** — Tiptap will throw a duplicate extension error.

### Full Install Command

```bash
npm install \
  @tiptap/core@^2.11 \
  @tiptap/pm@^2.11 \
  @tiptap/starter-kit@^2.11 \
  @tiptap/extension-heading@^2.11 \
  @tiptap/extension-image@^2.11 \
  @tiptap/extension-link@^2.11 \
  @tiptap/extension-table@^2.11 \
  @tiptap/extension-table-row@^2.11 \
  @tiptap/extension-table-cell@^2.11 \
  @tiptap/extension-table-header@^2.11 \
  @tiptap/extension-text-align@^2.11 \
  @tiptap/extension-underline@^2.11 \
  @tiptap/extension-text-style@^2.11 \
  @tiptap/extension-typography@^2.11 \
  @tiptap/extension-placeholder@^2.11
```

Remove at the same time:
```bash
npm uninstall trix @rails/actiontext
```

---

## Stimulus Controller Architecture

**Confidence:** HIGH — this is a well-established pattern in the Rails community.

The controller mounts Tiptap on `connect()` and tears it down on `disconnect()`. It owns:
1. Editor instance lifecycle
2. Toolbar button wiring (via `data-action`)
3. Image upload (file picker → DirectUpload → `insertContent`)
4. Syncing HTML output to the hidden form `<textarea>`

### Target / Value Layout

```
data-controller="tiptap"
data-tiptap-upload-url-value="/rails/active_storage/direct_uploads"   ← DirectUpload endpoint
data-tiptap-blob-url-value="/rails/active_storage/blobs/:signed_id/:filename" ← blob serving URL
```

### Controller Skeleton

```javascript
// app/javascript/controllers/tiptap_controller.js
import { Controller } from "@hotwired/stimulus"
import { Editor } from "@tiptap/core"
import StarterKit from "@tiptap/starter-kit"
import Heading from "@tiptap/extension-heading"
import Image from "@tiptap/extension-image"
import Link from "@tiptap/extension-link"
import Table from "@tiptap/extension-table"
import TableRow from "@tiptap/extension-table-row"
import TableCell from "@tiptap/extension-table-cell"
import TableHeader from "@tiptap/extension-table-header"
import TextAlign from "@tiptap/extension-text-align"
import Underline from "@tiptap/extension-underline"
import TextStyle from "@tiptap/extension-text-style"
import Typography from "@tiptap/extension-typography"
import Placeholder from "@tiptap/extension-placeholder"
import { DirectUpload } from "@rails/activestorage"

export default class extends Controller {
  static targets = ["editor", "input", "toolbar"]
  static values  = {
    uploadUrl: String,   // /rails/active_storage/direct_uploads
    blobUrl:   String,   // /rails/active_storage/blobs/redirect/:signed_id/:filename
    content:   String    // pre-existing HTML for edit forms
  }

  connect() {
    this.editor = new Editor({
      element:   this.editorTarget,
      extensions: [
        StarterKit.configure({
          // Heading is added separately to control levels
          heading: false,
        }),
        Heading.configure({ levels: [1, 2, 3, 4, 5, 6] }),
        Image.configure({ inline: false, allowBase64: false }),
        Link.configure({ openOnClick: false, autolink: true }),
        Table.configure({ resizable: false }),
        TableRow,
        TableCell,
        TableHeader,
        TextAlign.configure({ types: ["heading", "paragraph"] }),
        Underline,
        TextStyle,
        Typography,
        Placeholder.configure({ placeholder: "Write your article…" }),
      ],
      content:    this.contentValue || "",
      onUpdate:  ({ editor }) => {
        // Sync HTML to hidden textarea on every change
        this.inputTarget.value = editor.getHTML()
      },
    })

    // Set initial value in case of edit form with existing content
    if (this.contentValue) {
      this.inputTarget.value = this.contentValue
    }
  }

  disconnect() {
    this.editor?.destroy()
  }

  // ── Toolbar actions (called via data-action="click->tiptap#toggleBold") ──

  toggleBold()          { this.editor.chain().focus().toggleBold().run() }
  toggleItalic()        { this.editor.chain().focus().toggleItalic().run() }
  toggleUnderline()     { this.editor.chain().focus().toggleUnderline().run() }
  toggleStrike()        { this.editor.chain().focus().toggleStrike().run() }
  toggleBulletList()    { this.editor.chain().focus().toggleBulletList().run() }
  toggleOrderedList()   { this.editor.chain().focus().toggleOrderedList().run() }
  toggleBlockquote()    { this.editor.chain().focus().toggleBlockquote().run() }
  toggleCodeBlock()     { this.editor.chain().focus().toggleCodeBlock().run() }
  setHorizontalRule()   { this.editor.chain().focus().setHorizontalRule().run() }
  undo()                { this.editor.chain().focus().undo().run() }
  redo()                { this.editor.chain().focus().redo().run() }

  setHeading(event) {
    const level = parseInt(event.params.level, 10)  // data-tiptap-level-param="2"
    this.editor.chain().focus().toggleHeading({ level }).run()
  }

  setAlignment(event) {
    const align = event.params.align  // data-tiptap-align-param="center"
    this.editor.chain().focus().setTextAlign(align).run()
  }

  insertLink() {
    const url = window.prompt("URL:")
    if (!url) return
    this.editor.chain().focus().setLink({ href: url }).run()
  }

  insertTable() {
    this.editor.chain().focus().insertTable({ rows: 3, cols: 3, withHeaderRow: true }).run()
  }

  // ── Image upload ──

  triggerImageUpload() {
    const input = document.createElement("input")
    input.type  = "file"
    input.accept = "image/*"
    input.addEventListener("change", (e) => this.#uploadImage(e.target.files[0]))
    input.click()
  }

  #uploadImage(file) {
    if (!file) return
    const upload = new DirectUpload(file, this.uploadUrlValue, this)
    upload.create((error, blob) => {
      if (error) {
        console.error("DirectUpload error:", error)
        return
      }
      // Construct the public serving URL
      const src = this.blobUrlValue
        .replace(":signed_id", blob.signed_id)
        .replace(":filename",  encodeURIComponent(blob.filename))

      this.editor.chain().focus().setImage({ src, alt: file.name }).run()
    })
  }

  // DirectUpload delegate — called during upload progress
  directUploadWillStoreFileWithXHR(xhr) {
    xhr.upload.addEventListener("progress", (event) => {
      // Optionally show a progress bar here
      const percent = Math.round((event.loaded / event.total) * 100)
      this.dispatch("uploadProgress", { detail: { percent } })
    })
  }
}
```

### Form HTML Pattern

```erb
<%# app/views/admin/blogs/_form.html.erb %>
<div data-controller="tiptap"
     data-tiptap-upload-url-value="<%= rails_direct_uploads_url %>"
     data-tiptap-blob-url-value="/rails/active_storage/blobs/redirect/:signed_id/:filename"
     data-tiptap-content-value="<%= html_escape(@blog.body.to_s) %>">

  <%# Sticky toolbar — positioned via CSS, not JS -%>
  <div data-tiptap-target="toolbar" class="tiptap-toolbar sticky top-0 z-10 ...">
    <button type="button" data-action="click->tiptap#toggleBold">B</button>
    <button type="button" data-action="click->tiptap#toggleItalic">I</button>
    <button type="button" data-action="click->tiptap#toggleUnderline">U</button>
    <button type="button"
            data-action="click->tiptap#setHeading"
            data-tiptap-level-param="2">H2</button>
    <%# … etc … %>
    <button type="button" data-action="click->tiptap#triggerImageUpload">Image</button>
  </div>

  <%# Tiptap mounts here %>
  <div data-tiptap-target="editor" class="tiptap-editor prose max-w-none ..."></div>

  <%# Hidden textarea carries the value in form submission %>
  <%= f.hidden_field :body, data: { tiptap_target: "input" } %>
</div>
```

**Why `hidden_field` not `text_area`:** The textarea does not need to be visible. The hidden field avoids any browser attempt to render the raw HTML as text, and it participates in form submission normally. Tiptap's `onUpdate` keeps it in sync.

**Why `html_escape` on `content-value`:** The `data-tiptap-content-value` attribute holds HTML, so it must be entity-escaped for safe embedding in an HTML attribute. Without this, any `"` in the content will break the attribute.

---

## ActiveStorage Direct Upload

**Confidence:** HIGH — this is the standard Rails pattern; `@rails/activestorage` ships with Rails.

### Setup

`@rails/activestorage` is already in the Rails asset pipeline (it ships with Rails and is importable from `app/javascript`). Import it in your application entry or directly in the controller:

```javascript
import { DirectUpload } from "@rails/activestorage"
```

No additional npm install is needed — `@rails/activestorage` is provided by the `activestorage` gem that ships with Rails 8.

**Confirm the import path works:** In jsbundling-rails + esbuild projects, `@rails/activestorage` resolves from the Rails-installed JS. If the import does not resolve, install the npm counterpart:

```bash
npm install @rails/activestorage
```

### DirectUpload flow

```
1. User clicks "Insert Image" → file picker opens
2. File selected → new DirectUpload(file, "/rails/active_storage/direct_uploads")
3. DirectUpload PUTs file to storage (local disk / S3 / GCS)
4. Callback receives `blob` object with `blob.signed_id` and `blob.filename`
5. Controller constructs serving URL and calls editor.setImage({ src })
6. HTML stored in body column contains a standard <img src="/rails/active_storage/blobs/..."> tag
```

### Blob Serving URL

Rails has two blob URL helpers:

| Helper | Behaviour |
|--------|-----------|
| `rails_blob_url(blob)` | Direct URL — only works in controllers/mailers where `blob` object is available |
| `/rails/active_storage/blobs/redirect/:signed_id/:filename` | Route pattern — signed, redirects to actual storage URL |
| `/rails/active_storage/blobs/proxy/:signed_id/:filename` | Proxy through Rails — slower but avoids CORS on private buckets |

For blog body images, use the **redirect** variant. Paste the route pattern into `data-tiptap-blob-url-value` and do string interpolation in JavaScript:

```javascript
const src = "/rails/active_storage/blobs/redirect/" + blob.signed_id + "/" + encodeURIComponent(blob.filename)
```

### Gotcha: Signed ID Expiry

ActiveStorage signed IDs do not expire by default (the default is `nil` = no expiry). However, if `config.active_storage.service_urls_expire_in` is set in production, blob URLs embedded in HTML will break after expiry. For public blog content, either:
- Leave expiry at `nil` (recommended for public images), or
- Use a custom attachment model and serve via a public bucket path.

---

## esbuild Bundle Considerations

**Confidence:** HIGH — verified against the existing `package.json` build script.

### Existing build script

```json
"build": "esbuild app/javascript/*.* --bundle --sourcemap --format=esm --outdir=app/assets/builds --minify --tree-shaking=true --target=es2020"
```

### What changes with Tiptap

**Tree-shaking works correctly** with Tiptap because all `@tiptap/*` packages ship as ES modules with proper `exports` fields. The `--tree-shaking=true` flag combined with `--format=esm` will eliminate unused extension code. Only import extensions you actually use.

**No esbuild plugins needed.** Tiptap does not use CSS-in-JS, does not require PostCSS transforms at bundle time, and does not import `.css` files in a way that breaks esbuild. CSS for the editor (placeholder, selected cells, etc.) is handled separately via plain CSS.

**Bundle size estimate:**
- `@tiptap/core` + `@tiptap/pm` + StarterKit ≈ 150–180 KB minified, ~50 KB gzipped
- Each additional extension ≈ 2–10 KB
- Full set above ≈ 220–260 KB minified, ~70 KB gzipped
- This is acceptable for an admin-only interface — it is not a public page

**Gotcha: `@tiptap/pm` must be installed.** Without it, ProseMirror modules resolve from multiple paths and esbuild can emit duplicate copies of the runtime, inflating bundle size or causing runtime errors. Always install `@tiptap/pm`.

**Gotcha: `format=esm` required.** The existing build already uses `--format=esm`, which is correct. Tiptap 2.x is ESM-native. Do not switch to CJS.

**Gotcha: `target=es2020`.** Tiptap uses class fields and optional chaining, both supported in ES2020. The existing target is fine.

---

## HTML Sanitization (Rails Side)

**Confidence:** HIGH (gem choices); MEDIUM (exact config) — verify Loofah version against the Gemfile.lock after install.

### Decision: Use Loofah directly (not ActionText sanitizer, not a new gem)

**Do not use `ActionText::ContentHelper.sanitize`** — it is coupled to ActionText's attachment model and its allowlist is tuned for Trix output, not generic Tiptap HTML.

**Do not add `rails_sanitize` gem** — it wraps Rails' built-in `sanitize` helper which itself wraps Loofah. Adding the gem is redundant; Loofah is already in your bundle as a Rails dependency.

**Use `ActionController::Base.helpers.sanitize` with a custom allowlist**, or call Loofah directly in a model callback.

### Recommended: Model `before_save` callback with Loofah

```ruby
# app/models/blog.rb
require "loofah"

class Blog < ApplicationRecord
  before_save :sanitize_body

  ALLOWED_TAGS = %w[
    h1 h2 h3 h4 h5 h6
    p br strong em u s del ins
    ul ol li
    blockquote pre code
    table thead tbody tr th td
    img a
    hr
    span div
  ].freeze

  ALLOWED_ATTRIBUTES = {
    "a"    => %w[href title target rel],
    "img"  => %w[src alt title width height],
    "th"   => %w[colspan rowspan],
    "td"   => %w[colspan rowspan],
    "p"    => %w[style],   # for text-align from TextAlign extension
    "h1"   => %w[style],
    "h2"   => %w[style],
    "h3"   => %w[style],
    "h4"   => %w[style],
    "h5"   => %w[style],
    "h6"   => %w[style],
    "span" => %w[style],   # for TextStyle/Color extension
  }.freeze

  # Allowlisted style properties (Loofah's CSS scrubber)
  ALLOWED_CSS_PROPERTIES = %w[text-align color].freeze

  private

  def sanitize_body
    return if body.blank?
    self.body = Loofah.fragment(body)
      .scrub!(Loofah::HTML5::SafeListScrubber.new)
      .to_s
  end
end
```

**Why this approach:**
- Loofah is already loaded (it is a Rails dependency via `rails-html-sanitizer`)
- The SafeListScrubber applies the OWASP-recommended HTML5 allowlist
- Running `before_save` means the stored HTML is always clean, regardless of how it arrived
- `raw @blog.body` in views is safe because the DB value is pre-sanitized

**Gotcha: CSS properties in `style` attributes.** The TextAlign extension emits `style="text-align: center"` on headings and paragraphs. The default Loofah SafeListScrubber strips `style` attributes. You need to configure Loofah to allow `text-align` explicitly, or use a custom scrubber. The simplest approach is to extend SafeListScrubber with `allow_attributes`:

```ruby
scrubber = Loofah::HTML5::SafeListScrubber.new
# Allow style attr on block elements for text alignment
self.body = Loofah.fragment(body).scrub!(scrubber).to_s
```

If the default scrubber strips needed styles, switch to `rails-html-sanitizer`'s `PermitScrubber`:

```ruby
scrubber = Rails::Html::PermitScrubber.new
scrubber.tags = ALLOWED_TAGS
scrubber.attributes = %w[href src alt title style rel target colspan rowspan]
self.body = Loofah.fragment(body).scrub!(scrubber).to_s
```

`rails-html-sanitizer` is already in your bundle (it's a Rails dependency) — no new gem needed.

---

## Tailwind Typography (prose) Compatibility

**Confidence:** HIGH — this is a known configuration requirement.

### The problem

Tiptap renders `<p>`, `<h2>`, `<ul>`, `<table>`, etc. as plain HTML. Tailwind's `@tailwindcss/typography` plugin applies beautiful default styles to all of these when wrapped in a `.prose` class. This is perfect for the public blog show page.

However, Tiptap's editor surface also renders these same elements *inside the contenteditable div*. If you apply `.prose` to the editor container, the prose styles apply inside the editor too, giving you a true WYSIWYG preview — which is exactly what you want for heading styles.

### Recommended setup

**Public show page** (`app/views/blogs/show.html.erb`):
```erb
<article class="prose prose-lg max-w-none">
  <%= raw sanitize(@blog.body) %>
</article>
```

Use `sanitize` here as a defence-in-depth even though body is pre-sanitized at save time.

**Editor surface** (inside the tiptap editor div):
```html
<div data-tiptap-target="editor"
     class="tiptap-editor prose prose-lg max-w-none min-h-[400px] focus:outline-none border rounded-b-lg p-4">
</div>
```

Applying `.prose` to the editor container means headings, paragraphs, lists, and tables preview exactly as they will appear on the public page — no separate "preview mode" needed.

### Required @tailwindcss/typography version

The project already uses Tailwind CSS 4. The `@tailwindcss/typography` plugin for Tailwind v4 is `@tailwindcss/typography@^0.5.x` — but note that the Tailwind v4 plugin API changed. Confirm which version you need:

- **Tailwind CSS 4.x with the new plugin API:** Use `@tailwindcss/typography` 0.5.x (the plugin has been updated to support v4 via `@plugin` directive in CSS). Check the plugin's changelog for v4 compatibility.

```bash
npm install @tailwindcss/typography
```

Add to `application.tailwind.css`:
```css
@plugin "@tailwindcss/typography";
```

**Gotcha: Tailwind v4 uses `@plugin` not `plugins:[]` in tailwind.config.js.** Since this project is on Tailwind CSS 4, the typography plugin is imported via the CSS `@plugin` directive, not a JS config file. Do not create a `tailwind.config.js` if none exists.

---

## Migration from ActionText to Plain `body` Column

**Confidence:** HIGH — this is a one-time data migration pattern.

### Steps

1. **Add the new column:**
```ruby
# db/migrate/YYYYMMDDHHMMSS_add_body_to_blogs.rb
class AddBodyToBlogs < ActiveRecord::Migration[8.0]
  def change
    add_column :blogs, :body, :text
  end
end
```

2. **Migrate existing content (one-time data migration):**

ActionText stores rich text in the `action_text_rich_texts` table. The `body` column on that table stores a HTML fragment (Trix's output). Extract it:

```ruby
# db/migrate/YYYYMMDDHHMMSS_migrate_blog_content_to_body.rb
class MigrateBlogContentToBody < ActiveRecord::Migration[8.0]
  def up
    Blog.find_each do |blog|
      rich_text = ActionText::RichText.find_by(
        record_type: "Blog",
        record_id:   blog.id,
        name:        "content"
      )
      next unless rich_text&.body.present?

      # ActionText body is a fragment; .to_html gives the rendered HTML
      blog.update_columns(body: rich_text.body.to_html)
    end
  end

  def down
    # Non-reversible without re-importing to ActionText
    raise ActiveRecord::IrreversibleMigration
  end
end
```

3. **Update the Blog model:**
```ruby
# Remove:   has_rich_text :content
# Keep:     body plain text column (no model declaration needed)
```

4. **Update views:**
```erb
<%# Before (ActionText): %>
<%= @blog.content %>

<%# After (plain HTML): %>
<article class="prose prose-lg max-w-none">
  <%= raw sanitize(@blog.body) %>
</article>
```

5. **Remove ActionText from application.js:**
```javascript
// Remove these two lines:
import "trix"
import "@rails/actiontext"
```

6. **Drop the old rich text data (optional, after verification):**
```ruby
# After confirming migration was successful:
ActionText::RichText.where(record_type: "Blog", name: "content").delete_all
```

**Gotcha: `<action-text-attachment>` elements.** If any existing Trix content contains embedded ActionText attachments (for files/images uploaded via ActionText), their HTML will be `<action-text-attachment>` custom elements that Tiptap cannot render. These will not crash the editor but will render as unknown elements on the public page. Audit existing content for attachments before removing the ActionText import.

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Editor | Tiptap 2.x | Quill 2.x | Quill's delta format requires conversion to/from HTML; Tiptap outputs HTML natively; Tiptap has better extension ecosystem |
| Editor | Tiptap 2.x | Prosemirror directly | Tiptap is a maintained abstraction over ProseMirror; using ProseMirror directly requires significantly more code for the same feature set |
| Sanitization | Loofah / `rails-html-sanitizer` | `sanitize` gem (no-op — same thing) | `rails-html-sanitizer` wraps Loofah; no new dependency needed |
| Image upload | ActiveStorage DirectUpload | Third-party uploader (Cloudinary widget, etc.) | Project constraint requires ActiveStorage |
| Toolbar | Vanilla JS + Stimulus | Tiptap UI library (`@tiptap/ui`) | `@tiptap/ui` is a React component library; Stimulus is the constraint |
| CSS | `@tailwindcss/typography` (prose) | Custom editor CSS | `prose` is already used on the show page; applying it to the editor gives free WYSIWYG |

---

## Sources

> Web search and WebFetch tools were unavailable in this session. The following are training-knowledge sources (cutoff August 2025):

- Tiptap 2.x official documentation: https://tiptap.dev/docs/editor/extensions/overview
- Tiptap extensions reference: https://tiptap.dev/docs/editor/extensions/nodes/heading, /table, /image, /link
- ActiveStorage Direct Upload guide: https://guides.rubyonrails.org/active_storage_overview.html#direct-uploads
- Loofah / rails-html-sanitizer: https://github.com/rails/rails-html-sanitizer
- Tailwind Typography v4: https://github.com/tailwindlabs/tailwindcss-typography
- `@tiptap/pm` rationale: https://tiptap.dev/docs/editor/getting-started/install/vanilla-javascript

**Confidence summary:**

| Area | Level | Reason |
|------|-------|--------|
| Tiptap package names | HIGH | Stable API since 2.0; package names have not changed in 2+ years |
| Exact patch versions | MEDIUM | Tiptap releases frequently; verify with `npm info @tiptap/core version` at install time |
| Stimulus controller pattern | HIGH | Standard Stimulus + third-party JS pattern; well-established in Rails community |
| DirectUpload wiring | HIGH | Official Rails API; unchanged since Rails 6 |
| Loofah sanitization | HIGH | Core Rails dependency; API is stable |
| Tailwind v4 + typography | MEDIUM | Tailwind v4 is relatively new; verify `@plugin` syntax is current in typography 0.5.x |
| ActionText migration | HIGH | Standard ActiveRecord migration pattern |
