---
phase: 01-editor-foundation
plan: "01"
subsystem: editor
tags: [tiptap, stimulus, rails-8, sanitization, walking-skeleton]
dependency_graph:
  requires: []
  provides: [blogs.body column, tiptap-editor stimulus controller, server-side HTML sanitization]
  affects: [app/models/blog.rb, app/controllers/admin/blogs_controller.rb, app/views/admin/blogs/_form.html.erb, app/views/blogs/show.html.erb]
tech_stack:
  added: ["@tiptap/core ^3.23.2", "@tiptap/starter-kit ^3.23.2", "@tiptap/extensions ^3.23.2", "@tailwindcss/typography ^0.5.19"]
  removed: ["trix ^2.1.15", "@rails/actiontext ^8.1.100"]
  patterns: [Stimulus controller with lifecycle teardown, Rails::Html::SafeListSanitizer before_save, Turbo turbo:before-cache listener]
key_files:
  created:
    - db/migrate/20260513121220_add_body_to_blogs.rb
    - app/javascript/controllers/tiptap_editor_controller.js
  modified:
    - package.json
    - package-lock.json
    - yarn.lock
    - db/schema.rb
    - app/javascript/application.js
    - app/assets/stylesheets/application.tailwind.css
    - app/javascript/controllers/index.js
    - app/models/blog.rb
    - app/controllers/admin/blogs_controller.rb
    - app/views/admin/blogs/_form.html.erb
    - app/views/blogs/show.html.erb
    - spec/factories/blogs.rb
decisions:
  - "sticky top-0 (not top-16): admin header is position:static so no offset needed for toolbar"
  - "ALLOWED_TAGS includes standard prose elements; javascript: URLs stripped automatically by Rails sanitizer"
  - "turbo:before-cache listener added to application.js to call teardown() on Stimulus controllers before caching"
metrics:
  duration: "~25 minutes"
  completed: "2026-05-13"
  tasks_completed: 3
  tasks_total: 4
  files_created: 2
  files_modified: 12
---

# Phase 1 Plan 01: Tiptap Walking Skeleton Summary

**One-liner:** Trix/ActionText replaced with Tiptap 3.x Stimulus controller storing sanitized HTML in `blogs.body` text column via `Rails::Html::SafeListSanitizer`.

## What Was Implemented

### Task 1 — npm swap, migration, entry-point cleanup (commit 751206a)

- Installed `@tiptap/core`, `@tiptap/starter-kit`, `@tiptap/extensions`, `@tailwindcss/typography`
- Removed `trix` and `@rails/actiontext` from npm dependencies
- Generated and ran `AddBodyToBlogs` migration adding `t.text "body"` (nullable, no default) to the `blogs` table
- Removed `import "trix"` and `import "@rails/actiontext"` from `application.js`
- Added `turbo:before-cache` listener that calls `c.teardown()` on any Stimulus controller exposing that method — prevents orphaned Tiptap DOM nodes when Turbo caches pages
- Replaced `@import "./actiontext.css"` with `@plugin "@tailwindcss/typography"` in `application.tailwind.css`; removed `.trix-content a` rule
- Both `npm run build` and `npm run build:css` exit 0 with no resolution errors

### Task 2 — Tiptap Stimulus controller + form replacement (commit 42a1be3)

- Created `app/javascript/controllers/tiptap_editor_controller.js` with:
  - `static targets = ["editor", "input"]`
  - `connect()` instantiates `new Editor` with `StarterKit` (heading levels 1-6) and `Placeholder` extension
  - `onUpdate` writes `editor.getHTML()` to `this.inputTarget.value` on every keystroke
  - `onSelectionUpdate` and `onTransaction` update toolbar active-state via `updateToolbarState()`
  - `disconnect()` and `teardown()` both call `editor.destroy()` (Turbo-safe)
  - Toolbar methods: `toggleBold`, `setHeading(event)`, `toggleBulletList`, `toggleOrderedList`
  - `updateToolbarState()` toggles `aria-pressed` and `bg-pink-50 text-pink-700` on `[data-tiptap-state]` buttons
- Registered as `"tiptap-editor"` in `controllers/index.js`
- Replaced `form.rich_text_area :content` with Tiptap container in `admin/blogs/_form.html.erb`:
  - Toolbar: H1, H2, Bold, Bullet List, Ordered List buttons (`type="button"`, `data-tiptap-state`, `aria-pressed`)
  - Toolbar uses `sticky top-0 z-10` (not `top-16`) — admin header is `position: static`
  - Editor div: `ProseMirror prose prose-lg max-w-none min-h-[400px]` with `data-tiptap-editor-target="editor"`
  - Hidden input via `form.hidden_field :body, data: { tiptap_editor_target: "input" }` — Rails generates `name="blog[body]"`
- esbuild bundle grows from 218.5kb → 568.8kb confirming Tiptap bundled correctly

### Task 3 — Blog model, strong params, factory, show page (commit 6771503)

- `Blog` model changes:
  - Removed `has_rich_text :content`
  - Changed `validates :title, :content` to `validates :title, :body, presence: true`
  - Added `ALLOWED_TAGS` and `ALLOWED_ATTRIBUTES` frozen constants (SEC-01)
  - Added `before_save :sanitize_body` callback
  - Updated `seo_description` to call `strip_tags(body)` (was `strip_tags(content)`)
  - Added private `sanitize_body` method using `Rails::Html::SafeListSanitizer`
- `AdminBlogsController#blog_params` now permits `:body` (not `:content`)
- `blogs/show.html.erb` line 62: `<%= raw @blog.body %>` (inside existing `.prose.prose-lg` wrapper)
- `spec/factories/blogs.rb`: `body { "<p>Blog post content with lots of interesting information.</p>" }`
- Full codebase audit: zero references to `@blog.content`, `blog.content`, or `has_rich_text :content` in `app/` or `lib/`
- Admin blogs request spec: 1 example, 0 failures
- Smoke test: `Blog.new(title: "Smoke", body: "<p>ok</p><script>x</script>").save!` → persisted body is `<p>ok</p>` (script stripped)

### Task 4 — Checkpoint (awaiting manual verification)

The walking skeleton is code-complete. Task 4 requires manual end-to-end smoke verification in a live dev environment by the operator.

## Deviations from Plan

None. Plan executed exactly as written.

Notable implementation choices confirmed against the plan:
- `sticky top-0` (not `top-16`) per RESEARCH Pitfall 1 — admin header is `position: static`
- `@tiptap/extensions` version 3.23.2 resolved by npm — compatible with `@tiptap/core` 3.23.2
- No blog_spec.rb exists in the repo yet (not created by this plan); the plan's acceptance criterion "existing tests pass" was verified via the admin request spec which uses `create(:blog)`

## Known Stubs

None — the implementation is functionally complete for the walking skeleton scope. The public show page renders blank for existing blogs (body is nil until Plan 03's Rake backfill runs) — this is intentional and documented in the plan.

## Threat Flags

No new threat surface beyond what is documented in the plan's threat model.

- T-01-01: `before_save :sanitize_body` implemented and smoke-tested (PASS)
- T-01-02: `raw @blog.body` used only after server-side sanitization (PASS)
- T-01-03: No `html_safe` on user input before sanitization (PASS)
- T-01-04: `ALLOWED_ATTRIBUTES = %w[href target rel]` — no `style` or `class` (PASS)

## Follow-ups (Planned)

- **Plan 02:** Full toolbar (H3-H6, italic, strike, link, undo/redo, disabled table/image stubs), sticky offset verification, editor scoping styles
- **Plan 03:** Rake task to backfill existing `action_text_rich_texts` rows into `blogs.body` column

## Self-Check: PASSED

| Item | Status |
|------|--------|
| app/javascript/controllers/tiptap_editor_controller.js | FOUND |
| db/migrate/20260513121220_add_body_to_blogs.rb | FOUND |
| app/models/blog.rb | FOUND |
| app/views/admin/blogs/_form.html.erb | FOUND |
| app/views/blogs/show.html.erb | FOUND |
| spec/factories/blogs.rb | FOUND |
| commit 751206a (Task 1) | FOUND |
| commit 42a1be3 (Task 2) | FOUND |
| commit 6771503 (Task 3) | FOUND |
