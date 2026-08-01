# Phase 1: Editor Foundation — Research

**Researched:** 2026-05-13
**Domain:** Tiptap 3.x / Stimulus / Rails 8 / HTML sanitization / JSON-LD security
**Confidence:** HIGH (core stack verified via npm registry and Context7; codebase read directly)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Migration approach = Rake task. Schema migration adds `blogs.body text` column; a separate `rake blogs:migrate_body` task backfills content. Can be re-run if it fails partway. Deploy sequence = `db:migrate` then `rake blogs:migrate_body`.
- **D-02:** ActionText attachment nodes — strip silently via Nokogiri. `<action-text-attachment>` tags removed; surrounding text preserved intact.
- **D-03:** Clean cutover — remove `has_rich_text :content` from Blog model in the same commit that adds Tiptap. `action_text_rich_texts` table rows stay in DB untouched (safe rollback path) but no app code reads them after migration.
- **D-04:** Remove `has_rich_text :content` declaration from `app/models/blog.rb`.
- **D-05:** Remove `import "trix"` and `import "@rails/actiontext"` from `app/javascript/application.js`.
- **D-06:** Remove `trix` npm package from `package.json`. The `actiontext` Rails gem stays.
- **D-07:** Build the full toolbar in Phase 1 — include Phase 2 feature buttons (table insert, image upload) now as disabled stubs. Active in Phase 1: H1–H6, bold, italic, strikethrough, bullet list, ordered list, link, undo, redo.
- **D-08:** Disabled stub buttons (table, image) appear greyed out (`opacity-50`, `cursor-not-allowed`) with "Coming soon" tooltip on hover.
- **D-09:** Toolbar uses `position: sticky` with a `top` offset matching the admin navbar height.
- **D-10:** Apply `prose prose-lg` (Tailwind Typography) directly to the `.ProseMirror` contenteditable div.
- **D-11:** If admin layout styles bleed in, scope it as `.tiptap-editor .ProseMirror.prose`.
- **D-12:** HTML sanitized via `Rails::Html::SafeListSanitizer` in a `before_save` callback on Blog model. Safelist for Phase 1: `p, br, h1, h2, h3, h4, h5, h6, ul, ol, li, strong, em, a, blockquote, code, pre`.
- **D-13:** View renders pre-sanitized body with `raw @blog.body`.
- **D-14:** Replace `.to_json.html_safe` with `json_escape(schema.to_json)` in `ApplicationHelper` for `render_article_schema`, `render_breadcrumbs_schema`, `render_product_schema`, and `render_organization_schema`.

### Claude's Discretion

- Migration cutover: Clean cutover chosen (no dual-read period). Verify no other callers of `blog.content` before removing `has_rich_text`.
- ActionText gem: Keep Rails actiontext gem.
- WYSIWYG scoping: If `prose` classes conflict with admin layout in Tailwind CSS 4, researcher should find the correct scoping approach — preference is zero custom CSS duplication.

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within Phase 1 scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| EDIT-01 | Admin can compose blog content in Tiptap editor (replaces Trix/ActionText; content stored as sanitized HTML in `blogs.body` text column) | Tiptap 3.x vanilla JS init pattern verified; Stimulus controller lifecycle mapped; form submission via hidden input confirmed |
| EDIT-02 | Editor toolbar remains fixed/sticky while admin scrolls long posts | `position: sticky` with `top-0` confirmed; admin layout has static (non-fixed) header — toolbar snaps to viewport top when header scrolls away |
| EDIT-03 | Admin can apply H1–H6 headings from the toolbar | `editor.chain().focus().toggleHeading({ level: N }).run()` + `editor.isActive('heading', { level: N })` — confirmed via Context7 |
| EDIT-04 | Heading styles render visually inside the editor matching the live page (WYSIWYG via Tailwind prose) | `@tailwindcss/typography` v4 `@plugin` syntax confirmed; `prose prose-lg` applied directly to `.ProseMirror` div; public show page uses same classes |
| EDIT-05 | Bullet/numbered lists render correctly on live pages | StarterKit bundles BulletList and OrderedList extensions; `prose` classes handle `ul`/`ol` rendering automatically |
| EDIT-06 | Existing blog content migrated from ActionText to `body` column without data loss | ActionText body read from `action_text_rich_texts.body`; Nokogiri strips `<action-text-attachment>` nodes; Rake task pattern documented |
| SEC-01 | Blog body HTML sanitized server-side via `Rails::Html::SafeListSanitizer` before saving | `rails-html-sanitizer 1.6.2` available in Gemfile.lock; `before_save` callback pattern verified |
| SEC-02 | All JSON-LD `<script>` tags use `json_escape` to prevent `</script>` injection | `json_escape` from `ERB::Util` escapes `<`, `>`, `&` as Unicode sequences; fix pattern verified |
</phase_requirements>

---

## Summary

Phase 1 replaces the Trix/ActionText rich text editor with a Tiptap 3.x Stimulus controller, migrates content from ActionText's `action_text_rich_texts` table to a plain `blogs.body text` column, and fixes two server-side security issues. All primary libraries are available and verified against current registry versions.

The most important structural finding: **the `blogs` table currently has no `body` column** — content is stored entirely in `action_text_rich_texts.body` via the `has_rich_text :content` association. The schema migration must add this column before the Rake backfill can run.

A second finding that affects the UI-SPEC: **the admin layout header is `position: static` (not fixed or sticky)**. When the page scrolls, the header scrolls out of view. The sticky toolbar therefore needs `top-0`, not `top-16`. The UI-SPEC's `top-16` offset would only be correct if the navbar were `position: fixed`. This is a discrepancy the planner must resolve before implementation.

Tiptap 3.23.2 (released 2026-05-12) ships with proper `"type": "module"` and dual ESM/CJS exports in all packages, so no dual-loading or ProseMirror version conflicts occur with esbuild's ESM output mode.

**Primary recommendation:** Wire Tiptap via a single `tiptap_editor_controller.js` Stimulus controller. Initialize in `connect()`, destroy in `disconnect()`. Write HTML to a hidden `input[name="blog[body]"]` in the `connect()` and on each `onUpdate` callback so the form always submits current content.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Editor UI + toolbar | Browser (Stimulus controller) | — | Tiptap is a client-side ProseMirror wrapper; all toolbar interaction is JS |
| HTML serialization | Browser (Stimulus controller) | — | `editor.getHTML()` runs in browser; result written to hidden form field |
| Form submission | Frontend Server (Rails ERB form) | — | Standard Rails form_with; controller receives `:body` param |
| HTML sanitization | API / Backend (Rails model callback) | — | `before_save` on Blog model — never rely on client-side sanitization |
| Content migration | Database / Storage (Rake task) | — | Reads `action_text_rich_texts`, writes `blogs.body`; a data transformation |
| JSON-LD security | API / Backend (Rails helper) | — | Server-side rendering of structured data scripts |
| WYSIWYG typography | Browser + CDN | — | `prose prose-lg` applied to `.ProseMirror` div; CSS delivered via Tailwind build |

---

## Standard Stack

### Core (verified against npm registry 2026-05-13)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `@tiptap/core` | 3.23.2 | Editor engine; `Editor` class, extension API | Headless, framework-agnostic; works in Stimulus without React |
| `@tiptap/starter-kit` | 3.23.2 | Bundled extension set (Bold, Italic, Strike, Heading, Lists, Blockquote, Code, History, etc.) | One import covers all Phase 1 toolbar features |
| `@tiptap/extensions` | 3.23.2 | Supplementary extensions including `Placeholder`, `UndoRedo` | Placeholder for editor hint text; UndoRedo if needed standalone |
| `@tailwindcss/typography` | 0.5.19 | `prose` utility classes for typographic defaults | Already used on public blog show page; same `prose prose-lg` classes for WYSIWYG |

**Note on Link extension:** `@tiptap/extension-link` is already bundled inside `@tiptap/starter-kit` as of 3.x — do NOT install it separately. Confirm with `npm view @tiptap/starter-kit dependencies` which lists `@tiptap/extension-link ^3.23.2`.

### Version Verification

All versions confirmed via `npm view <package> version` on 2026-05-13:
- `@tiptap/core`: 3.23.2 (published 2026-05-12)
- `@tiptap/starter-kit`: 3.23.2 (published 2026-05-12)
- `@tiptap/extensions`: 3.23.2 (published 2026-05-12)
- `@tailwindcss/typography`: 0.5.19

### Supporting (already in project)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `rails-html-sanitizer` | 1.6.2 | `Rails::Html::SafeListSanitizer` — server-side HTML sanitization | Already a Rails dependency; use in `before_save` callback |
| `nokogiri` | 1.18.10 | HTML/XML parsing | Already a transitive dependency; use in Rake migration task to strip `<action-text-attachment>` nodes |

### Not Needed (already in project as transitive deps)

- ProseMirror packages: pulled in automatically via `@tiptap/pm`
- `@tiptap/extension-link`: already bundled in `@tiptap/starter-kit`

### Installation

```bash
# Install new packages
npm install @tiptap/core @tiptap/starter-kit @tiptap/extensions @tailwindcss/typography

# Remove Trix/ActionText npm packages
npm uninstall trix @rails/actiontext
```

---

## Architecture Patterns

### System Architecture Diagram

```
Admin browser
  |
  | [GET /admin/blogs/:id/edit]
  v
Rails ERB form (app/views/admin/blogs/_form.html.erb)
  |-- renders: <div data-controller="tiptap-editor">
  |     |-- Toolbar div (sticky)
  |     |-- .ProseMirror contenteditable (Tiptap mounts here)
  |     |-- <input type="hidden" name="blog[body]">
  |
  | [Stimulus connect()]
  v
tiptap_editor_controller.js
  |-- new Editor({ element, extensions: [StarterKit.configure(...)], content: existingHTML })
  |-- onUpdate: () => hiddenInput.value = editor.getHTML()
  |-- onSelectionUpdate: () => updateToolbarActiveStates()
  |
  | [Toolbar button click]
  v
editor.chain().focus().toggleBold().run()  (etc.)
  |
  | [Form submit]
  v
Rails controller (Admin::BlogsController#update)
  |-- params[:blog][:body]  (sanitized HTML string)
  |
  | [Blog model before_save]
  v
Rails::Html::SafeListSanitizer
  |-- strips disallowed tags/attributes
  |-- result stored in blogs.body (plain text column)
  |
  | [Public GET /blog/:slug]
  v
app/views/blogs/show.html.erb
  |-- <div class="prose prose-lg max-w-none">
  |--   raw @blog.body
  |-- </div>
```

### Recommended Project Structure (new files only)

```
app/
  javascript/
    controllers/
      tiptap_editor_controller.js   # New: Stimulus controller wrapping Tiptap
      index.js                      # Modified: add tiptap-editor registration
    application.js                  # Modified: remove trix/actiontext imports
  assets/
    stylesheets/
      application.tailwind.css      # Modified: add @plugin "@tailwindcss/typography"
                                    # remove @import "./actiontext.css"
lib/
  tasks/
    blogs.rake                      # New: blogs:migrate_body Rake task
db/
  migrate/
    YYYYMMDDHHMMSS_add_body_to_blogs.rb   # New: adds blogs.body text column
```

### Pattern 1: Stimulus Controller — Init, Destroy, Form Submission

**What:** Tiptap `Editor` instance created on `connect()`, destroyed on `disconnect()`. Content written to hidden input on every update so the Rails form always submits current HTML.

**When to use:** Any rich text field in a Rails/Stimulus form that stores HTML in a plain column.

```javascript
// Source: Context7 /ueberdosis/tiptap-docs (vanilla JavaScript docs)
// app/javascript/controllers/tiptap_editor_controller.js

import { Controller } from "@hotwired/stimulus"
import { Editor } from "@tiptap/core"
import StarterKit from "@tiptap/starter-kit"
import { Placeholder } from "@tiptap/extensions"

export default class extends Controller {
  static targets = ["editor", "input"]

  connect() {
    const existingContent = this.inputTarget.value || ""

    this.editor = new Editor({
      element: this.editorTarget,
      extensions: [
        StarterKit.configure({
          heading: { levels: [1, 2, 3, 4, 5, 6] },
        }),
        Placeholder.configure({
          placeholder: "Start writing your post...",
        }),
      ],
      content: existingContent,
      onUpdate: ({ editor }) => {
        this.inputTarget.value = editor.getHTML()
      },
      onSelectionUpdate: ({ editor }) => {
        this.updateToolbarState(editor)
      },
    })

    // Sync initial content to hidden input immediately
    this.inputTarget.value = this.editor.getHTML()
  }

  disconnect() {
    if (this.editor) {
      this.editor.destroy()
      this.editor = null
    }
  }

  // Turbo cache cleanup — called before Turbo caches the page
  teardown() {
    if (this.editor) {
      this.editor.destroy()
      this.editor = null
    }
  }

  updateToolbarState(editor) {
    // Update aria-pressed and active classes on toolbar buttons
    // Called on every selectionUpdate
  }
}
```

**Registration in index.js:**
```javascript
// app/javascript/controllers/index.js
import TiptapEditorController from "./tiptap_editor_controller"
application.register("tiptap-editor", TiptapEditorController)
```

### Pattern 2: HTML Serialization and Deserialization

**What:** Tiptap always outputs and accepts HTML strings in Phase 1. Input = existing `blogs.body` HTML string (or empty string); output = `editor.getHTML()` written to hidden input before form submit.

**Key points:**
- `editor.getHTML()` returns a complete HTML string (e.g., `<h1>Title</h1><p>Body</p>`)
- `editor.setContent(html)` replaces editor content at runtime (not needed for initial load — pass `content:` to constructor)
- Empty editor outputs `<p></p>` — treat this as blank in model validation

```javascript
// Source: Context7 /ueberdosis/tiptap-docs
const html = editor.getHTML()     // "<h2>Hello</h2><p>World</p>"
const text = editor.getText()     // "Hello\n\nWorld"
editor.commands.setContent('<p>New content</p>')  // replace at runtime
```

### Pattern 3: Toolbar Button Active States

**What:** On every `selectionUpdate` and `transaction`, read `editor.isActive()` to toggle button appearance.

```javascript
// Source: Context7 /ueberdosis/tiptap-docs

// Check active state
editor.isActive('bold')                        // true/false
editor.isActive('heading', { level: 1 })       // true/false
editor.isActive('bulletList')                  // true/false
editor.isActive('link')                        // true/false

// Execute commands (always end chain with .run())
editor.chain().focus().toggleBold().run()
editor.chain().focus().toggleHeading({ level: 1 }).run()
editor.chain().focus().toggleBulletList().run()
editor.chain().focus().toggleOrderedList().run()
editor.chain().focus().toggleStrike().run()
editor.chain().focus().undo().run()
editor.chain().focus().redo().run()

// Link insertion with window.prompt (per D-09 / UI-SPEC)
const url = window.prompt("Enter URL:")
if (url) {
  editor.chain().focus().extendMarkRange('link').setLink({ href: url }).run()
}
```

### Pattern 4: Tailwind Typography v4 Registration

**What:** Add the `@plugin` directive in the Tailwind CSS entry file. Remove the old `actiontext.css` import.

**Important:** `@tailwindcss/typography` v0.5.x works with Tailwind v4 via the `@plugin` directive (replaces `tailwind.config.js` plugins array). This is confirmed in the official GitHub discussion.

```css
/* app/assets/stylesheets/application.tailwind.css */
@import "tailwindcss";
@plugin "@tailwindcss/typography";

/* Remove: @import "./actiontext.css"; */

/* Only permitted custom CSS for Phase 1 (if prose conflicts with admin styles): */
.tiptap-editor .ProseMirror {
  @apply prose prose-lg max-w-none;
}
```

**Alternative (no custom CSS):** Apply classes directly on the element in HTML:
```html
<div class="ProseMirror prose prose-lg max-w-none ..."
     data-tiptap-editor-target="editor"
     contenteditable="true">
</div>
```
The planner should try the direct class approach first; add the CSS rule only if admin layout styles bleed.

### Pattern 5: Rake Migration Task

**What:** Reads each blog's ActionText rich text record, strips `<action-text-attachment>` nodes via Nokogiri, writes plain HTML to `blogs.body`. Idempotent — skips posts where `body` is already populated.

**Data model:** ActionText stores content in `action_text_rich_texts` table with `record_type='Blog'`, `record_id=<blog.id>`, `name='content'`, `body=<Trix HTML>`.

```ruby
# Source: Codebase read (db/migrate/20251216121901_migrate_blog_content_to_rich_text.rb pattern)
# lib/tasks/blogs.rake

namespace :blogs do
  desc "Migrate blog content from ActionText to blogs.body column"
  task migrate_body: :environment do
    total = Blog.count
    migrated = 0
    skipped = 0

    Blog.find_each do |blog|
      if blog.body.present?
        puts "Skipping post #{blog.id} — body already populated"
        skipped += 1
        next
      end

      rich_text = ActionText::RichText.find_by(
        record_type: "Blog",
        record_id: blog.id,
        name: "content"
      )

      if rich_text&.body.present?
        raw_html = rich_text.read_attribute(:body)   # raw Trix HTML from DB

        # Strip action-text-attachment nodes; preserve surrounding text
        doc = Nokogiri::HTML.fragment(raw_html)
        doc.css("action-text-attachment").each(&:remove)
        clean_html = doc.to_html

        blog.update_column(:body, clean_html)
        migrated += 1
        puts "Migrated #{migrated}/#{total} posts"
      else
        puts "Skipping post #{blog.id} — no ActionText content found"
        skipped += 1
      end
    end

    puts "Done. #{migrated} posts migrated, #{skipped} skipped."
  end
end
```

**Note on `read_attribute(:body)`:** The `rich_text.body` accessor returns an `ActionText::Content` object; calling `.to_s` on it would render attachments as HTML (calling the Rails view layer). Instead, `read_attribute(:body)` bypasses the ActionText layer and reads the raw HTML stored in the column — this is what we want for direct Nokogiri manipulation.

### Pattern 6: Server-Side HTML Sanitization

```ruby
# Source: WebSearch verified against rails-html-sanitizer README; gem confirmed at 1.6.2
# app/models/blog.rb

ALLOWED_TAGS = %w[p br h1 h2 h3 h4 h5 h6 ul ol li strong em a blockquote code pre].freeze
ALLOWED_ATTRIBUTES = { "a" => %w[href target rel] }.freeze

before_save :sanitize_body

private

def sanitize_body
  return if body.blank?
  sanitizer = Rails::Html::SafeListSanitizer.new
  self.body = sanitizer.sanitize(
    body,
    tags: ALLOWED_TAGS,
    attributes: ALLOWED_ATTRIBUTES.values.flatten
  )
end
```

**Note on attribute scoping:** `Rails::Html::SafeListSanitizer` takes a flat `attributes:` list, not a per-tag hash. Allowed attributes apply globally. For Phase 1, only `href`, `target`, and `rel` on `<a>` tags is the intent — which is fine since those are only meaningful on `<a>`.

### Pattern 7: JSON-LD Security Fix (SEC-02)

**What:** `json_escape` from `ERB::Util` escapes `<`, `>`, `&`, ` `, ` ` as Unicode escape sequences (e.g., `<` becomes `<`). This prevents `</script>` injection inside a JSON-LD `<script>` block.

**Important:** The result of `json_escape` is NOT marked `html_safe`, so wrap with `raw()` or `html_safe` only AFTER calling `json_escape`, not before. The `content_tag :script` helper applies its own escaping to tag attributes but NOT to the content block — which is why `json_escape` on the content body is required.

```ruby
# Source: WebSearch verified against ERB::Util docs and APIdock
# BEFORE (vulnerable):
content_tag :script, schema.to_json.html_safe, type: "application/ld+json"

# AFTER (correct):
content_tag :script, json_escape(schema.to_json), type: "application/ld+json"
```

Apply to all four helpers: `render_organization_schema`, `render_article_schema`, `render_product_schema`, `render_breadcrumbs_schema`.

### Anti-Patterns to Avoid

- **Calling `editor.getHTML()` only on form submit:** Content will be empty if the user submits without interacting with the editor after page load. Sync on `connect()` AND on every `onUpdate` callback.
- **Instantiating Tiptap without destroying it on `disconnect()`:** Causes memory leaks and duplicate editor instances on Turbo navigation. Always call `editor.destroy()` in `disconnect()`.
- **Using `rich_text.body.to_s` in the Rake migration:** This renders ActionText attachments through the Rails view layer (HTTP requests to resolve attachments). Use `read_attribute(:body)` for the raw HTML string.
- **Applying sanitization in the controller:** Always sanitize in `before_save` on the model. Never trust controller-layer sanitization alone.
- **Adding `@tiptap/extension-link` as a separate install:** It is already a dependency of `@tiptap/starter-kit` 3.x. Adding it separately risks version mismatches.
- **Using `schema.to_json.html_safe` for JSON-LD:** This is the exact vulnerability pattern in the existing code. Use `json_escape(schema.to_json)` instead.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Rich text editing | Custom contenteditable + execCommand | `@tiptap/starter-kit` | execCommand is deprecated; ProseMirror handles undo, selection, DOM reconciliation |
| HTML sanitization | Regex-based tag stripping | `Rails::Html::SafeListSanitizer` | Regex cannot parse malformed HTML; Nokogiri-based sanitizer handles malformed input safely |
| ActionText HTML stripping | Manual string replacement | Nokogiri CSS selector + `.remove` | `<action-text-attachment>` tags can be nested; string replace misses edge cases |
| Toolbar active state | Global document listener | `editor.isActive()` in `onSelectionUpdate` | ProseMirror selection model is async; global listeners fight with the editor |
| JSON escaping for `<script>` | Manual `gsub('</', '<\/')` | `json_escape` from `ERB::Util` | Does not cover all injection vectors; `json_escape` handles all Unicode escape cases |

**Key insight:** In every case, the ecosystem provides a battle-hardened solution that handles HTML edge cases (malformed input, nested elements, Unicode) that hand-rolled solutions miss.

---

## Runtime State Inventory

> Phase 1 includes a content migration from ActionText to a plain column. This is a migration phase for blog content state.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | `action_text_rich_texts` table: rows with `record_type='Blog'`, `name='content'`. These hold all existing blog post HTML content. | Data migration — `rake blogs:migrate_body` reads each row, strips attachments, writes to `blogs.body` |
| Live service config | None — no external services store blog content (no CMS API, no CDN content config) | None |
| OS-registered state | None | None |
| Secrets/env vars | None — no secret key names reference `content` or `body` | None |
| Build artifacts | `app/assets/builds/application.css` and `application.js` — rebuilt by esbuild/Tailwind CLI; stale after removing `actiontext.css` import | Rebuild: `yarn build && yarn build:css` |

**ActionText table retention:** Per D-03, the `action_text_rich_texts` table is NOT dropped. Rows remain in place as the rollback path. Only the `has_rich_text :content` declaration is removed from the Blog model.

---

## Common Pitfalls

### Pitfall 1: Sticky Toolbar Offset — UI-SPEC vs. Actual Admin Layout

**What goes wrong:** UI-SPEC specifies `top-16` (64px) for the sticky toolbar. This is only correct if the admin header is `position: fixed` or `position: sticky`. The admin header in `app/views/layouts/admin.html.erb` is `position: static` — it scrolls away with the page.

**Why it happens:** The UI-SPEC was written assuming the header stays visible while the user edits. But in the actual admin layout, the header is a normal document-flow `<header>` element.

**How to avoid:** Use `top-0` on the sticky toolbar. When the user scrolls past the admin header, the header leaves the viewport and the toolbar sticks to the top of the viewport (no overlap). This is the correct behavior for a static-header layout.

**Warning signs:** If `top-16` is used with a static header, the toolbar will appear to "float" 64px below the top of the viewport when the header has scrolled away — revealing a 64px gap of page content above the sticky toolbar.

**Resolution for planner:** Use `class="sticky top-0 z-10 bg-white ..."` for the toolbar. The UI-SPEC's `top-16` is incorrect for this layout.

### Pitfall 2: Turbo Page Caching Leaves a Dead Editor

**What goes wrong:** Turbo caches the page DOM before navigating away. If `editor.destroy()` is not called before the cache snapshot, the next time Turbo restores the cached page, there will be an orphaned ProseMirror DOM with no live editor instance. User cannot type; toolbar does nothing.

**Why it happens:** Turbo takes the DOM snapshot at `turbo:before-cache`. The Stimulus `disconnect()` lifecycle fires at the same time, but there is a race if teardown is expensive.

**How to avoid:** Call `editor.destroy()` in both `disconnect()` and a `teardown()` method that responds to the global `turbo:before-cache` event pattern. In `application.js`, add:
```javascript
document.addEventListener('turbo:before-cache', () => {
  application.controllers.forEach(controller => {
    if (typeof controller.teardown === 'function') {
      controller.teardown()
    }
  })
})
```

**Warning signs:** After navigating away and back, the editor area is visible but clicking/typing has no effect; no `console.error` in the editor because the ProseMirror view was properly removed — it just wasn't reinitialized.

### Pitfall 3: Blog Factory Uses `content` Attribute — Breaks After Migration

**What goes wrong:** `spec/factories/blogs.rb` has `content { "Blog post content..." }`. After removing `has_rich_text :content` from the Blog model, FactoryBot will attempt to assign `:content` as a plain attribute. The `blogs` table has no `content` column (it was removed in the earlier migration to ActionText). This causes a `ActiveRecord::UnknownAttributeError` in tests.

**Why it happens:** The factory was written for the ActionText era. After removing `has_rich_text`, `:content` is unknown.

**How to avoid:** Update the factory to use `body { "<p>Blog post content...</p>" }` instead of `content { "..." }`. Simultaneously update the Blog model validation from `validates :title, :content, presence: true` to `validates :title, :body, presence: true`.

**Warning signs:** All RSpec model/request tests that use `create(:blog)` fail with `ActiveRecord::UnknownAttributeError: unknown attribute 'content'`.

### Pitfall 4: `seo_description` Method Still References `content`

**What goes wrong:** `Blog#seo_description` calls `strip_tags(content)`. After removing `has_rich_text :content`, `content` becomes `nil` (method does not exist), causing a `NoMethodError` on the public blog show page.

**Why it happens:** The `seo_description` method was written against the ActionText API where `content` was the rich text accessor.

**How to avoid:** Update `seo_description` to use `body` instead:
```ruby
def seo_description
  meta_description.presence || ActionController::Base.helpers.strip_tags(body).truncate(160)
end
```

**Warning signs:** `NoMethodError: undefined method 'content' for #<Blog...>` on public blog show page after migration.

### Pitfall 5: Public Blog Show Page Still Calls `@blog.content`

**What goes wrong:** `app/views/blogs/show.html.erb` line 62 renders `<%= @blog.content %>`. After removing `has_rich_text :content`, this outputs nothing (or errors) instead of the body HTML.

**How to avoid:** Change to `<%= raw @blog.body %>` and wrap in the `prose` container:
```erb
<div class="prose prose-lg max-w-none mb-16">
  <%= raw @blog.body %>
</div>
```

**Warning signs:** Public blog show page renders blank content area; no error shown (ActionText `has_rich_text` returns `nil` gracefully when the association is gone).

### Pitfall 6: `@tiptap/extension-link` Installed Separately Causes Version Conflict

**What goes wrong:** Installing `@tiptap/extension-link` separately alongside `@tiptap/starter-kit` can result in two copies of the same extension at potentially different patch versions, causing the `extendMarkRange('link')` command to fail with a schema mismatch.

**How to avoid:** Do NOT install `@tiptap/extension-link` separately. It is a dependency of `@tiptap/starter-kit` and is automatically available. Import it from `@tiptap/starter-kit` internally — or simply use the Link commands via `editor.chain().focus().setLink(...)` directly.

### Pitfall 7: esbuild Entry Point Glob Misses Subdirectory Files

**What goes wrong:** The build script uses `app/javascript/*.*` — this does NOT include files in subdirectories like `app/javascript/controllers/tiptap_editor_controller.js` as entry points. But this is fine — controllers are NOT entry points; they are imported via `app/javascript/controllers/index.js` which IS imported from `app/javascript/application.js` (an entry point).

**How to avoid:** Register the new controller in `app/javascript/controllers/index.js`:
```javascript
import TiptapEditorController from "./tiptap_editor_controller"
application.register("tiptap-editor", TiptapEditorController)
```
Do NOT add `tiptap_editor_controller.js` to `app/javascript/` directly.

---

## Code Examples

### Verified Tiptap 3.x Initialization (Context7)

```javascript
// Source: Context7 /ueberdosis/tiptap-docs (vanilla-javascript.mdx, editor.mdx)
import { Editor } from '@tiptap/core'
import StarterKit from '@tiptap/starter-kit'
import { Placeholder } from '@tiptap/extensions'

const editor = new Editor({
  element: document.querySelector('.editor'),
  extensions: [
    StarterKit.configure({
      heading: { levels: [1, 2, 3, 4, 5, 6] },
    }),
    Placeholder.configure({
      placeholder: 'Start writing your post...',
    }),
  ],
  content: '<p>Hello World!</p>',
  onUpdate: ({ editor }) => {
    console.log(editor.getHTML())
  },
  onSelectionUpdate: ({ editor }) => {
    // update toolbar button states
  },
})

// Cleanup (call in Stimulus disconnect())
editor.destroy()
```

### UndoRedo Extension (Tiptap 3.x — changed from 2.x)

```javascript
// Source: Context7 /ueberdosis/tiptap-docs (undo-redo.mdx, starterkit.mdx)
// StarterKit includes undoRedo by default in 3.x (via @tiptap/extensions/undo-redo)
// To disable: StarterKit.configure({ undoRedo: false })
// Undo/redo commands:
editor.chain().focus().undo().run()
editor.chain().focus().redo().run()
```

### Tailwind Typography v4 Plugin Registration

```css
/* Source: WebFetch from tailwindlabs/tailwindcss-typography GitHub + Discussion #14120 */
/* app/assets/stylesheets/application.tailwind.css */
@import "tailwindcss";
@plugin "@tailwindcss/typography";
```

### Rails::Html::SafeListSanitizer Pattern

```ruby
# Source: WebSearch verified against rails-html-sanitizer README
sanitizer = Rails::Html::SafeListSanitizer.new
clean = sanitizer.sanitize(
  body,
  tags: %w[p br h1 h2 h3 h4 h5 h6 ul ol li strong em a blockquote code pre],
  attributes: %w[href target rel]
)
```

### Nokogiri ActionText Attachment Stripping

```ruby
# Source: Codebase patterns + Nokogiri CSS selector API [ASSUMED pattern is standard]
doc = Nokogiri::HTML.fragment(raw_html)
doc.css("action-text-attachment").each(&:remove)
clean_html = doc.to_html
```

### JSON-LD Security Fix

```ruby
# Source: WebSearch verified against ERB::Util API docs
# BEFORE (vulnerable in current application_helper.rb):
content_tag :script, schema.to_json.html_safe, type: "application/ld+json"

# AFTER (correct):
content_tag :script, json_escape(schema.to_json), type: "application/ld+json"
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `history` extension separate install | UndoRedo bundled in `@tiptap/extensions`, enabled by default via StarterKit | Tiptap 3.x | No separate `@tiptap/extension-history` install needed |
| `@tiptap/extension-link` separate | Included in StarterKit 3.x dependencies | Tiptap 3.x | Do not install separately |
| `tailwind.config.js` plugins array | `@plugin "@tailwindcss/typography"` in CSS | Tailwind v4 | No JS config file needed for typography plugin |
| `has_rich_text` ActionText column | Plain `text` column with `before_save` sanitizer | Project decision | Simpler rendering; no `<action-text-attachment>` on public side |

**Deprecated/outdated:**
- `import "trix"` and `import "@rails/actiontext"` in `application.js` — removed entirely
- `@import "./actiontext.css"` in `application.tailwind.css` — removed; Tiptap uses ProseMirror CSS, not Trix CSS
- `trix` npm package — uninstalled
- `.trix-content a` CSS rule in `application.tailwind.css` — removed (no more Trix content)

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `Nokogiri::HTML.fragment(html).css("action-text-attachment").each(&:remove)` successfully strips attachment nodes while preserving surrounding inline text | Pattern 5 (Rake task) | Attachment nodes might contain text content that should be preserved; need to verify whether inner text of attachment tags matters |
| A2 | The admin header (`h-16`) scrolls away with the page — i.e., it is `position: static` — confirmed via layout code read, but actual browser rendering with potential CSS overrides not browser-tested | Pitfall 1 / Common Pitfalls | If any CSS in the built stylesheet applies `position: fixed` to the header, `top-0` would overlay the navbar; use `top-16` in that case |
| A3 | ActionText stores raw Trix HTML in `action_text_rich_texts.body`; `read_attribute(:body)` returns this raw HTML without rendering attachments | Pattern 5 (Rake task) | If ActionText body column stores JSON or pre-rendered HTML differently than expected, migration logic needs adjustment |

---

## Open Questions (RESOLVED)

1. **Sticky toolbar offset — UI-SPEC discrepancy**
   - What we know: Admin header is `position: static`; UI-SPEC says `top-16` (64px)
   - What's unclear: Whether any global CSS makes the header fixed; whether the `top-16` vs `top-0` decision should be re-confirmed with the user
   - Recommendation: Use `top-0` unless a CSS audit reveals the header is made fixed elsewhere. The planner should note this discrepancy and use `top-0`.

2. **`blog.content` caller audit — clean cutover verification**
   - What we know: Direct audit found `@blog.content` in `app/views/blogs/show.html.erb:62` and `content` in `Blog#seo_description`; both must be updated in the same commit
   - What's unclear: Whether there are any partial renders, mailers, or API endpoints referencing `blog.content` not caught by the grep
   - Recommendation: The plan should include a pre-commit verification step: `grep -rn "\.content\b" app/ --include="*.{rb,erb}"` before cutting over.

3. **ActionText `body.to_s` vs `read_attribute(:body)` in migration**
   - What we know: `rich_text.body` is an `ActionText::Content` object; `read_attribute(:body)` reads the raw column
   - What's unclear: Whether `ActionText::Content` objects in this project embed image attachments as inline base64 or as `<action-text-attachment sgid="...">` references
   - Recommendation: Rake task should use `read_attribute(:body)` to avoid triggering Rails rendering pipeline during a production migration.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Node.js | npm install / esbuild build | Yes | 24.2.0 | — |
| npm | Package installation | Yes | 11.3.0 | — |
| Ruby | Rails / Rake task | Yes | 3.4.2 | — |
| Bundler | Gem management | Yes | 2.6.2 | — |
| PostgreSQL | Rails DB / migration | Yes | Accepting connections on port 5432 | — |
| `@tiptap/core` | Editor | Not yet installed | 3.23.2 (registry) | — |
| `@tailwindcss/typography` | WYSIWYG prose styles | Not yet installed | 0.5.19 (registry) | — |
| `trix` (remove) | Currently in package.json | Yes — to be removed | 2.1.15 | N/A |
| `@rails/actiontext` (remove) | Currently in package.json | Yes — to be removed | 8.1.100 | N/A |

**Missing dependencies with no fallback:**
- `@tiptap/core`, `@tiptap/starter-kit`, `@tiptap/extensions`, `@tailwindcss/typography` — must be installed before implementation

**Missing dependencies with fallback:**
- None.

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | Admin auth handled by Devise/BaseController — not changed |
| V3 Session Management | No | Not changed in this phase |
| V4 Access Control | No | Admin namespace auth unchanged |
| V5 Input Validation | Yes | `Rails::Html::SafeListSanitizer` in `before_save` (SEC-01) |
| V6 Cryptography | No | No crypto in this phase |
| V7 Error Handling | No | Not changed |

### Known Threat Patterns for This Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| XSS via stored HTML (blog body) | Tampering + Info Disclosure | `Rails::Html::SafeListSanitizer` in `before_save`; `raw @blog.body` only after sanitization at save |
| `</script>` injection in JSON-LD | Tampering | `json_escape(schema.to_json)` in all `content_tag :script` helpers |
| Editor-submitted arbitrary HTML | Spoofing | Never trust browser-side Tiptap output; always sanitize server-side before persistence |

**SEC-02 note:** The existing bug (`schema.to_json.html_safe`) is present in all four helper methods (`render_organization_schema`, `render_article_schema`, `render_product_schema`, `render_breadcrumbs_schema`). Fix all four — not just the three explicitly named in D-14.

---

## Sources

### Primary (HIGH confidence)

- Context7 `/ueberdosis/tiptap-docs` — Tiptap Editor initialization, commands API, history/undo-redo, placeholder extension, destroy lifecycle
- npm registry (via `npm view`) — Verified current versions: `@tiptap/core` 3.23.2, `@tiptap/starter-kit` 3.23.2, `@tiptap/extensions` 3.23.2, `@tailwindcss/typography` 0.5.19 (all confirmed 2026-05-13)
- `npm view @tiptap/starter-kit dependencies` — Confirmed Link extension is bundled; `"type": "module"` and dual ESM/CJS exports confirmed for all Tiptap 3.x packages
- Project codebase (direct file reads) — `app/models/blog.rb`, `app/javascript/application.js`, `app/helpers/application_helper.rb`, `app/views/admin/blogs/_form.html.erb`, `app/views/blogs/show.html.erb`, `app/views/layouts/admin.html.erb`, `db/schema.rb`, `package.json`, `spec/factories/blogs.rb`

### Secondary (MEDIUM confidence)

- WebFetch tailwindlabs/tailwindcss-typography README — `@plugin "@tailwindcss/typography"` syntax for Tailwind v4 confirmed
- WebFetch GitHub Discussion #14120 (tailwindlabs/tailwindcss) — Typography plugin v4 support confirmed with `@plugin` directive
- WebSearch + WebFetch betterstimulus.com/turbo/teardown — `turbo:before-cache` + `teardown()` pattern for Stimulus controllers
- WebSearch APIdock `json_escape` — `ERB::Util.json_escape` escapes `<`, `>`, `&` as Unicode sequences; result is NOT `html_safe`

### Tertiary (LOW confidence / training knowledge)

- Nokogiri `HTML.fragment` + CSS selector pattern for stripping ActionText attachment nodes — standard pattern [ASSUMED]; not verified against a live document in this session
- ActionText `read_attribute(:body)` vs `.to_s` distinction — inferred from migration code pattern [ASSUMED]

---

## Metadata

**Confidence breakdown:**
- Standard Stack: HIGH — npm registry confirmed all versions; ESM/CJS format confirmed
- Architecture: HIGH — direct codebase reads; Tiptap API confirmed via Context7
- Pitfalls: HIGH (layout, factory, seo_description, show page) — confirmed by direct code read; MEDIUM (Turbo caching) — confirmed via community pattern

**Research date:** 2026-05-13
**Valid until:** 2026-06-13 (Tiptap 3.x is actively maintained; re-verify if a major version ships)
