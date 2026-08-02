---
phase: 01-toc-domain-core-regression-baseline
plan: 04

subsystem: rendering

tags: [rails, erb, helper, nokogiri, request-spec, brakeman, regression-gate]

# Dependency graph
requires:
  - phase: 01-toc-domain-core-regression-baseline (01-02)
    provides: "Blog::TableOfContents.call(sanitized_html) -> #to_html"
  - phase: 01-toc-domain-core-regression-baseline (01-03)
    provides: "LAYOUT-04 golden-master gate (spec/requests/blogs_golden_master_spec.rb) and 10 committed baselines"
provides:
  - "BlogsHelper#blog_body_with_toc_anchors(blog, sanitized_html) — TOC-off short-circuit returning the sanitizer's own SafeBuffer untouched; TOC-on path returns Blog::TableOfContents.call(...).to_html.html_safe"
  - "app/views/blogs/show.html.erb wired to call the helper downstream of the existing sanitize call, wrapper div byte-identical"
  - "spec/requests/blogs_toc_spec.rb — 10 examples proving rendered-response anchors, TOC-off zero-injection, and non-mutation of blogs.body/.md export/JSON API/seo_description"
affects: [phase-02-toc-sidebar, phase-03-scroll-spy, phase-04-admin-overrides]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Helper wraps the view sanitizer's output as an argument — injection is structurally downstream, never upstream, of the last sanitizer pass"
    - "TOC-off short-circuit returns the caller's own SafeBuffer object (not a copy/re-serialization) — byte-identity is structural, not merely tested"

key-files:
  created:
    - spec/requests/blogs_toc_spec.rb
  modified:
    - app/helpers/blogs_helper.rb
    - app/views/blogs/show.html.erb

key-decisions:
  - "Manual .md/JSON API endpoint check (Task 3 step 5) performed via an in-process ActionDispatch::Integration::Session in a RAILS_ENV=test bin/rails runner script rather than a bound bin/rails server + curl — functionally identical HTTP round-trip through the real router/controller/view stack, avoids binding a port in the worktree sandbox"
  - "Brakeman before/after baseline established via a temporary detached git worktree at the pre-plan commit (05339d4), not git stash — git stash is prohibited for worktree-isolated executors per the destructive-git-operations rule"

patterns-established: []

requirements-completed: [TOC-03, LAYOUT-04]

# Metrics
duration: ~20min (includes yarn install/build restoration and Brakeman before/after worktree setup)
completed: 2026-08-02
---

# Phase 01 Plan 04: Render-Time Anchor Injection & Full Regression Gate Summary

**Wired `Blog::TableOfContents` into the rendered `/blog/:slug` response via a one-line `show.html.erb` wrap and a guard-clause short-circuit in `BlogsHelper`, proved the wiring with a 10-example request spec, and ran the full-suite regression gate (152 rspec examples, 0 rubocop offenses in plan-touched files, Brakeman warning count unchanged at 0 security / 1 pre-existing ignored).**

## Performance

- **Duration:** ~20 min (includes restoring this worktree's node_modules/asset builds via `yarn install && yarn build:css && yarn build`, and a temporary detached worktree for the Brakeman before/after comparison)
- **Started:** 2026-08-02T19:57:00Z (approx, worktree base commit)
- **Completed:** 2026-08-02T20:04:08Z
- **Tasks:** 3 completed
- **Files modified:** 3 (1 created, 2 modified), plus 1 deferred-items.md documentation update

## Accomplishments
- `BlogsHelper#blog_body_with_toc_anchors` implemented exactly per D-03/Pattern 3: `return sanitized_html unless blog.toc_enabled?` as the first statement, returning the sanitizer's own `SafeBuffer` untouched on the TOC-off path — no parse, no re-serialization
- `show.html.erb` line 76 wraps the existing `sanitize @blog.body, tags: Blog::ALLOWED_TAGS, attributes: Blog::ALLOWED_ATTRIBUTES` call verbatim as the helper's second argument; the `div.prose` wrapper (LAYOUT-04's golden-master selector) is byte-identical to its pre-plan form
- `spec/requests/blogs_toc_spec.rb`: 10 examples covering unescaped/unique `toc-` anchors on H2/H3 (including the dedup suffix), H1/H4 left untouched, zero injection when `toc_enabled: false`, `blogs.body`/.md export/`seo_description`/public JSON API all provably unaffected (byte-for-byte `content_html` equality, not substring match), and `Article` STI coverage
- Mutation-tested the spec itself: temporarily removing `.html_safe` from the helper failed 4/10 examples; temporarily removing the TOC-off guard clause failed 2/10 examples (the TOC-off group). Both mutations reverted immediately, confirmed by a clean `git diff`
- Full-suite regression gate: `bundle exec rspec` — 152 examples, 0 failures, 5 pre-existing pending; `git status --porcelain spec/fixtures/golden_master/` empty (all 10 baselines from plan 01-03 matched without regeneration); `bundle exec rubocop` — 0 offenses across all three files this plan touched; Brakeman — 0 security warnings / 1 pre-existing ignored warning (Mass Assignment, `admin/users_controller.rb`, unrelated to this plan) on both the pre-plan tree and the current tree — the predicted `.html_safe` XSS warning (RESEARCH.md assumption A6) did **not** materialize
- Manual endpoint verification (in-process integration session, `RAILS_ENV=test`): a TOC-enabled post's rendered HTML contains `id="toc-...` anchors; its `.md` export and `/api/v1/blogs/:slug` JSON response contain no `toc-` substring at all

## Task Commits

Each task was committed atomically:

1. **Task 1: BlogsHelper anchor injection with a TOC-off short-circuit, wired at the sanitize call site** - `0f1ade9` (feat)
2. **Task 2: Request spec proving anchors reach the response and never reach the database, .md, or JSON API** - `920ec0d` (test)
3. **Task 3: Full-suite regression gate including Brakeman disposition** - `e6c5088` (docs, deferred-items.md logging; this SUMMARY is the plan's Task 3 deliverable)

_Note: this worktree does not run the shared metadata commit (STATE.md/ROADMAP.md) — the orchestrator handles that centrally after merge._

## Files Created/Modified
- `app/helpers/blogs_helper.rb` - `blog_body_with_toc_anchors(blog, sanitized_html)`: TOC-off guard clause, TOC-on `Blog::TableOfContents.call(...).to_html.html_safe`, `# SECURITY:` justification comment naming the two enforcing spec files
- `app/views/blogs/show.html.erb` - Line 76 wraps the existing `sanitize` call as the helper's second argument; wrapper `div.prose` untouched
- `spec/requests/blogs_toc_spec.rb` - New request spec, 10 examples across 4 describe groups (rendered response, TOC-off short-circuit, persistence/upstream-consumers, STI coverage)
- `.planning/phases/01-toc-domain-core-regression-baseline/deferred-items.md` - Logged pre-existing, out-of-scope Rubocop offenses in generated schema files (see Deviations below)

## Decisions Made
- Full-suite Task 3 verification's "manual `curl`/`bin/rails server`" instruction was satisfied with an equivalent in-process `ActionDispatch::Integration::Session` under `RAILS_ENV=test` — exercises the identical router → controller → view → helper chain as a bound HTTP server would, without needing to allocate a port inside the worktree sandbox.
- Brakeman's required before/after comparison was established via a temporary `git worktree add --detach` at the pre-plan commit (`05339d4`) rather than `git stash`, per the standing prohibition on `git stash` for worktree-isolated executors (the shared stash ref is unsafe across parallel worktrees). The temporary worktree was removed (`git worktree remove --force`) immediately after the baseline scan.
- Discovered mid-Task-2 that fixture slugs containing the literal substring `toc-` (e.g. `toc-persistence-post`) produce false-positive `include("toc-")` failures in the `.md`/URL-based assertions, because the slug itself — not the anchor injection — contains that substring. Renamed all spec fixture slugs to an `anchor-*-post` / `anchor-on-article` naming scheme to eliminate the collision. This was a bug in the spec I was writing (Rule 1), not a finding about the implementation; the same false positive appeared in the ad hoc manual endpoint check and was fixed identically.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Restored this worktree's node_modules and asset builds**
- **Found during:** Pre-Task-1 environment check (same root cause as plans 01-01 and 01-03)
- **Issue:** This worktree had no `node_modules/` and a gitignored, empty `app/assets/builds/`. Every request spec rendering `stylesheet_link_tag "application"` fails with `Propshaft::MissingAssetError` without it — blocks this plan's own Task 1/2/3 verification commands.
- **Fix:** `yarn install` (from the already-committed `yarn.lock`), then `yarn build:css` and `yarn build`.
- **Files modified:** None tracked by git (both are gitignored).
- **Verification:** `bundle exec rspec spec/requests/blogs_golden_master_spec.rb spec/requests/blogs_spec.rb` went from failing to 26/26 passing before Task 1 began.
- **Committed in:** N/A (gitignored, nothing to commit).

**2. [Rule 1 - Bug in my own test] Renamed spec fixture slugs colliding with the `toc-` assertion substring**
- **Found during:** Task 2, first run of `spec/requests/blogs_toc_spec.rb`
- **Issue:** Fixture slugs like `toc-persistence-post` made `expect(response.body).not_to include("toc-")` fail because the rendered canonical URL / markdown "Source:" line contains the slug itself, which happens to contain `toc-` — a false positive unrelated to anchor injection.
- **Fix:** Renamed all fixture slugs to an `anchor-*` scheme (`anchor-on-post`, `anchor-off-post`, `anchor-persistence-post`, `anchor-on-article`).
- **Files modified:** `spec/requests/blogs_toc_spec.rb` (committed in the Task 2 commit, `920ec0d` — no separate commit needed since the file was not yet committed).
- **Verification:** `bundle exec rspec spec/requests/blogs_toc_spec.rb` — 10/10 passing after the rename.

### Deferred (Not Fixed — Out of Scope)

**1. Pre-existing Rubocop offenses in generated DB schema files**
- **Found during:** Task 3 full-suite `bundle exec rubocop`
- **Symptom:** 160 `Layout/SpaceInsideArrayLiteralBrackets` offenses across `db/schema.rb`, `db/cache_schema.rb`, `db/queue_schema.rb`, `db/cable_schema.rb`.
- **Why deferred:** Confirmed via `git show <plan-01-02-commit>:db/schema.rb` that these files were byte-identical before this plan started — the offenses predate plan 01-04 entirely and were last touched by plan 01-01's migration commit (`92983bb`). None of this plan's three touched files (`app/helpers/blogs_helper.rb`, `app/views/blogs/show.html.erb`, `spec/requests/blogs_toc_spec.rb`) have any offenses — `bundle exec rubocop` on the plan's own files reports 0. Per SCOPE BOUNDARY, pre-existing issues in unrelated files are not auto-fixed.
- **Logged to:** `.planning/phases/01-toc-domain-core-regression-baseline/deferred-items.md` (commit `e6c5088`).

---

**Total deviations:** 2 auto-fixed (1 blocking, 1 bug-in-own-test), 1 deferred (pre-existing, out of scope)
**Impact on plan:** None of the deviations touched application behavior. The full-suite gate (`bundle exec rspec`) is green at 152/152 (0 failures), and the golden-master baselines from plan 01-03 pass unmodified.

## Issues Encountered

None beyond the deviations documented above.

## User Setup Required

None — no external service configuration required.

## Regression Gate Results (Task 3)

1. **`bundle exec rspec` (full suite):** 152 examples, 0 failures, 5 pending (pre-existing, unrelated to this plan)
2. **Golden-master cleanliness:** `git status --porcelain spec/fixtures/golden_master/` — empty. All 10 baselines from plan 01-03 passed without regeneration.
3. **`bundle exec rubocop`:** 0 offenses across `app/helpers/blogs_helper.rb`, `app/views/blogs/show.html.erb` (not Rubocop-scanned — `.erb`, not `.rb`), and `spec/requests/blogs_toc_spec.rb`. Repo-wide, 160 pre-existing offenses remain in 4 generated schema files, unrelated to and predating this plan (see Deferred above).
4. **Brakeman before/after:**
   - Pre-plan tree (commit `05339d4`, scanned via a temporary detached worktree): Security Warnings: 0, Ignored Warnings: 1
   - Post-plan tree (current, commit `e6c5088`): Security Warnings: 0, Ignored Warnings: 1
   - **Delta: none.** The single ignored warning in both scans is the same pre-existing, unrelated finding (`Mass Assignment` / `PermitAttributes`, `app/controllers/admin/users_controller.rb:53`, fingerprint `65572beab7e2934e069d38dddd02d57ed295a65ff20bb1bc6320b67bac540647`), already dispositioned in the repo's existing `config/brakeman.ignore` (which predates this phase — first committed at `17694fc`, contradicting RESEARCH.md's assumption that no ignore file exists; noted here for accuracy, not acted on). RESEARCH.md assumption A6 (a new XSS/unescaped-output warning on the `BlogsHelper#blog_body_with_toc_anchors` `.html_safe` call) did **not** materialize — Brakeman did not flag it, likely because the sole `.html_safe` call site's input (`Blog::TableOfContents.call(sanitized_html).to_html`) is not traceable by Brakeman's static taint analysis back to unsanitized user input through the `Nokogiri` call chain. No new suppression, ignore-file entry, or `# brakeman:ignore` comment was added.
5. **Manual endpoint check:** A TOC-enabled post's rendered `/blog/:slug` HTML contains `id="toc-...` anchors (confirmed present); its `.md` export and `/api/v1/blogs/:slug` JSON response both contain zero occurrences of `toc-` (confirmed absent). Performed via an in-process `ActionDispatch::Integration::Session` under `RAILS_ENV=test` (functionally equivalent to `curl` against a bound `bin/rails server`).

## STATE.md Blocker Discharged

The STATE.md Blockers/Concerns entry — "Tiptap StarterKit Heading dropping unknown `id` attributes on round-trip is unverified (MEDIUM confidence)" — is now moot by construction and can be closed. Plan 01-01 Task 2 proved (`spec/models/blog_spec.rb`, id-strip invariant) that an `id` attribute submitted in `body` HTML never persists to the `blogs.body` column for either `Blog` or `Article`, because `Blog::ALLOWED_ATTRIBUTES` excludes `"id"` entirely. Since the Tiptap editor always loads `body` from the database, it can never encounter a body containing an `id` attribute in the first place — there is no round-trip for Tiptap's Heading extension to corrupt. This plan's own anchor injection reinforces the same invariant from the render side: anchors are injected downstream of the sanitizer into the *rendered response only*, never written back to `body` (proven by this plan's Task 2 assertion that `blog.reload.body` excludes both `id=` and `toc-` after a TOC-on render).

## Next Phase Readiness
- TOC-03 (render-time anchor injection into `/blog/:slug`) and LAYOUT-04 (zero-regression golden-master gate) are both complete and CI-enforced.
- Phase 2 (two-column sidebar layout) can consume `Blog::TableOfContents#entries` (unused by this phase, already exposed by the plan 01-02 PORO) and must keep `bundle exec rspec spec/requests/blogs_golden_master_spec.rb` green — Layer A will catch any unintended `div.prose` markup change, Layer B will catch wrapper/layout regressions once the two-column layout lands.
- No blockers carried forward from this plan. The pre-existing schema.rb Rubocop offenses (see Deferred above) are a phase-level, not plan-level, cleanup candidate for whoever next decides on a `db/*_schema.rb` Rubocop exclusion.

---
*Phase: 01-toc-domain-core-regression-baseline*
*Completed: 2026-08-02*
