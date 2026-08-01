---
phase: "03-seo-fields-faq-schema"
plan: "01"
subsystem: "blog-seo"
tags:
  - rails
  - seo
  - jsonb
  - stimulus
  - keywords

dependency_graph:
  requires: []
  provides:
    - blogs.keywords jsonb column
    - blogs.faq_schema text column (stub for Plan 04)
    - blogs.canonical_url_override string column (stub for Plan 02)
    - Blog#has_one_attached :og_image (stub for Plan 03)
    - Blog#keywords_list helper method
    - keywords-input Stimulus controller
    - ApplicationHelper#page_keywords helper
    - page keywords meta tag in layout
  affects:
    - app/models/blog.rb
    - app/controllers/admin/blogs_controller.rb
    - app/controllers/blogs_controller.rb
    - app/helpers/application_helper.rb
    - app/views/layouts/application.html.erb
    - app/views/admin/blogs/_form.html.erb

tech_stack:
  added: []
  patterns:
    - jsonb column with Rails native serialization (no serialize call needed)
    - Stimulus controller with hidden field sync for array form params
    - document.createElement + textContent for XSS-safe chip rendering
    - ERB pre-render of existing chips on form load, Stimulus reads hidden inputs in connect()
    - before_save :normalize_keywords to strip blank array entries from form submit

key_files:
  created:
    - db/migrate/20260522000001_add_seo_fields_to_blogs.rb
    - app/javascript/controllers/keywords_input_controller.js
    - spec/requests/blogs_spec.rb
  modified:
    - db/schema.rb
    - app/models/blog.rb
    - app/controllers/admin/blogs_controller.rb
    - app/controllers/blogs_controller.rb
    - app/helpers/application_helper.rb
    - app/views/layouts/application.html.erb
    - app/views/admin/blogs/_form.html.erb
    - app/javascript/controllers/index.js
    - spec/models/blog_spec.rb
    - spec/requests/admin/blogs_spec.rb
    - spec/helpers/application_helper_spec.rb

decisions:
  - normalize_keywords before_save strips blank entries — handles Rails form empty array [""] edge case
  - chip remove button uses textContent not innerHTML throughout (XSS guard per CLAUDE.md + threat model T-03-05)

metrics:
  duration: "3 minutes"
  completed_date: "2026-05-22"
  tasks_completed: 3
  files_modified: 11
---

# Phase 3 Plan 1: SEO Keywords Slice — Summary

**One-liner:** End-to-end Keywords SEO slice: jsonb column + tag-chip Stimulus UI + `page_keywords` helper emitting conditional `<meta name="keywords">` on published blog pages.

## What Was Built

### Task 1: Migration + Blog Model Accessor Safety
- Created `db/migrate/20260522000001_add_seo_fields_to_blogs.rb` adding three columns: `keywords` (jsonb, default [], not null), `faq_schema` (text, nullable), `canonical_url_override` (string, nullable)
- Added `has_one_attached :og_image` to Blog model (unblocks Plan 03)
- Added `def keywords_list` returning `Array(keywords).join(", ")` — nil-safe via `Array()`
- Added `before_save :normalize_keywords` stripping blank entries from the keywords array (handles Rails form empty-array edge case where `[""]` is submitted)
- 12 model specs pass including 5 new `#keywords` describe block specs

### Task 2: Admin Form Chip Input + Stimulus Controller + Strong Params
- Created `app/javascript/controllers/keywords_input_controller.js` (57 lines) with:
  - `static targets = ["input", "chipContainer"]`
  - `connect()` reads pre-rendered hidden inputs into `_keywords` array, calls `renderChips()`
  - `addChip()` handles Enter/comma/Backspace key events
  - `removeChip()` splices by integer index from `data-index`
  - `renderChips()` uses `document.createElement` + `textContent` (never `innerHTML`) for XSS safety
- Registered `keywords-input` controller in `app/javascript/controllers/index.js`
- Added keywords chip widget to `app/views/admin/blogs/_form.html.erb` with ERB pre-render loop for existing values
- Updated `Admin::BlogsController#blog_params` to permit `keywords: []`
- `yarn build` exits 0; 6 request specs pass

### Task 3: Public Meta Tag Rendering
- Added `def page_keywords` to `ApplicationHelper` — returns nil when blank (handles nil and [] correctly)
- Inserted conditional `<meta name="keywords">` block after robots meta tag in `app/views/layouts/application.html.erb`
- Added `@page_keywords = @blog.keywords` to `BlogsController#show`
- 9 helper + request specs pass (3 page_keywords, 2 public blogs, 4 existing article schema)

## Commits

| Task | Type | Hash | Description |
|------|------|------|-------------|
| 1 RED | test | f96c68e | Failing specs for Blog#keywords and keywords_list |
| 1 GREEN | feat | b6935c8 | Migration, og_image attachment, keywords_list method |
| 2 RED | test | 27bf7cf | Failing request specs for keywords strong params |
| 2 GREEN | feat | ddcfbf0 | Stimulus controller, form UI, strong params |
| 3 RED | test | 141e6ef | Failing specs for page_keywords and public meta tag |
| 3 GREEN | feat | 7cc1c44 | Helper, layout insertion, controller assignment |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Rails form empty array sends `[""]` not `[]`**
- **Found during:** Task 2 — second request spec ("clears keywords when submitted as empty array") failed with `got: [""]`
- **Issue:** When a form submits `keywords: []`, Rails encodes it as `[""]` in the params. Without normalization, saving would store `[""]` instead of `[]`.
- **Fix:** Added `before_save :normalize_keywords` to Blog model that calls `Array(keywords).reject(&:blank?)` — strips blank strings before persistence.
- **Files modified:** `app/models/blog.rb`
- **Commit:** ddcfbf0 (included in Task 2 GREEN commit since the fix was discovered during Task 2 implementation)

## Known Stubs

| Stub | File | Reason |
|------|------|--------|
| `faq_schema` column added but not wired | db/schema.rb | Intentional — Plan 04 adds the FAQ builder form and `render_faq_schema` helper |
| `canonical_url_override` column added but not wired | db/schema.rb | Intentional — Plan 02 adds the form field, validation, and controller override |
| `has_one_attached :og_image` declared but not wired | app/models/blog.rb | Intentional — Plan 03 adds the form field and OG image fallback chain |

## Threat Surface Scan

No new threat surface beyond what the plan's threat model covered. All mitigations applied:

- T-03-01: Admin authentication enforced by `Admin::BaseController` (inherited)
- T-03-02: `keywords: []` strong params allows only array of scalars — verified in specs
- T-03-03: ERB auto-escapes `<%= page_keywords %>` in content attribute — no raw/html_safe
- T-03-05: `renderChips()` uses `document.createElement` + `textContent` throughout — never `innerHTML` for keyword values

## Self-Check

Files created:
- `db/migrate/20260522000001_add_seo_fields_to_blogs.rb` — FOUND
- `app/javascript/controllers/keywords_input_controller.js` — FOUND
- `spec/requests/blogs_spec.rb` — FOUND

Commits verified via `git log --oneline`:
- f96c68e, b6935c8, 27bf7cf, ddcfbf0, 141e6ef, 7cc1c44 — all FOUND

All 27 specs across plan files pass: 0 failures.

## Self-Check: PASSED
