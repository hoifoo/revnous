---
phase: 03-seo-fields-faq-schema
plan: "02"
subsystem: blog-seo
tags:
  - rails
  - seo
  - validation
  - canonical

# Dependency graph
requires:
  - phase: 03-01
    provides: canonical_url_override string column on blogs table (migration)
provides:
  - Blog#canonical_url_override validation (URI::DEFAULT_PARSER, http/https only, allow_blank)
  - :canonical_url_override in Admin::BlogsController strong params
  - Canonical URL Override text_field in admin blog form (after slug, before keywords)
  - BlogsController#show respects override with .presence fallback to blog_url
affects:
  - app/models/blog.rb
  - app/controllers/admin/blogs_controller.rb
  - app/controllers/blogs_controller.rb
  - app/views/admin/blogs/_form.html.erb

# Tech tracking
tech-stack:
  added: []
  patterns:
    - URI::DEFAULT_PARSER.make_regexp(%w[http https]) validation with allow_blank for optional URL fields (mirrors User#linkedin_url)
    - .presence || fallback for optional override fields in controller assignments

key-files:
  created: []
  modified:
    - app/models/blog.rb
    - app/controllers/admin/blogs_controller.rb
    - app/controllers/blogs_controller.rb
    - app/views/admin/blogs/_form.html.erb
    - spec/models/blog_spec.rb
    - spec/requests/admin/blogs_spec.rb
    - spec/requests/blogs_spec.rb

key-decisions:
  - "Used URI::DEFAULT_PARSER.make_regexp(%w[http https]) with allow_blank: true — exact pattern from User#linkedin_url for consistency"
  - ".presence used in controller (not .present?) so empty string converts to nil and || falls through to blog_url default"
  - "canonical_url_override field positioned after slug and before keywords in admin form (UI-SPEC position 10)"

requirements-completed:
  - SEO-03

# Metrics
duration: 2 min
completed: 2026-05-22
---

# Phase 3 Plan 02: Canonical URL Override Slice Summary

**End-to-end Canonical URL Override (SEO-03): URI validation rejects non-http(s) schemes, admin form field persists the override, and public blog pages use the override value with a clean .presence || blog_url fallback.**

## Performance

- **Duration:** 2 min
- **Started:** 2026-05-22T08:36:34Z
- **Completed:** 2026-05-22T08:38:42Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments

- Blog model validates `canonical_url_override` using the same `URI::DEFAULT_PARSER.make_regexp(%w[http https])` pattern as `User#linkedin_url` — rejects `javascript:`, `data:`, and freeform strings; accepts blank
- Admin form has a Canonical URL Override text field (position 10, single-column, after slug, before keywords) with placeholder and hint copy matching the UI-SPEC
- `Admin::BlogsController#blog_params` permits `:canonical_url_override` — field saves without unpermitted-param warnings
- `BlogsController#show` uses `@blog.canonical_url_override.presence || blog_url(@blog.slug)` — blank/nil values fall through cleanly to the existing default

## Task Commits

| Task | Type | Hash | Description |
|------|------|------|-------------|
| 1 RED | test | 9d3b0d2 | Failing specs: 7 model specs + 1 admin request spec |
| 1 GREEN | feat | 283a2bb | Validation, strong params, admin form field |
| 2 RED | test | 8d6e99a | Failing request specs for canonical link rendering |
| 2 GREEN | feat | e526caa | Controller .presence || fallback assignment |

## Files Created/Modified

- `app/models/blog.rb` — Added `validates :canonical_url_override` with URI::DEFAULT_PARSER pattern
- `app/controllers/admin/blogs_controller.rb` — Added `:canonical_url_override` to permitted scalar array
- `app/controllers/blogs_controller.rb` — Replaced `blog_url(@blog.slug)` line with override+fallback
- `app/views/admin/blogs/_form.html.erb` — Added canonical URL Override `<div>` after slug field
- `spec/models/blog_spec.rb` — Added 7-spec `describe "#canonical_url_override validation"` block
- `spec/requests/admin/blogs_spec.rb` — Added 1 PATCH request spec for override persistence
- `spec/requests/blogs_spec.rb` — Added 3 GET request specs for canonical link rendering

## Decisions Made

- **URI::DEFAULT_PARSER.make_regexp** chosen over custom regex — same pattern as `User#linkedin_url`; proven in production to reject `javascript:` schemes (T-03-11 mitigated)
- **`.presence` over `.present?`** — `.presence` returns nil for blank, enabling `||` short-circuit; `.present?` returns boolean which cannot short-circuit
- **Form field position** — single-column slot (no `md:col-span-2`), placed between slug and keywords per UI-SPEC field ordering table (position 10)

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Known Stubs

None introduced by this plan. Pre-existing stubs (faq_schema, og_image) remain documented in 03-01-SUMMARY.md and are resolved by Plans 03 and 04.

## Threat Surface Scan

No new threat surface. All threats covered by the plan's threat model:

- T-03-08: `javascript:alert(1)` rejected by URI::DEFAULT_PARSER validation — verified in Test 5 (model spec)
- T-03-09: ERB auto-escapes `<%= canonical_url %>` in `href` attribute — no `raw`/`html_safe` used

## Next Phase Readiness

- SEO-03 requirement satisfied end-to-end
- Plan 01 keywords behaviour unaffected (all 31 specs pass including Plan 01 specs)
- Ready for Plan 03 (OG Image slice) or Plan 04 (FAQ Schema slice)

---
*Phase: 03-seo-fields-faq-schema*
*Completed: 2026-05-22*

## Self-Check: PASSED

Files verified:
- `app/models/blog.rb` — FOUND
- `app/controllers/blogs_controller.rb` — FOUND
- `app/views/admin/blogs/_form.html.erb` — FOUND
- `03-02-SUMMARY.md` — FOUND

Commits verified:
- 9d3b0d2 (test RED Task 1) — FOUND
- 283a2bb (feat GREEN Task 1) — FOUND
- 8d6e99a (test RED Task 2) — FOUND
- e526caa (feat GREEN Task 2) — FOUND

All 31 specs pass: 0 failures.
