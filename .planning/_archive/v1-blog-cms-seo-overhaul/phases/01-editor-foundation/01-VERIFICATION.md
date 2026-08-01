---
phase: 01-editor-foundation
verified: 2026-05-14T00:00:00Z
status: human_needed
score: 7/8 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Verify bullet and numbered lists render correctly on published pages with Tailwind Typography prose classes"
    expected: "Bullet list shows disc markers; numbered list shows numeric markers on live /blog/:slug page for a post with list content"
    why_human: "This is a visual rendering check on the public-facing page requiring a running dev server"
  - test: "Verify heading styles inside editor match the live page appearance (WYSIWYG parity)"
    expected: "H2 inside the editor area visually renders larger and bolder than paragraph text, matching the prose-lg scale of the public show page"
    why_human: "CSS parity between editor and public page requires visual inspection in a browser; the CSS scoping rule exists but only a human can confirm the rendered sizes match"
---

# Phase 01: Editor Foundation Verification Report

**Phase Goal:** Replace Trix/ActionText editor with Tiptap, persist sanitized HTML in blogs.body, render on public page — with full toolbar, server-side sanitization, and backfill Rake task.
**Verified:** 2026-05-14
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Admin can open any blog post and see the Tiptap editor in place of the Trix/ActionText editor | VERIFIED | `_form.html.erb` line 86: `data-controller="tiptap-editor"` replaces `rich_text_area :content`; no `has_rich_text :content` in `blog.rb`; no `import "trix"` in `application.js` |
| 2 | Toolbar stays visible (sticky) while scrolling a long post in the editor | VERIFIED | `_form.html.erb` line 87: `class="tiptap-toolbar sticky top-0 z-10 bg-white ..."` confirmed in code |
| 3 | Admin can apply H1 through H6 headings and heading styles match the live page appearance inside the editor | VERIFIED (code) / ? (visual parity) | ERB loop `[1,2,3,4,5,6].each` generates 6 heading buttons with `data-tiptap-state="heading:<level>"` and `data-tiptap-editor-level-param`; `.tiptap-editor .ProseMirror { @apply prose max-w-none ... }` CSS rule in `application.tailwind.css` applies prose styles inside editor; visual parity needs human |
| 4 | Bullet and numbered lists render correctly on published pages using Tailwind Typography prose classes | ? UNCERTAIN | `show.html.erb` line 61: `<div class="prose prose-lg max-w-none mb-16">` is present with `sanitize @blog.body`; CSS config has `@plugin "@tailwindcss/typography"` — list rendering needs human visual check on live page |
| 5 | All pre-existing blog content is readable and intact after migration; no `<action-text-attachment>` nodes remain in the body column | VERIFIED (code) | `lib/tasks/blogs.rake`: `doc.css("action-text-attachment").each(&:remove)` present; task is idempotent with `if blog.body.present?` skip guard; `bundle exec rake -T blogs` would list `blogs:migrate_body`; actual data state requires human to confirm Task 2 of Plan 03 was run |
| 6 | `blogs.body` TEXT column exists and sanitized HTML is persisted on save via `Rails::Html::SafeListSanitizer` | VERIFIED | `db/schema.rb` line 134: `t.text "body"` under blogs table; `blog.rb` lines 12, 45-50: `before_save :sanitize_body` calls `Rails::Html::SafeListSanitizer.new.sanitize(...)` |
| 7 | SEC-01: XSS tags stripped on save; SEC-02: JSON-LD helpers use json_escape | VERIFIED | `blog.rb` `sanitize_body` method confirmed; `application_helper.rb` has 4 occurrences of `json_escape(schema.to_json)`, 0 occurrences of `.to_json.html_safe` |
| 8 | No code references `blog.content`, `@blog.content`, or `has_rich_text :content` in `app/` or `lib/` | VERIFIED | `grep -rn "has_rich_text :content|@blog\.content\b|blog\.content\b|rich_text_area :content" app/ lib/` returns only `app/views/admin/legal_documents/_form.html.erb:66` (unrelated LegalDocument form, not Blog) |

**Score:** 7/8 truths verified (1 needs human visual confirmation)

### Deferred Items

None — all success criteria from ROADMAP are addressed within this phase.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `db/migrate/20260513121220_add_body_to_blogs.rb` | Schema migration adding blogs.body text column | VERIFIED | File exists; `db/schema.rb` confirms `t.text "body"` at line 134 in blogs table |
| `app/models/blog.rb` | Blog model with body validation, sanitize_body before_save, no has_rich_text | VERIFIED | `validates :title, :body, presence: true`; `before_save :sanitize_body`; `sanitize_body` private method using `Rails::Html::SafeListSanitizer`; no `has_rich_text :content` |
| `app/javascript/controllers/tiptap_editor_controller.js` | Stimulus controller, min 40 lines, with editor + input targets | VERIFIED | 148 lines; imports `@tiptap/core`, `@tiptap/starter-kit`, `@tiptap/extensions`, `@hotwired/stimulus`, `@tiptap/extension-underline`, `@tiptap/extension-link`; `static targets = ["editor", "input"]`; full lifecycle + toolbar methods present |
| `app/views/admin/blogs/_form.html.erb` | Form with Tiptap container, data-controller=tiptap-editor | VERIFIED | Line 86: `data-controller="tiptap-editor"`; editor target at line 280; hidden input at line 284 |
| `app/views/blogs/show.html.erb` | Public show page renders @blog.body inside .prose.prose-lg | VERIFIED (with deviation) | Line 61-63: `<div class="prose prose-lg max-w-none mb-16">` wrapping `<%= sanitize @blog.body, tags: Blog::ALLOWED_TAGS, attributes: Blog::ALLOWED_ATTRIBUTES %>` — deviates from plan's `raw @blog.body` (see Deviations section; deviation is strictly safer) |
| `spec/factories/blogs.rb` | Factory using body attribute, not content | VERIFIED | Line 5: `body { "<p>Blog post content with lots of interesting information.</p>" }`; no `content {` attribute |
| `lib/tasks/blogs.rake` | blogs:migrate_body Rake task, min 30 lines | VERIFIED | 45 lines; namespace, desc, task, idempotent guard, ActionText lookup, Nokogiri strip, update_column, progress output all confirmed |
| `app/helpers/application_helper.rb` | All four JSON-LD helpers use json_escape | VERIFIED | 4 occurrences of `json_escape(schema.to_json)`; 0 occurrences of `.to_json.html_safe` |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `_form.html.erb` | `tiptap_editor_controller.js` | `data-controller="tiptap-editor"` + `data-tiptap-editor-target="editor"` + `data-tiptap-editor-target="input"` | WIRED | editor target at line 280; input target at line 284; controller registered in `index.js` line 11 |
| `tiptap_editor_controller.js` | `input[name="blog[body]"]` | `onUpdate` callback: `this.inputTarget.value = editor.getHTML()` | WIRED | Line 28: `this.inputTarget.value = editor.getHTML()` confirmed |
| `admin/blogs_controller.rb` | `blog.rb#sanitize_body` | `:body` permitted in strong params triggers `before_save :sanitize_body` | WIRED | Controller permits `:body`; model has `before_save :sanitize_body` |
| `blog.rb` | `blogs.body column` | `Rails::Html::SafeListSanitizer.new.sanitize(...)` assigned to `self.body` | WIRED | Lines 45-50 in `blog.rb` confirmed |
| `show.html.erb` | `blogs.body column` | `sanitize @blog.body` inside `<div class="prose prose-lg max-w-none mb-16">` | WIRED | Line 62 confirmed; uses `sanitize` helper (double-sanitization; see Deviations) |
| `lib/tasks/blogs.rake` | `action_text_rich_texts` | `ActionText::RichText.find_by(record_type: "Blog", record_id: blog.id, name: "content")` | WIRED | Lines 17-21 confirmed |
| `lib/tasks/blogs.rake` | `blogs.body column` | `blog.update_column(:body, sanitized_html)` | WIRED | Line 38 confirmed |
| `lib/tasks/blogs.rake` | raw Trix HTML | `rich_text.read_attribute(:body)` | WIRED | Line 29 confirmed |
| `app/helpers/application_helper.rb` | `<script type="application/ld+json">` payload | `json_escape(schema.to_json)` in all 4 helpers | WIRED | 4 occurrences confirmed |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|-------------------|--------|
| `show.html.erb` | `@blog.body` | `blogs.body` TEXT column, written by `sanitize_body` before_save callback | Yes — DB column populated by save or rake task | FLOWING |
| `_form.html.erb` | `inputTarget.value` | `blog.body` from DB on edit; empty on new; set by `editor.getHTML()` on every keystroke | Yes — initial value from `this.inputTarget.value` in `connect()`; updates on `onUpdate` | FLOWING |
| `application_helper.rb` | `schema.to_json` | Blog/Product model fields from DB (title, description, etc.) | Yes — model attribute reads | FLOWING |

### Behavioral Spot-Checks

Step 7b: SKIPPED — requires running server for admin/blog form interaction. CLI-verifiable items checked via grep patterns above.

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| `trix` absent from package.json | `grep "trix" package.json` | No output (exit 0) | PASS |
| `@rails/actiontext` absent from package.json | `grep "@rails/actiontext" package.json` | No output (exit 0) | PASS |
| Tiptap packages present | `grep "@tiptap/core\|@tiptap/starter-kit" package.json` | Both found at ^3.23.2 | PASS |
| No `import "trix"` in application.js | `grep "trix\|actiontext" application.js` | No output | PASS |
| json_escape count = 4 | `grep -c "json_escape(schema.to_json)" application_helper.rb` | 4 | PASS |
| No `.to_json.html_safe` remaining | `grep "schema.to_json.html_safe" application_helper.rb` | No output | PASS |
| blogs.body column in schema | `grep "body" db/schema.rb` | `t.text "body"` at line 134 | PASS |
| Rake task file exists | `test -f lib/tasks/blogs.rake` | File present, 45 lines | PASS |

### Probe Execution

No probe scripts found in `scripts/*/tests/probe-*.sh`. Step 7c: SKIPPED.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|---------|
| EDIT-01 | 01-01-PLAN.md | Admin can compose blog content in Tiptap editor; content stored as sanitized HTML in `blogs.body` | SATISFIED | Tiptap controller wired; `blogs.body` column exists; sanitization confirmed |
| EDIT-02 | 01-02-PLAN.md | Editor toolbar remains fixed/sticky while admin scrolls long posts | SATISFIED | `sticky top-0 z-10` class on toolbar wrapper confirmed |
| EDIT-03 | 01-02-PLAN.md | Admin can apply H1–H6 headings from toolbar | SATISFIED | ERB loop generates 6 heading buttons with `data-tiptap-editor-level-param` and `setHeading` action; `toggleHeading({level})` wired in controller |
| EDIT-04 | 01-01-PLAN.md | Heading styles render visually inside editor matching live page appearance (WYSIWYG) | NEEDS HUMAN | `.tiptap-editor .ProseMirror { @apply prose max-w-none ... }` CSS rule present; visual parity needs browser inspection |
| EDIT-05 | 01-01-PLAN.md | Bullet and numbered lists render correctly on live published pages | NEEDS HUMAN | Prose wrapper (`prose prose-lg max-w-none`) present; `@tailwindcss/typography` registered; visual rendering needs live page check |
| EDIT-06 | 01-03-PLAN.md | Existing blog content migrated from ActionText to body column; no `<action-text-attachment>` nodes | SATISFIED (code) | Rake task fully implemented with Nokogiri strip; idempotent; runs via `bundle exec rake blogs:migrate_body` |
| SEC-01 | 01-01-PLAN.md | Blog body HTML sanitized server-side via `Rails::Html::SafeListSanitizer` before saving | SATISFIED | `before_save :sanitize_body` confirmed; sanitizer call confirmed |
| SEC-02 | 01-02-PLAN.md | All JSON-LD `<script>` tags use `json_escape` | SATISFIED | 4 occurrences of `json_escape(schema.to_json)` confirmed; zero `.to_json.html_safe` remaining |

**Orphaned requirements check:** REQUIREMENTS.md traceability table maps EDIT-01 through EDIT-06, SEC-01, SEC-02 to Phase 1. All 8 IDs are claimed by the 3 plans. No orphaned requirements.

**Note on REQUIREMENTS.md status flags:** `EDIT-01`, `EDIT-04`, `EDIT-05`, `SEC-01` still show as `[ ]` (Pending) in REQUIREMENTS.md, but EDIT-01 and SEC-01 are demonstrably implemented in code. This is a documentation state inconsistency, not a code gap — the REQUIREMENTS.md was not updated to reflect completion after the phase ran.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `app/models/blog.rb` | 5-6 | `ALLOWED_TAGS` includes `img, figure, figcaption`; `ALLOWED_ATTRIBUTES` includes `src, alt, width, height` beyond the plan's specification | Info | Deviation from plan spec (which specified only `p br h1..h6 ul ol li strong em a blockquote code pre` and `href target rel`). Image-permissive tags/attributes are intentional and defensible since image elements are likely needed for migrated content from Trix. Not a security regression — attributes remain whitelisted. The rake task also explicitly sanitizes through the model's ALLOWED_TAGS. |
| `app/views/blogs/show.html.erb` | 62 | `<%= sanitize @blog.body, tags: Blog::ALLOWED_TAGS, attributes: Blog::ALLOWED_ATTRIBUTES %>` instead of plan-specified `<%= raw @blog.body %>` | Info | Deviation from plan spec. The implementation uses Rails `sanitize` helper at render time in addition to the `before_save` sanitization. This is strictly safer (defense in depth) — double-sanitization is not harmful. However, it means the view renders body through two sanitization passes rather than trusting the pre-sanitized body. The plan's rationale for `raw` was that sanitization at save time is sufficient. |
| `lib/tasks/blogs.rake` | 35-38 | Rake task runs `Rails::Html::SafeListSanitizer` in addition to Nokogiri strip, contradicting Plan 03's spec which says to bypass sanitize_body | Warning | Plan 03 explicitly specified `update_column(:body, clean_html)` to bypass `before_save :sanitize_body`. The actual implementation adds an extra manual `sanitizer.sanitize(...)` call before `update_column`. This is safe but deviates from the plan's "trusted source" rationale. The deviation is benign but it also means if `Blog::ALLOWED_TAGS` expands in the future, backfill results might differ from migration-era intent. |

No `TBD`, `FIXME`, or `XXX` debt markers found in any phase-modified file.

### Human Verification Required

#### 1. Bullet and Numbered List Rendering on Public Page (EDIT-05)

**Test:** Create or view a published blog post that contains a bullet list and a numbered list. Visit the public `/blog/:slug` URL.
**Expected:** Bullet list renders with disc markers; numbered list renders with numeric sequence markers. Both styled correctly via Tailwind Typography `prose-lg` class.
**Why human:** Visual CSS rendering — `prose prose-lg` wrapper and `@tailwindcss/typography` plugin are configured, but the actual rendered output requires browser inspection.

#### 2. WYSIWYG Heading Parity — Editor vs. Public Page (EDIT-04)

**Test:** Open `/admin/blogs/new`. Click into the editor. Type "Test heading" and click H2. Compare the visual size and weight of the heading in the editor to the same heading on a published post's `/blog/:slug` page.
**Expected:** H2 in the editor area and H2 on the public page render at the same visual scale (Tailwind Typography `prose-lg` applied to both via `.tiptap-editor .ProseMirror` CSS rule and `.prose.prose-lg` on the public show page wrapper).
**Why human:** CSS parity requires side-by-side visual comparison. The scoping rule (`.tiptap-editor .ProseMirror`) exists in `application.tailwind.css`, but whether it fully matches `prose-lg` sizing on the public side depends on whether the typography plugin computes identically for both contexts.

#### 3. Rake Task Backfill Execution Confirmation (EDIT-06 data state)

**Test:** Run `bundle exec rake blogs:migrate_body` against the development database if any blogs existed before the Tiptap migration. Then verify with `bin/rails runner 'puts Blog.where("body LIKE ?", "%action-text-attachment%").count'`.
**Expected:** Output is 0 (no action-text-attachment nodes remain). Task should also show idempotent behavior on a second run.
**Why human:** Cannot verify data state in the database without a live Rails environment.

### Gaps Summary

No blocking gaps found. The phase goal is substantively achieved:

- Tiptap editor replaces Trix/ActionText end-to-end in code
- `blogs.body` column exists with server-side sanitization
- Full toolbar (21 buttons across 8 groups) is implemented
- JSON-LD security fix applied to all 4 helpers
- Backfill Rake task is implemented and structurally sound

Three items need human confirmation before the phase can be marked fully complete:
1. Visual rendering of lists on the public page (EDIT-05)
2. WYSIWYG heading parity between editor and public page (EDIT-04)
3. Actual database state after running the Rake backfill (EDIT-06 data)

Two deviations from plan specs are present but both are strictly safer or equivalent:
- `show.html.erb` uses `sanitize` helper instead of `raw` (defense in depth — not a gap)
- `ALLOWED_TAGS`/`ALLOWED_ATTRIBUTES` expanded to include image-related tags (intentional for Trix migration compatibility)
- Rake task adds an extra sanitization pass before `update_column` (safe but deviates from plan's rationale)

---

_Verified: 2026-05-14_
_Verifier: Claude (gsd-verifier)_
