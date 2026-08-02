---
phase: 01-toc-domain-core-regression-baseline
plan: 01

subsystem: database

tags: [rails, activerecord, postgresql, jsonb, migration, sti, admin-controller, rspec]

# Dependency graph
requires: []
provides:
  - "blogs.toc_enabled boolean column (default false, null: false), no backfill"
  - "blogs.toc_overrides jsonb column (default {}, null: false), no backfill"
  - "Admin::BlogsController#blog_params permits toc_enabled (admin-only write seam)"
  - "Model spec coverage proving Article (STI) inherits both columns with identical defaults"
  - "Model spec coverage proving id attributes never persist to blogs.body (Blog and Article)"
affects: [01-02, 01-03, 01-04]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "add_column with a constant default (no backfill), proven zero-row-touch via before/after pluck+diff on id/updated_at/body"
    - "jsonb column keyed by anchor (toc_overrides) follows the keywords jsonb precedent, not the faq_schema text-holding-JSON pattern"

key-files:
  created:
    - db/migrate/20260802120004_add_toc_fields_to_blogs.rb
  modified:
    - db/schema.rb
    - app/controllers/admin/blogs_controller.rb
    - spec/models/blog_spec.rb

key-decisions:
  - "toc_overrides intentionally NOT added to admin strong params this plan - unvalidated jsonb write surface deferred to Phase 4 (ADMIN-02)"
  - "No :article factory added; Article specs use Article.create! directly with the same required attributes the :blog factory supplies, per plan direction"

patterns-established:
  - "Zero-row-touch migration verification: capture Blog.pluck(:id, :updated_at, :body) to a tmp/ JSON file before and after db:migrate, diff must be empty"

requirements-completed: [TOC-01]

# Metrics
duration: ~25min
completed: 2026-08-02
---

# Phase 01 Plan 01: TOC Data Model Columns & Admin Write Seam Summary

**Added `toc_enabled` (boolean, default false) and `toc_overrides` (jsonb, default {}) to `blogs` via a proven zero-row-touch migration, opened the admin-only `toc_enabled` write seam, and locked defaults/STI inheritance/id-strip invariants with model specs.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-08-02T12:01:00Z (approx)
- **Completed:** 2026-08-02T12:04:09Z
- **Tasks:** 2 completed
- **Files modified:** 4 (1 created, 3 modified)

## Accomplishments
- `blogs.toc_enabled` and `blogs.toc_overrides` columns exist with correct defaults, proven not to touch a single pre-existing row (`updated_at`/`body` byte-identical before/after migration)
- `Admin::BlogsController#blog_params` permits `toc_enabled` only — `toc_overrides` deliberately excluded (no consumer yet, Phase 4 concern)
- `Article` (STI subtype of `Blog`) confirmed to inherit both columns with identical defaults
- Discharged the STATE.md MEDIUM-confidence blocker on `id` attribute stripping — new specs prove `id="..."` submitted in `body` HTML never persists, for both `Blog` and `Article`, and that `Blog::ALLOWED_ATTRIBUTES` itself excludes `"id"`

## Task Commits

Each task was committed atomically:

1. **Task 1: Add toc_enabled and toc_overrides columns with a proven zero-row-touch migration** - `92983bb` (feat)
2. **Task 2: Lock the column defaults, the STI path, and the id-never-persisted invariant in model specs** - `2f25e5f` (test)

_Note: this worktree does not run the shared metadata commit (STATE.md/ROADMAP.md) — the orchestrator handles that centrally after merge._

## Files Created/Modified
- `db/migrate/20260802120004_add_toc_fields_to_blogs.rb` - New migration, two `add_column` calls, no index, no backfill
- `db/schema.rb` - Regenerated (version bump + two new `blogs` columns; no other table touched)
- `app/controllers/admin/blogs_controller.rb` - `toc_enabled` appended to `blog_params`' permitted scalar list
- `spec/models/blog_spec.rb` - Two new `describe` blocks: TOC column defaults/STI, and id-strip invariant (Blog + Article)

## Decisions Made
- `toc_overrides` is not added to any strong-params list in this plan (per plan directive and threat register T-01-02) — an unvalidated jsonb structure with no consumer would be pure attack surface; Phase 4 (ADMIN-02) will validate anchor keys/string values before permitting it.
- No `:article` FactoryBot factory was added. Per the plan's explicit fallback, `Article` specs use `Article.create!(title:, slug:, body:, published_at:)` directly, matching the required attributes the `:blog` factory already supplies.

## Deviations from Plan

None - plan executed exactly as written. Both tasks' automated verification commands and acceptance criteria passed without needing any Rule 1-4 fixes.

## Issues Encountered

Pre-existing, out-of-scope: running the plan's overall `<verification>` block (`bundle exec rspec spec/models spec/requests`) surfaces 24 failures in files this plan does not touch (`spec/requests/admin/resource_deletion_spec.rb`, `spec/requests/admin/seo_metadata_spec.rb`, `spec/requests/admin/users_spec.rb`, `spec/requests/blogs_spec.rb`), all `Propshaft::MissingAssetError: The asset 'application.css' was not found in the load path`. Root cause: `app/assets/builds/*` is gitignored in this worktree and the Tailwind CSS build has not been run — unrelated to the migration, controller change, or model spec additions in this plan. `spec/models/blog_spec.rb` (the only spec file this plan modified) passes 39/39. Logged to `.planning/phases/01-toc-domain-core-regression-baseline/deferred-items.md` per the SCOPE BOUNDARY rule; not auto-fixed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- `toc_enabled`/`toc_overrides` columns and the admin write seam for `toc_enabled` are in place for plans 01-02 (`Blog::TableOfContents` PORO), 01-03, and 01-04 to build on.
- The `id`-strip invariant is now permanently asserted by CI, so plan 01-02's anchor-injection design (never adding `id` to `Blog::ALLOWED_ATTRIBUTES`) has a regression guard.
- Before running the full `spec/requests` suite in this or a fresh worktree, run the Tailwind/esbuild CSS build step (see deferred-items.md) — otherwise 24 unrelated request specs will fail on missing `application.css`.

---
*Phase: 01-toc-domain-core-regression-baseline*
*Completed: 2026-08-02*
