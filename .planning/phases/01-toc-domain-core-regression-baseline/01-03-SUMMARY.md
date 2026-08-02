---
phase: 01-toc-domain-core-regression-baseline
plan: 03

subsystem: testing

tags: [rspec, request-spec, nokogiri, html5, golden-master, regression-baseline, propshaft]

# Dependency graph
requires:
  - phase: 01-toc-domain-core-regression-baseline (01-01)
    provides: "blogs.toc_enabled / blogs.toc_overrides columns (used only to pin toc_enabled: false on every fixture)"
provides:
  - "GoldenMaster RSpec support module (spec/support/golden_master.rb): normalize_html, article_region, match_golden!"
  - "LAYOUT-04 CI gate: spec/requests/blogs_golden_master_spec.rb, 15 examples over 5 curated TOC-off fixtures"
  - "10 committed byte-exact/normalized baselines under spec/fixtures/golden_master/ freezing today's /blog/:slug rendering"
affects: [01-04, phase-02-two-column-layout, phase-03-client-behavior]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Two-layer golden master: Layer A byte-exact on div.prose via Nokogiri::HTML5, Layer B full-page with volatility normalized (asset digest, ISO-8601 timestamp, host)"
    - "match_golden! calls `skip`, never `expect`, under UPDATE_GOLDEN=1 — regeneration can never report as a pass"
    - "Absolute Time.utc fixture timestamps + distinct published_at per fixture keep JSON-LD dates and published-scope ordering deterministic"

key-files:
  created:
    - spec/support/golden_master.rb
    - spec/requests/blogs_golden_master_spec.rb
    - spec/fixtures/golden_master/images_post.article.html
    - spec/fixtures/golden_master/images_post.page.html
    - spec/fixtures/golden_master/tables_post.article.html
    - spec/fixtures/golden_master/tables_post.page.html
    - spec/fixtures/golden_master/code_post.article.html
    - spec/fixtures/golden_master/code_post.page.html
    - spec/fixtures/golden_master/faq_post.article.html
    - spec/fixtures/golden_master/faq_post.page.html
    - spec/fixtures/golden_master/minimal_post.article.html
    - spec/fixtures/golden_master/minimal_post.page.html
  modified: []

key-decisions:
  - "Golden-master comparison hand-rolled (~65 lines) rather than pulling in rspec-snapshot/approvals, per RESEARCH.md's rejection of both as unverified/unnecessary dependencies"
  - "No application code changed — this plan is test-only, matching D-07 and the plan's own success criteria"
  - "yarn install + yarn build:css + yarn build run once to restore this worktree's gitignored app/assets/builds/* (Rule 3 blocking-issue fix, not a new/unverified package — installed from the already-committed yarn.lock)"

patterns-established:
  - "Golden-master normalization: reduce over NORMALIZERS [(regexp, replacement)] pairs, each with a comment naming the verified volatility source and the date it was verified"
  - "Regeneration-cannot-pass invariant: any RSpec golden-master matcher must `skip`, never allow `expect` to trivially pass, when writing a new baseline"

requirements-completed: [LAYOUT-04]

# Metrics
duration: ~15min
completed: 2026-08-02
---

# Phase 01 Plan 03: TOC Domain Core & Regression Baseline Summary

**Two-layer golden-master RSpec gate (byte-exact div.prose + normalized full-page) freezing today's TOC-off `/blog/:slug` rendering across 10 committed baselines spanning images, tables, code, FAQ, and minimal-body posts.**

## Performance

- **Duration:** ~15 min (includes restoring this worktree's node_modules/asset builds, out of scope for the plan itself but required to run request specs)
- **Started:** 2026-08-02T12:06:00Z (approx, worktree base commit)
- **Completed:** 2026-08-02T12:12:27Z
- **Tasks:** 2 completed
- **Files modified:** 12 (2 created source files, 10 committed baseline `.html` files)

## Accomplishments
- `GoldenMaster` support module provides deterministic, documented baseline comparison with a regeneration path that can never silently pass (`skip`, not `expect`, under `UPDATE_GOLDEN=1`)
- `Nokogiri::HTML5` used throughout (never HTML4/bare `Nokogiri::HTML`), avoiding the entity-decoding corruption documented in RESEARCH.md Pitfall 1 — verified `&nbsp;` survives as a literal entity in `images_post.article.html`
- 10 baselines committed capturing the real `Blog::ALLOWED_TAGS` markup surface: `figure`/`img`/`figcaption`, `table`/`colgroup`/`thead`/`tbody`/`tfoot`, `pre`/`code` with escaped entities, an FAQ post exercising both the `_faq_section` partial and the `FAQPage` JSON-LD branch, and a genuinely minimal single-`<p>` body
- Gate proven stable across 3 consecutive fresh-process runs (15/15 green each time) and proven sensitive: a single injected HTML comment inside `div.prose` in `app/views/blogs/show.html.erb` failed 10/15 examples; the edit was reverted immediately after the check and `git diff` confirmed a clean revert
- Zero application code changed — `git diff --stat -- app/` is empty, matching the plan's test-only success criterion

## Task Commits

Each task was committed atomically:

1. **Task 1: Golden-master support module with volatility normalization and UPDATE_GOLDEN regeneration** - `1c10214` (test)
2. **Task 2: Capture and commit the five-post TOC-off baseline** - `c58a83c` (test)

_Note: this worktree does not run the shared metadata commit (STATE.md/ROADMAP.md) — the orchestrator handles that centrally after merge._

## Files Created/Modified
- `spec/support/golden_master.rb` - `GoldenMaster` module: `NORMALIZERS` (Propshaft digest, ISO-8601 timestamp, host), `normalize_html`, `article_region` (Nokogiri::HTML5, raises a clear error if `div.prose` is absent instead of `NoMethodError` on nil), `match_golden!` (skip-on-regenerate); auto-required via `spec/rails_helper.rb:30`, no `rails_helper.rb` change needed
- `spec/requests/blogs_golden_master_spec.rb` - LAYOUT-04 gate: 5 curated `FIXTURES`, absolute `BASE_TIME`, 3 examples per fixture (Layer A, Layer B, zero-`toc-`-anchors negative assertion)
- `spec/fixtures/golden_master/*.html` - 10 committed baselines (`{images_post,tables_post,code_post,faq_post,minimal_post}.{article,page}.html`)

## Decisions Made
- Hand-rolled comparison logic instead of an approval-testing gem — matches RESEARCH.md's explicit rejection of `rspec-snapshot`/`approvals` (both `[ASSUMED]` provenance, neither solves volatility normalization, the actual hard part)
- `update_column` (not `update`) for `faq_post`'s `faq_schema`, to bypass the `parse_faq_schema` callback and keep `updated_at` — and therefore the JSON-LD `dateModified` — pinned, matching the existing idiom at `spec/requests/blogs_spec.rb:110-122`
- No Active Storage `attach` calls anywhere in the fixture setup — blob keys are randomized per test run and would poison a committed baseline; "images" coverage is satisfied by `<img>` tags inside the sanitized body HTML, the actual code path this project touches

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Restored this worktree's node_modules and asset builds**
- **Found during:** Pre-Task-1 environment check (`bundle exec rspec spec/requests/blogs_spec.rb`)
- **Issue:** This worktree had no `node_modules/` and a gitignored, empty `app/assets/builds/` (only `.keep` tracked). Every request spec that renders a view with `stylesheet_link_tag "application"` — including the new golden-master spec and the plan's own Task 1 verify command — fails with `Propshaft::MissingAssetError`. This is the same root cause already logged as an out-of-scope deferred item after Plan 01-01, but it directly blocks this plan's own verification commands, unlike 01-01 where it was incidental.
- **Fix:** Ran `yarn install` (installs from the already-committed `yarn.lock`/`package.json` — no new or unverified package name introduced), then `yarn build:css` and `yarn build` to produce `app/assets/builds/application.css` and `application.js`.
- **Files modified:** None tracked by git (`node_modules/` and `app/assets/builds/*` are both gitignored; nothing was staged or committed for this fix).
- **Verification:** `bundle exec rspec spec/requests/blogs_spec.rb` went from failing on `Propshaft::MissingAssetError` to 11/11 passing before Task 1 began.
- **Committed in:** N/A (no trackable file changes — build artifacts and node_modules are gitignored in this repo).

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Necessary to run any request spec in this worktree at all, including the plan's own verify commands. No application or test code was touched by this fix, and nothing was committed for it — a fresh worktree/CI run will need the same `yarn install && yarn build:css && yarn build` step before this spec (or any request spec) can run, consistent with the resolution already suggested in `deferred-items.md` after 01-01.

## Issues Encountered
None beyond the deviation above.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- LAYOUT-04's regression gate is live and green: `bundle exec rspec spec/requests` passes 77/77 including the 15 new golden-master examples
- Plan 01-04 (anchor injection) and Phase 2 (two-column layout) must keep `bundle exec rspec spec/requests/blogs_golden_master_spec.rb` green; Layer A will catch any change to the `div.prose` markup itself, Layer B will catch wrapper/layout regressions once TOC anchors and layout land
- Regeneration path (`UPDATE_GOLDEN=1 bundle exec rspec spec/requests/blogs_golden_master_spec.rb`) is documented in both `spec/support/golden_master.rb`'s file header and the spec file's own header comment, for whichever future plan needs it (e.g., if Phase 2 intentionally changes the wrapper markup)
- Any fresh worktree/CI environment must run `yarn install && yarn build:css && yarn build` before this or any other request spec — carried forward from the 01-01 deferred item, now also directly relevant to this plan's own test suite

---
*Phase: 01-toc-domain-core-regression-baseline*
*Completed: 2026-08-02*

## Self-Check: PASSED

All created files verified present on disk (`spec/support/golden_master.rb`, `spec/requests/blogs_golden_master_spec.rb`, 10 files under `spec/fixtures/golden_master/`). All task and metadata commits (`1c10214`, `c58a83c`, `37a464a`) verified present in `git log`.
