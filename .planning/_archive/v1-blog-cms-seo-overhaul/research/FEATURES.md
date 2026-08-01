# Feature Landscape: Blog CMS with Tiptap

**Domain:** Rails admin blog CMS — Trix-to-Tiptap migration with author profiles and SEO schema
**Researched:** 2026-05-13
**Confidence note:** Tiptap extension API verified against training knowledge (cutoff Aug 2025). Extension names and npm package identifiers are HIGH confidence. Any Tiptap Pro/Cloud pricing tiers should be re-checked at tiptap.dev before implementation begins.

---

## Table Stakes

Features that any content-managed blog is expected to have. Missing = product feels broken or unprofessional.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Sticky toolbar | Standard in every modern editor (Notion, WordPress Gutenberg, Contentful) | Low | CSS-only `position: sticky; top: 0` on the toolbar div inside the editor wrapper |
| H1–H6 headings | Fundamental document structure | Low | `@tiptap/extension-heading` with `levels: [1,2,3,4,5,6]` |
| WYSIWYG heading preview | Without this headings are useless — user can't see what H2 looks like | Medium | CSS scoped to `.ProseMirror` mirroring the live `prose` classes |
| Bullet and numbered lists | Every writer expects these | Low | `@tiptap/extension-bullet-list` + `@tiptap/extension-ordered-list` + `@tiptap/extension-list-item` |
| Lists rendering correctly on live page | Tailwind prose reset strips default list styles | Low | Already solved by `.prose` — no custom work needed beyond using the right HTML output |
| Inline body images via ActiveStorage | Core to any blog content workflow | Medium | `@tiptap/extension-image` extended with a custom upload handler wired to the existing ActiveStorage direct-upload endpoint |
| Author attribution on post | Every blog shows who wrote it | Low (DB) / Medium (UI) | FK `author_id` on `blogs` + profile columns on `users`; card partial on show page |
| Meta title + meta description | Already exists; must continue working | None | Existing fields — no regression risk |

---

## Differentiators

Features that are not universally expected at this scale but provide meaningful SEO and editorial value.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Table support | Structured comparison content (pricing tables, feature lists) improves time-on-page and SEO relevance | Medium | `@tiptap/extension-table` + `@tiptap/extension-table-row` + `@tiptap/extension-table-cell` + `@tiptap/extension-table-header` — four packages, one coherent feature |
| Paragraph/line spacing control | Gives the marketing writer control over visual density without developer involvement | Medium-High | Two valid approaches — see detailed section below |
| FAQ schema (FAQPage JSON-LD) | Direct Google rich-result eligibility; FAQ accordions in SERPs can 3-5x CTR for informational queries | Medium | JSON stored in `faq_schema` column; UI is the complexity |
| Keywords meta field | Signals intent to Google (modest ranking factor, high value for internal taxonomy) | Low | Plain `string` column on `blogs`; `<meta name="keywords">` in head |
| Canonical URL override | Prevents duplicate content penalties when content is syndicated or re-dated | Low | Plain `string` column on `blogs`; overrides the default `request.original_url` in `canonical_url` helper |
| OG image override | Allows a post-specific social preview image separate from the cover photo | Low | `has_one_attached :og_image` on `Blog`; falls back to cover photo, then logo |
| Author Person JSON-LD schema | Elevates article schema to reference a real Person entity; Google uses this for author credibility signals in E-E-A-T | Low (once author model exists) | Replace the hardcoded `"@type": "Organization"` author block in `render_article_schema` |

---

## Anti-Features

Features to explicitly NOT build in this milestone.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Slash-command menu (like Notion `/`) | Significant JS complexity, no user request, overkill for one writer | Toolbar buttons only |
| Collaborative editing / real-time cursors | Requires Tiptap Cloud or a WebSocket backend; project has one user | Not applicable |
| Markdown import/export | Adds serialization complexity; HTML storage is the decision | Store HTML, done |
| Custom font picker | Visual inconsistency risk on live pages; Tailwind prose controls typography | Leave typography to CSS |
| Version history / revisions | Not requested; `published_at` blank = draft is sufficient | Defer indefinitely |
| Content scheduling | Explicitly out of scope in PROJECT.md | — |
| Public author profile pages | Explicitly out of scope | Author card on post only |
| Replacing ActionText on other models | Legal documents, case studies — out of scope | Leave Trix on those |

---

## Feature Deep Dives

### Feature 1: Sticky Toolbar

**Approach:** CSS-only. No Tiptap API involvement.

The editor wrapper is a `<div>` with relative positioning. The toolbar `<div>` inside it gets:

```css
.tiptap-toolbar {
  position: sticky;
  top: 0;
  z-index: 10;
  background: white;
  border-bottom: 1px solid #e5e7eb;
}
```

The Stimulus controller renders the toolbar and the `<div id="editor">` below it. Tiptap's `EditorContent` mounts to `#editor`. The toolbar stays in view as the user scrolls within the admin page.

**Table stakes.** Zero complexity. Do this on day one.

---

### Feature 2 + 3: H1–H6 Headings with WYSIWYG Preview

**Extension:** `@tiptap/extension-heading`

Configuration:
```js
Heading.configure({ levels: [1, 2, 3, 4, 5, 6] })
```

The extension outputs standard `<h1>` through `<h6>` tags. No custom HTML schema needed.

**WYSIWYG preview problem:** The admin uses Tailwind base reset which strips heading styles to unstyled text. The `.prose` class on the live page restores them, but the admin editor does NOT have `.prose` on the ProseMirror root.

**Solution:** Scope the Tailwind Typography prose styles directly to `.ProseMirror` inside the admin editor CSS. This is the standard approach — add a CSS block to the admin stylesheet:

```css
/* Apply prose-equivalent styles to the Tiptap editor root */
.tiptap-editor-container .ProseMirror {
  /* mirror prose-lg */
}
.tiptap-editor-container .ProseMirror h1 { @apply text-4xl font-bold mt-8 mb-4; }
.tiptap-editor-container .ProseMirror h2 { @apply text-3xl font-semibold mt-6 mb-3; }
.tiptap-editor-container .ProseMirror h3 { @apply text-2xl font-semibold mt-5 mb-2; }
.tiptap-editor-container .ProseMirror h4 { @apply text-xl font-medium mt-4 mb-2; }
.tiptap-editor-container .ProseMirror h5 { @apply text-lg font-medium mt-3 mb-1; }
.tiptap-editor-container .ProseMirror h6 { @apply text-base font-medium mt-2 mb-1; }
.tiptap-editor-container .ProseMirror p  { @apply text-base leading-7 mb-4; }
```

Alternatively, simply add the `prose prose-lg` class to the container div that wraps ProseMirror. This is the simplest path and guarantees the admin view matches the live page exactly. Preferred.

**Complexity:** Low.

---

### Feature 4: Lists (Bullet + Numbered)

**Extensions:**
- `@tiptap/extension-bullet-list`
- `@tiptap/extension-ordered-list`
- `@tiptap/extension-list-item`

These three always install together. Output is standard `<ul>`, `<ol>`, `<li>` HTML.

**Live page rendering:** Tailwind's base reset removes `list-style` from all elements. The `.prose` class in Tailwind Typography restores `list-disc` for `<ul>` and `list-decimal` for `<ol>` within prose containers. Since the show page already wraps content in `<div class="prose prose-lg max-w-none">`, lists render correctly without any additional work.

**Verification required at implementation:** Confirm that `@tailwindcss/typography` is installed and configured (the Tailwind 4 CLI build in `package.json` suggests it may need explicit addition — check `tailwind.config.js` or the CSS entry point for `@plugin "@tailwindcss/typography"`).

**Complexity:** Low.

---

### Feature 5: Table Support

**Extensions (four required, one coherent feature):**
- `@tiptap/extension-table`
- `@tiptap/extension-table-row`
- `@tiptap/extension-table-cell`
- `@tiptap/extension-table-header`

Configuration:
```js
Table.configure({ resizable: true })
```

`resizable: true` enables column width dragging. This requires the `prosemirror-tables` peer dependency, which the Tiptap table extension pulls in automatically.

**Output HTML:**
```html
<table>
  <tbody>
    <tr>
      <th>Header</th>
      <th>Header</th>
    </tr>
    <tr>
      <td>Cell</td>
      <td>Cell</td>
    </tr>
  </tbody>
</table>
```

**Live page rendering:** Tailwind Typography's `.prose` applies sensible table styles (borders, padding, alternating row colors) automatically. No custom CSS needed.

**Toolbar UX:** Add toolbar buttons for "Insert table", "Add row", "Delete row", "Add column", "Delete column". These call standard Tiptap table commands: `editor.chain().focus().insertTable({ rows: 3, cols: 3, withHeaderRow: true }).run()`.

**Complexity:** Medium. The table extension is stable but the toolbar UI for table manipulation (add/delete rows and columns, merge cells) requires a moderately involved Stimulus controller — roughly 150-200 lines of JS.

---

### Feature 6: Inline Body Images via ActiveStorage

**Extension:** `@tiptap/extension-image`

The base `Image` extension handles `<img>` nodes in the document. For uploads, it must be extended with a custom upload handler.

**Upload flow:**
1. User clicks "Insert image" in toolbar or drags/drops a file
2. Stimulus controller intercepts the file
3. Direct upload to ActiveStorage using the existing `@rails/activestorage` `DirectUpload` class (already a dependency via `@rails/actiontext`)
4. On completion, ActiveStorage returns a `signed_id`; Rails blob URL is constructed from it
5. `editor.chain().focus().setImage({ src: blob_url }).run()` inserts the image node
6. Tiptap stores `<img src="/rails/active_storage/blobs/...">` in the HTML body

**Rails side:** The existing ActiveStorage direct upload endpoint (`/rails/active_storage/direct_uploads`) handles the upload without any new controller code. A `BlobsController` or use of `rails_blob_url` is needed to serve the signed URL back to the JS — or simply construct it as `"/rails/active_storage/blobs/redirect/#{signed_id}/#{filename}"`.

**HTML sanitization:** When saving, `ActionController::Base.helpers.sanitize(body, tags: allowed_tags, attributes: allowed_attrs)` must explicitly allow `<img>` with `src`, `alt`, `width`, `height`. Without this, sanitization strips all images.

**Complexity:** Medium. The upload handler in the Stimulus controller is the main work (~80 lines). Sanitization allowlist is a gotcha.

---

### Feature 7: Paragraph/Line Spacing and Margin Control

This is the most architecturally contested feature. Two valid approaches:

#### Approach A: Tiptap Paragraph Attributes (custom extension)

Extend the built-in `Paragraph` extension to accept a `lineHeight` attribute:

```js
const CustomParagraph = Paragraph.extend({
  addAttributes() {
    return {
      lineHeight: {
        default: null,
        renderHTML: attributes => {
          if (!attributes.lineHeight) return {}
          return { style: `line-height: ${attributes.lineHeight}` }
        },
        parseHTML: element => element.style.lineHeight || null,
      },
      marginBottom: {
        default: null,
        renderHTML: attributes => {
          if (!attributes.marginBottom) return {}
          return { style: `margin-bottom: ${attributes.marginBottom}` }
        },
        parseHTML: element => element.style.marginBottom || null,
      },
    }
  },
})
```

Output: `<p style="line-height: 2; margin-bottom: 1.5rem">...</p>`

**Pros:** Granular per-paragraph control. Stored in the HTML body.
**Cons:** Inline styles can conflict with Tailwind's `prose` CSS specificity. The marketing writer has too many knobs — per-paragraph spacing is usually a design mistake in editorial content.

#### Approach B: CSS Class Approach (recommended)

Add a `spacing` attribute that applies a class rather than inline styles:

```js
renderHTML: attributes => ({ class: `spacing-${attributes.spacing}` })
```

Output: `<p class="spacing-relaxed">...</p>`

Define three fixed options in both admin and live-page CSS:
```css
.spacing-tight  p, p.spacing-tight  { line-height: 1.5; margin-bottom: 0.75rem; }
.spacing-normal p, p.spacing-normal { line-height: 1.75; margin-bottom: 1rem; }
.spacing-relaxed p, p.spacing-relaxed { line-height: 2; margin-bottom: 1.5rem; }
```

**Pros:** Constrained choices prevent layout chaos. CSS classes are not stripped by sanitizers (add them to the allowlist). Works with prose overrides cleanly.
**Cons:** Less granular — but that is a feature, not a bug, for an editorial CMS.

**Recommendation:** Use Approach B with a document-level (not per-paragraph) spacing selector. A single `<select>` field on the blog form ("Content spacing: Normal / Relaxed") sets a class on the outer wrapper div, not inside the Tiptap document at all. This is the simplest possible implementation and avoids Tiptap extension complexity entirely. Store it as a `body_spacing` string column on `blogs`.

**Complexity:** Low (document-level CSS class) to Medium (per-paragraph Tiptap attribute).

---

### Feature 8: Author Profile

#### DB Schema Recommendation

**Use columns on `users` table — do not create a separate `AuthorProfile` model.**

Rationale from PROJECT.md: "Reuse existing Devise user accounts rather than a separate Author model — simpler, no orphan risk." This is correct.

**New columns to add to `users` via migration:**

```ruby
add_column :users, :bio, :text
add_column :users, :job_title, :string       # "Head of Marketing", "Founder"
add_column :users, :linkedin_url, :string
add_column :users, :twitter_handle, :string  # store handle only, not full URL
# avatar via has_one_attached :avatar (already standard ActiveStorage pattern)
```

`first_name` and `last_name` already exist in the schema. No `display_name` needed — concatenate them.

**On `blogs` table:**

```ruby
add_column :blogs, :author_id, :bigint       # FK to users
add_foreign_key :blogs, :users, column: :author_id
add_index :blogs, :author_id
```

Remove the existing `author` string column once all posts are migrated (or keep it as fallback for legacy posts that pre-date the FK).

**Model associations:**

```ruby
# User
has_many :blogs, foreign_key: :author_id
has_one_attached :avatar

# Blog
belongs_to :author, class_name: "User", foreign_key: :author_id, optional: true
```

**`optional: true`** is important — existing posts have no `author_id` and must not fail validation.

**Admin form:** Replace the free-text `author` field with a `collection_select` scoped to users with admin role. The existing `roles` column (a serialized array) makes this: `User.where("roles LIKE ?", "%admin%")`.

**Author card on show page:** A `_author_card.html.erb` partial with avatar, name, job title, bio, and social links. Conditionally rendered when `@blog.author.present?`.

**Author Person JSON-LD:** Extend `render_article_schema` in `application_helper.rb` to emit:
```json
"author": {
  "@type": "Person",
  "name": "Jane Smith",
  "url": "https://linkedin.com/in/janesmith",
  "image": "<avatar_url>"
}
```
when `blog.author` is set, falling back to the existing `"@type": "Organization"` block for legacy posts.

**Complexity:** Low (DB + associations) / Medium (admin UI + card partial + schema update).

---

### Feature 9: Dynamic SEO Fields

#### 9a. Keywords

**Implementation:** Add `keywords` string column to `blogs`. Render as `<meta name="keywords" content="<%= @blog.keywords %>">` in the blog show layout head. Plain text input in the admin form with a hint: "Comma-separated".

**Complexity:** Low.

#### 9b. Canonical URL Override

**Implementation:** Add `canonical_url_override` string column to `blogs`. In `blogs_controller#show`, set `@canonical_url = @blog.canonical_url_override.presence || request.original_url.split("?").first`. The existing `canonical_url` helper in `ApplicationHelper` already references `@canonical_url`, so this works without modifying the helper.

**Complexity:** Low.

#### 9c. OG Image Override

**Implementation:** `has_one_attached :og_image` on `Blog`. In `blogs_controller#show`, set `@page_og_image` to the OG image URL if attached, else fall back to cover photo, else logo. The existing `page_og_image` helper already checks `@page_og_image`.

**Complexity:** Low.

#### 9d. FAQ Schema (FAQPage JSON-LD)

This is the most complex SEO feature.

**Storage:** `faq_schema` text column on `blogs`, serialized as JSON array: `[{ "question": "...", "answer": "..." }]`. The PROJECT.md decision to use this approach is correct.

```ruby
# Blog model
serialize :faq_schema, coder: JSON
```

Or use a plain JSON column if PostgreSQL is available (it is — schema shows Postgres):
```ruby
add_column :blogs, :faq_schema, :jsonb, default: []
```

**Recommended UX pattern: Stimulus + vanilla JS dynamic fields** (not Turbo Frames)

Turbo Frames are appropriate for server-side-driven dynamic content. FAQ Q&A entry is a client-side-only form manipulation problem — adding/removing field pairs from a list in the admin form. Turbo would add unnecessary round trips.

The pattern:

1. Hidden `<template>` element contains the Q&A field pair HTML
2. "Add FAQ" button clones the template and appends to a container
3. "Remove" button on each pair deletes its parent row
4. On form submit, a Stimulus controller serializes all Q&A pairs from the DOM into a hidden `faq_schema` input as JSON
5. Rails receives the JSON string, the model deserializes it

```js
// faq_controller.js (Stimulus)
addQuestion() {
  const template = this.templateTarget.content.cloneNode(true)
  const index = this.questionTargets.length
  // update name attributes with index
  this.listTarget.appendChild(template)
}

removeQuestion(event) {
  event.currentTarget.closest('[data-faq-target="pair"]').remove()
}

serialize() {
  const pairs = this.pairTargets.map(pair => ({
    question: pair.querySelector('[data-field="question"]').value,
    answer: pair.querySelector('[data-field="answer"]').value,
  }))
  this.outputTarget.value = JSON.stringify(pairs)
}
```

**Validation:** Validate that questions and answers are non-empty before accepting in the model. Strip empty pairs before serializing.

**JSON-LD output:** A new helper method `render_faq_schema(blog)`:

```ruby
def render_faq_schema(blog)
  return unless blog.faq_schema.present? && blog.faq_schema.any?

  schema = {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    "mainEntity": blog.faq_schema.map do |pair|
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

  content_tag :script, schema.to_json.html_safe, type: "application/ld+json"
end
```

Called in `blogs/show.html.erb` inside `content_for :structured_data`.

**Complexity:** Medium. The Stimulus JS controller is ~60 lines. The Rails helper is trivial. The form partial for the FAQ pairs needs care to avoid name attribute collisions with the main blog form.

---

## Feature Dependencies

```
Tiptap base setup (Stimulus controller + npm packages)
  → Sticky toolbar          (CSS only, no deps)
  → H1-H6 headings          (requires base setup)
  → Lists                   (requires base setup)
  → Tables                  (requires base setup + heading done first for toolbar ordering)
  → Inline images           (requires base setup + ActiveStorage direct-upload knowledge)

Author FK (blogs.author_id migration)
  → Author profile columns on users (independent, but migrate together)
  → Author card partial             (requires both above)
  → Author JSON-LD                  (requires author card work done)

FAQ schema column (blogs.faq_schema)
  → Stimulus FAQ controller         (requires column exists)
  → FAQPage JSON-LD helper          (requires FAQ controller done)

keywords / canonical_url_override / og_image
  → Independent of each other; all require only a migration
```

---

## Live Page Rendering with Tailwind Prose

The show page already wraps content in:
```erb
<div class="prose prose-lg max-w-none mb-16">
  <%= @blog.content %>
</div>
```

After migration, this becomes:
```erb
<div class="prose prose-lg max-w-none mb-16">
  <%= raw sanitize(@blog.body, tags: allowed_tags, attributes: allowed_attrs) %>
</div>
```

**What `.prose` gives for free (no extra work):**
- `h1`–`h6`: appropriate sizes, weights, margins
- `ul` / `ol` / `li`: bullets and numbers restored with correct indentation
- `table` / `th` / `td`: borders, padding, striped rows
- `p`: readable line-height and margin
- `img`: max-width: 100%, appropriate margins
- `a`: link color and underline
- `code` / `pre`: monospace with background
- `blockquote`: left border and italic style

**The only customization needed:** Override Tailwind Typography defaults that conflict with the site's design system (link color, heading colors). This is done via `prose-pink` modifier or custom CSS overrides in the application stylesheet — already present based on the existing use of `prose prose-lg`.

**IMPORTANT — Tailwind 4 difference:** The project uses Tailwind CSS 4 (from `package.json`). In Tailwind 4, Typography plugin configuration uses `@plugin "@tailwindcss/typography"` in the CSS entry point, not in `tailwind.config.js`. Verify this is present in `app/assets/stylesheets/application.tailwind.css` before assuming prose classes work. If `@tailwindcss/typography` is not in `package.json` dependencies, it must be installed.

**Sanitization allowlist for `raw`-free rendering:**

Rather than `raw`, use Rails' built-in sanitizer with an explicit allowlist. Define it in `Blog` or `ApplicationHelper`:

```ruby
ALLOWED_TIPTAP_TAGS = %w[
  h1 h2 h3 h4 h5 h6
  p br strong em u s
  ul ol li
  blockquote
  table thead tbody tr th td
  img
  a
  code pre
  figure figcaption
].freeze

ALLOWED_TIPTAP_ATTRS = %w[
  href src alt title class style
  width height
  target rel
  colspan rowspan
  data-type
].freeze
```

This is safer than `raw` and handles untrusted HTML correctly.

---

## MVP Recommendation

**Phase 1 — Editor foundation (highest leverage, unlocks everything else):**
1. Install Tiptap packages, create Stimulus controller, wire to blog form
2. Sticky toolbar (CSS)
3. H1–H6 with WYSIWYG preview (CSS on `.ProseMirror`)
4. Bullet and numbered lists
5. Swap `rich_text_area :content` for `hidden_field :body` populated by Tiptap
6. Update show page to use `sanitize(@blog.body, ...)`

**Phase 2 — Rich content (tables + images):**
7. Table support with toolbar controls
8. Inline image upload via ActiveStorage

**Phase 3 — Author profiles:**
9. Migration: `users` author columns, `blogs.author_id` FK
10. Admin form: select user as author
11. Author card partial on show page
12. Author Person JSON-LD

**Phase 4 — SEO fields:**
13. Keywords, canonical URL override, OG image override (all low complexity, batch together)
14. FAQ schema: Stimulus controller, admin form, FAQPage JSON-LD helper

**Defer:**
- `body_spacing` control: useful but not blocking. Add after editor is stable.
- Spacing is a nice-to-have; the marketing writer can use headings and paragraph breaks for visual rhythm in the interim.

---

## Sources

All Tiptap extension information is from training knowledge (Tiptap v2.x, cutoff August 2025). Confidence: HIGH for extension names and API surface. MEDIUM for any Pro-tier extension gating — verify at `https://tiptap.dev/docs/editor/extensions/overview` that all extensions listed here are in the free OSS tier before starting implementation.

Schema.org FAQPage spec: HIGH confidence — this is a stable, long-running schema type.
Tailwind Typography behavior: HIGH confidence for v3 behavior; MEDIUM for Tailwind 4 plugin import syntax — verify the `@plugin` directive is present in the CSS entry point.
Rails ActiveStorage direct upload API: HIGH confidence — stable since Rails 5.2.
