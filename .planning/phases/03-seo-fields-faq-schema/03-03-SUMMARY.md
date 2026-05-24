---
phase: "03-seo-fields-faq-schema"
plan: "03"
subsystem: "seo-og-image"
tags:
  - rails
  - seo
  - activestorage
  - og-image
  - security
dependency_graph:
  requires:
    - "03-01"
    - "03-02"
  provides:
    - "og_image_url model helper"
    - "og:image fallback chain (og_image → cover_photo → logo)"
    - "admin OG image upload form field with preview"
  affects:
    - "app/models/blog.rb"
    - "app/controllers/blogs_controller.rb"
    - "app/controllers/admin/blogs_controller.rb"
    - "app/views/admin/blogs/_form.html.erb"
tech_stack:
  added: []
  patterns:
    - "ActiveStorage has_one_attached content-type whitelist validation"
    - "3-step og:image fallback chain (og_image → cover_photo → logo)"
    - "explicit raster-image whitelist to prevent stored-XSS via SVG (T-03-14)"
key_files:
  created:
    - "spec/fixtures/files/sample.png"
  modified:
    - "app/models/blog.rb"
    - "app/controllers/admin/blogs_controller.rb"
    - "app/controllers/blogs_controller.rb"
    - "app/views/admin/blogs/_form.html.erb"
    - "spec/models/blog_spec.rb"
    - "spec/requests/admin/blogs_spec.rb"
    - "spec/requests/blogs_spec.rb"
decisions:
  - "og_image content-type validation uses explicit raster-image whitelist %w[image/png image/jpeg image/jpg image/gif image/webp] (not start_with? prefix) per T-03-14 stored-XSS mitigation"
  - "og_image_for controller method sets @page_og_image deterministically; eliminates conditonal old line"
  - "Model og_image_url mirrors cover_photo_url pattern (url_for with host, rails_blob_path fallback, rescue StandardError)"
  - "Test specs use ActiveJob::Base.queue_adapter = :test to avoid SolidQueue DB table requirement for ActiveStorage analyze jobs"
  - "Test specs set Rails.application.routes.default_url_options[:host] to enable og_image_url/cover_photo_url to return full URLs for assertion"
metrics:
  duration: "~15 minutes"
  completed: "2026-05-24"
  tasks_completed: 2
  files_modified: 7
---

# Phase 03 Plan 03: OG Image Upload and Fallback Chain Summary

**One-liner:** Per-post OG image upload with explicit SVG-blocking content-type whitelist and a 3-step og:image fallback chain (og_image → cover_photo → site logo).

## What Was Built

### Task 1: Blog model og_image_url helper + content-type validation + strong params

**`app/models/blog.rb`**
- Added `og_image_url` public method mirroring the existing `cover_photo_url` pattern: returns nil when not attached, uses `url_for(og_image)` when default host is set, falls back to `rails_blob_path(og_image, only_path: false)`, rescues StandardError to nil.
- Added `validate :validate_og_image_content_type` after the canonical_url_override validation.
- Added private `validate_og_image_content_type` method with an explicit raster-image whitelist `%w[image/png image/jpeg image/jpg image/gif image/webp]` — SVG and other non-raster types are rejected and purged, preventing stored-XSS via `image/svg+xml` per threat T-03-14.

**`app/controllers/admin/blogs_controller.rb`**
- Added `:og_image` to the `permitted` array in `blog_params`, after `:canonical_url_override`.

**`spec/models/blog_spec.rb`**
- Added `describe "#og_image"` block with 6 tests (nil return, URL return with host set, PDF rejected, PNG valid, SVG rejected, purge on invalid).
- Used `around` hook to switch to `:test` queue adapter, avoiding SolidQueue table dependency during `attach`.
- URL test sets `Rails.application.routes.default_url_options[:host]` temporarily so `og_image_url` produces a full URL (cleaned up via ensure block).

### Task 2: Admin form file_field + preview, public-side fallback chain

**`app/views/admin/blogs/_form.html.erb`**
- Inserted OG Image `<div>` block immediately before the existing Cover Photo block.
- Includes: label ("OG Image (Social Share)"), `form.file_field :og_image accept="image/*"`, conditional preview (`@blog.persisted? && @blog.og_image.attached?`), hint text explaining fallback priority.

**`app/controllers/blogs_controller.rb`**
- Replaced `@page_og_image = @blog.cover_photo_url if @blog.image.attached?` with `@page_og_image = og_image_for(@blog)`.
- Added private method `og_image_for(blog)` implementing the 3-step fallback chain:
  1. If `blog.og_image.attached?` → return `blog.og_image_url`
  2. Else if `blog.image.attached?` → return `blog.cover_photo_url`
  3. Else → return `helpers.asset_url("logo.png")`
- The `ApplicationHelper#page_og_image` already falls back to `asset_url("logo.png")` when `@page_og_image` is nil, but the controller now sets it explicitly for determinism.

**`spec/requests/admin/blogs_spec.rb`**
- Added `describe "PATCH /update og_image"` with test: uploads PNG fixture, confirms `blog.og_image.attached? == true`.
- Uses `:test` queue adapter in `around` hook.

**`spec/requests/blogs_spec.rb`**
- Added `describe "GET /blog/:id og:image fallback chain"` with 3 tests:
  1. Both og_image and cover attached → response body includes og_image_url (og_image wins)
  2. Only cover photo attached → response body includes cover_photo_url
  3. Neither attached → response body matches `/logo\.png/` in og:image meta tag
- Uses `:test` queue adapter and sets `default_url_options[:host]` for full URL generation.

**`spec/fixtures/files/sample.png`**
- Created 1x1 PNG fixture file for use in request specs.

## Acceptance Criteria Verification

| Criterion | Status |
|-----------|--------|
| `def og_image_url` in blog.rb | PASS |
| `validate :validate_og_image_content_type` registered | PASS |
| `def validate_og_image_content_type` private method | PASS |
| SVG NOT in whitelist (`image/svg` absent from whitelist array) | PASS |
| `image/webp` in whitelist | PASS |
| No `start_with?("image/")` prefix check used | PASS |
| `:og_image` in admin blog_params | PASS |
| `form.file_field :og_image` in admin form | PASS |
| `@blog.og_image.attached?` preview guard | PASS |
| `@page_og_image = og_image_for` in blogs_controller | PASS |
| `def og_image_for` in blogs_controller | PASS |
| Old `@page_og_image = @blog.cover_photo_url if` line removed | PASS |
| All new specs pass (41 total across model + request specs) | PASS |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] SolidQueue DB tables absent in test environment**
- **Found during:** Task 1 GREEN phase
- **Issue:** `attach(io:)` triggers `ActiveStorage::AnalyzeJob` via SolidQueue; test DB lacks `solid_queue_jobs` table, causing `PG::UndefinedTable` error.
- **Fix:** Added `around` hook in specs to temporarily switch `ActiveJob::Base.queue_adapter = :test`, which queues jobs in memory instead of SolidQueue.
- **Files modified:** `spec/models/blog_spec.rb`, `spec/requests/admin/blogs_spec.rb`, `spec/requests/blogs_spec.rb`

**2. [Rule 3 - Blocking] og_image_url / cover_photo_url returns nil in test environment**
- **Found during:** Task 2 RED phase
- **Issue:** Model URL helpers require `Rails.application.routes.default_url_options[:host]` to be set; test environment has empty hash, causing `rails_blob_path(only_path: false)` to raise StandardError (rescued → nil).
- **Fix:** Added `Rails.application.routes.default_url_options[:host] = "www.example.com"` in `around` hook for request specs that need to assert specific blob URLs; cleaned up in `ensure` block.
- **Files modified:** `spec/requests/blogs_spec.rb`

**3. [Rule 2 - Missing Critical Functionality] Worktree missing compiled assets**
- **Found during:** Task 2 RED phase initial run
- **Issue:** Request specs failed with `Propshaft::MissingAssetError: application.css not found` because worktree lacks compiled assets.
- **Fix:** Copied compiled assets from main repo to worktree `app/assets/builds/`. This is a worktree initialization artifact; the main repo has the assets.
- **Files modified:** `app/assets/builds/` (runtime, not committed)

## Known Stubs

None — OG image upload, model helper, and fallback chain are fully wired end-to-end.

## Threat Surface Scan

No new network endpoints or auth paths introduced beyond what's in the plan's threat model. The `og_image_for` method is a private controller helper with no new public surface. Content-type whitelist mitigates T-03-14 as designed.

## TDD Gate Compliance

- RED gate: `test(03-03): add failing specs for og_image_url and content-type validation` (e920f59)
- GREEN gate: `feat(03-03): Blog#og_image_url helper, content-type validation, and og_image strong params` (52db1ee)
- RED gate (Task 2): `test(03-03): add failing request specs for og_image admin upload and og:image fallback chain` (4fc800c)
- GREEN gate (Task 2): `feat(03-03): OG image admin form field and 3-step fallback chain in blogs controller` (65d738f)
