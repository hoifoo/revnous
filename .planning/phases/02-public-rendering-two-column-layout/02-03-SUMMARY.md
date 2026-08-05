---
phase: 02-public-rendering-two-column-layout
plan: 03
subsystem: testing
tags: [rspec, nokogiri, request-spec, accessibility, manual-qa, traceability]

# Dependency graph
requires:
  - phase: 02-public-rendering-two-column-layout (plan 01)
    provides: "BlogsHelper#blog_article(blog) returning an ArticleContent value object (html, toc_entries, toc?)"
  - phase: 02-public-rendering-two-column-layout (plan 02)
    provides: "app/views/blogs/_toc_sidebar.html.erb, branch-conditional show.html.erb, permalink hover-reveal CSS"
provides:
  - "Request-spec regression lock on sidebar presence, the 3-entry threshold (both directions), hide-override filtering, the nav accessible name, permalink structure, nested-anchor stripping, and the frozen TOC-off class string"
  - "Mutation-checked, non-vacuous threshold coverage (MIN_TOC_ENTRIES 3→2 flip fails 3 examples)"
  - "02-MANUAL-QA.md — 16-item browser checklist for sticky/hover/measure/breakpoint behavior no spec/system infra exists to automate"
  - "REQUIREMENTS.md A11Y-01 traceability corrected to Partial (Phase 2 nav wrapper / Phase 3 aria-current)"
affects: [phase-3-reading-navigation-behavior]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Nokogiri::HTML5-scoped structural assertions (nav[aria-label] → contextual .css('> li')) instead of raw response.body.scan counts, wherever a token (href=\"#toc-) can appear in more than one place"
    - "Mutation testing as an acceptance gate: flip a threshold constant, assert red, revert, assert green — proves specs are non-vacuous rather than just present"

key-files:
  created:
    - .planning/phases/02-public-rendering-two-column-layout/02-MANUAL-QA.md
  modified:
    - spec/requests/blogs_toc_spec.rb
    - .planning/REQUIREMENTS.md

key-decisions:
  - "Bare 'lg:grid-cols-' substring assertions were too broad — the site footer independently uses 'lg:grid-cols-4' for its own layout. Narrowed all TOC-grid absence assertions to the full track string 'lg:grid-cols-[minmax(0,1fr)_16rem]' to avoid a false-negative test (auto-fixed during Task 1, see Deviations)"
  - "Reused code_post/tables_post body strings from blogs_golden_master_spec.rb verbatim (copied, not required cross-file — FIXTURES is scoped inside that spec's anonymous example-group class) and each was prefixed with two extra headings to clear the 3-entry threshold for the wide-content grid-track assertions"

patterns-established:
  - "Contextual Nokogiri child-combinator selection (node.css('> li')) for scoping direct-child counts inside a landmark, avoiding descendant-selector overcounts"

requirements-completed: []  # Plan not yet complete — Task 3 (human-verify checkpoint) is pending; see below

# Metrics
duration: ~55min (Tasks 1-2 only; Task 3 checkpoint pending)
completed: 2026-08-05
---

# Phase 02 Plan 03: Automated Test Lock & Manual QA Checklist Summary

**35-example Nokogiri-scoped request-spec suite locking Phase 2's TOC sidebar/threshold/permalink/frozen-TOC-off behavior under a mutation-verified gate, plus a written 16-item manual QA checklist and REQUIREMENTS.md A11Y-01 traceability correction — Task 3's human browser walkthrough is the one remaining checkpoint**

## Performance

- **Duration:** ~55 min (Tasks 1-2)
- **Started:** 2026-08-05T21:10:00Z
- **Completed (Tasks 1-2):** 2026-08-05T22:05:00Z
- **Tasks:** 2 of 3 (Task 3 is a `checkpoint:human-verify` gate — see below)
- **Files modified:** 3 (`spec/requests/blogs_toc_spec.rb`, `.planning/REQUIREMENTS.md` modified; `.planning/phases/02-public-rendering-two-column-layout/02-MANUAL-QA.md` created)

## Accomplishments

- Extended `spec/requests/blogs_toc_spec.rb` from 10 to 35 examples, adding 7 new `describe` blocks tagged with their requirement IDs:
  - **sidebar rendering (LAYOUT-01, A11Y-01)** — exact `<nav aria-label="Table of contents">` string, `ol[role="list"]` with exactly 3 direct `li` children each linking to a real heading `id`, the visible "Table of Contents" `<p>` label, absence of `aria-current` (Phase 3's job), the grid track + `max-w-5xl` container, and DOM order (nav before `div.prose`)
  - **sidebar suppression threshold (TOC-04, D-12)** — the 2/3/4-entry boundary in both directions, single- and double-anchor hide-override filtering with the heading `id` surviving suppression (D-11), and `ActiveModel::Type::Boolean` jsonb-string casting (`"0"`/`"false"` visible, `"1"` hidden — Pitfall 6)
  - **TOC-off layout is frozen (LAYOUT-03)** — the exact `class="prose prose-lg max-w-none mb-16 "` string including its trailing space, `max-w-4xl` presence / `max-w-5xl` absence, and absence of the TOC grid track, permalink class, and nav
  - **heading permalinks (INTX-04)** — href/aria-label/inner-span structure on the `toc-intro` permalink, the untouched `<h2 id="toc-intro">` opening tag, zero leaked trailing `#` in any sidebar entry text, and zero permalinks on a suppressed post
  - **entry labels with inline markup (Pitfall 4)** — a heading containing `<a href="/x">` produces no nested anchor inside the nav and exactly one sidebar `<a>` whose text still contains all three label fragments; a heading containing `<strong>` keeps it inside the sidebar link
  - **wide content does not break the grid (Pitfall 2)** — `code_post`/`tables_post` bodies (reused verbatim from the golden-master spec, each prefixed with two headings to clear the threshold) return 200 with the `minmax(0,1fr)` track present
  - **STI coverage** — the sidebar renders identically for an `Article` STI subtype
- **Mutation check passed:** flipping `BlogsHelper::MIN_TOC_ENTRIES` from `3` to `2` fails exactly 3 new examples (the 2-heading threshold test, the double-hide-suppression test, and the suppressed-permalink-count test); reverting restores 200 passed, 5 pending across the full suite. This proves the threshold specs are non-vacuous (T-02-14).
- Full suite (`bundle exec rspec spec/`) is green: 200 passed, 5 pending (pre-existing, unrelated). Golden-master fixtures untouched (`git status --porcelain spec/fixtures/golden_master/` empty).
- Created `.planning/phases/02-public-rendering-two-column-layout/02-MANUAL-QA.md`: a setup section with exact `bin/rails console` commands to produce a TOC-on fixture (5+ headings, a wide `<pre>`, a `<table>`) and a TOC-off comparison post, followed by the 16 checklist items specified in the plan (sticky travel, hover-reveal fade, keyboard focus parity, H3 indent/de-emphasis, the 65ch measure, the 64px/48px heading rhythm, the `max-w-5xl` container-widening confirmation flagged from RESEARCH Open Question 1, the 1024px breakpoint transition, horizontal-overflow check on wide content, reduced-motion behavior, TOC-off pixel parity, and an accessibility audit pass), closed with a "Known non-defects in this phase" section (no smooth scroll, no active-entry highlight, no `aria-current`, no mobile disclosure, no sidebar auto-scroll — all explicitly Phase 3).
- Corrected `REQUIREMENTS.md`: A11Y-01's Traceability Status cell changed from `Pending` to `Partial` with an inline explanation, plus a one-line note beneath the table stating A11Y-01 spans two phases and must not be marked complete at the end of Phase 2. Coverage counts (`Unmapped: 0`) untouched; diff is 3 insertions/1 deletion on exactly the two intended spots.

## Task Commits

Each task was committed atomically:

1. **Task 1: Extend the request spec with Phase 2 coverage** - `ada4dc6` (test)
2. **Task 2: Write the manual QA checklist and correct A11Y-01 traceability** - `2103b5c` (docs)
3. **Task 3: Walk the manual QA checklist in a browser** - **NOT STARTED** (`checkpoint:human-verify`, see below)

_Note: worktree-mode execution — plan metadata commit (this SUMMARY) is committed separately by this agent; STATE.md/ROADMAP.md are owned by the orchestrator._

## Files Created/Modified

- `spec/requests/blogs_toc_spec.rb` — extended in place; 4 pre-existing `describe` blocks untouched (still green); 7 new `describe` blocks (25 new examples) added; 5 new body-fixture `let`s added alongside the existing `body_html`
- `.planning/phases/02-public-rendering-two-column-layout/02-MANUAL-QA.md` — new file; setup + 16-item checklist + known-non-defects section
- `.planning/REQUIREMENTS.md` — A11Y-01 Traceability row status corrected; one-line spanning-phases note added beneath the table

## Decisions Made

- See `key-decisions` in frontmatter — both were mechanical corrections required to make the spec assertions actually test what they claim (avoiding a false-negative from the footer's unrelated `lg:grid-cols-4`, and sourcing the wide-content fixture bodies without a cross-file constant reference).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Bare `lg:grid-cols-` substring assertion false-failed against the site footer**
- **Found during:** Task 1 first verification run (`bundle exec rspec spec/requests/blogs_toc_spec.rb`)
- **Issue:** Two new tests (`sidebar suppression threshold` at the 2-heading case, and `TOC-off layout is frozen`) asserted `expect(response.body).not_to include("lg:grid-cols-")` to prove no TOC grid track rendered. `app/views/shared/_footer.html.erb` independently ships `lg:grid-cols-4` for its own unrelated product-column layout, present on every page — the substring match caught that too, producing 2 spurious failures on markup this plan never touches.
- **Fix:** Narrowed both assertions to the full, specific track string `lg:grid-cols-[minmax(0,1fr)_16rem]` — the exact class the TOC grid emits — so the test only fails on the TOC feature actually leaking, not on unrelated footer markup.
- **Files modified:** `spec/requests/blogs_toc_spec.rb`
- **Verification:** Both tests pass; confirmed via a scoped debug spec that isolated the false-positive source before applying the fix
- **Committed in:** `ada4dc6` (Task 1 commit — fixed before the task's first commit, so no separate fix commit was needed)

**2. [Rule 1 - Bug] `linked_heading_body` fixture didn't actually contain the `<strong>` case its own test asserted**
- **Found during:** Task 1 first verification run — "keeps a `<strong>` element inside the sidebar link" failed with "expected not nil"
- **Issue:** The shared top-of-file `let(:linked_heading_body)` was defined with a plain `<h3>Third</h3>` third heading, but the "entry labels with inline markup" describe block's second test asserted a `<strong>` survives inside that same heading's sidebar link — the fixture and the assertion had drifted apart while drafting.
- **Fix:** Updated the single `linked_heading_body` definition to wrap the third heading's text in `<strong>` (`<h3><strong>Third</strong></h3>`), matching what the test actually needs; verified via a scoped debug spec dumping the rendered nav markup before and after.
- **Files modified:** `spec/requests/blogs_toc_spec.rb`
- **Verification:** Full spec file green (35/35) after the fix
- **Committed in:** `ada4dc6` (Task 1 commit — fixed before the task's first commit, so no separate fix commit was needed)

**3. [Rule 3 - Blocking] Missing `node_modules` and unbuilt assets in fresh worktree checkout**
- **Found during:** Before any spec run (baseline verification)
- **Issue:** Identical to the pattern already documented in 02-01-SUMMARY.md and 02-02-SUMMARY.md — this worktree had no `node_modules/` and no `app/assets/builds/` output, so every request spec would fail with `Propshaft::MissingAssetError`
- **Fix:** Ran `npm install` (already-declared dependencies from committed lockfiles), reverted the resulting `package-lock.json`/`yarn.lock` resync noise with `git checkout -- package-lock.json yarn.lock`, then `npm run build` and `npm run build:css`
- **Files modified:** none committed — gitignored build output; lockfile noise reverted before any task commit
- **Verification:** `git status --short` confirmed clean before each task commit; full suite green after the build
- **Committed in:** not committed (build artifacts and lockfile noise, out of scope for this plan)

---

**Total deviations:** 3 auto-fixed (2 bugs in the new spec assertions themselves, 1 blocking/environment) — none touched production code; all were self-inflicted spec-drafting corrections caught by running the specs before committing.
**Impact on plan:** No scope creep. Both spec-level bugs were fixed inside Task 1's own commit (never landed in a red state), and the environment fix matches the identical, already-documented pattern from Plans 02-01/02-02.

## Issues Encountered

None beyond the auto-fixed items above.

## User Setup Required

None - no external service configuration required.

## Known Stubs

None. This plan adds test/documentation artifacts only — no production code, no rendering paths, nothing that could stub UI data.

## Threat Flags

None. This plan adds zero production code and crosses no new trust boundary — per its own `<threat_model>`, its security value is confirming the boundaries established in Plans 02-01/02-02 hold under test, which it does (T-02-12 through T-02-15, T-02-SC all addressed via the new spec assertions and the mutation check).

## Next Phase Readiness

### CHECKPOINT PENDING — Task 3 not started

**This plan is NOT complete.** Task 3 is a `checkpoint:human-verify` gate requiring a human to walk all 16 items in `02-MANUAL-QA.md` in an actual browser — sticky positioning, hover-reveal timing, measured pixel widths, and the breakpoint transition are not observable from this agent session and must not be simulated or auto-approved per the execution protocol.

**What's ready for the checkpoint:**
- `.planning/phases/02-public-rendering-two-column-layout/02-MANUAL-QA.md` exists with its setup section and all 16 unchecked items
- `yarn build:css` has already been run in this worktree (assets are current for Task 1's spec run); re-run it if this worktree's branch is merged/rebased before the walkthrough, since the merge could reintroduce a stale `application.css`
- Two fixture-creation snippets are provided in the checklist's Setup section (a 5+-heading TOC-on post with a wide `<pre>` and a `<table>`, plus a TOC-off comparison post) — nothing has been created yet in any shared/dev database; the developer creates these when they start the walkthrough

**What the checkpoint needs from the developer:**
1. Run `yarn build:css`, then `bin/rails server`
2. Follow the Setup section in `02-MANUAL-QA.md` to create the two fixture posts and note their URLs
3. Walk all 16 checklist items at 1280px, repeating items 12-13 while narrowing through 1024px
4. Pay particular attention to item 11 (the `max-w-5xl` TOC-on container width, carried from RESEARCH Open Question 1 assumptions A6/A7 — not a locked decision, one-class change if wrong)
5. Tick each item in `02-MANUAL-QA.md` and report back: either "approved" to accept the layout as shipped, or which item failed and what was observed

**Once the developer responds:** a continuation agent should tick the confirmed items in `02-MANUAL-QA.md`, commit that file, record the developer's verbatim verdict on item 11 in this SUMMARY, and only then proceed to mark this plan's requirements (`TOC-04, LAYOUT-01, LAYOUT-03, A11Y-01, INTX-04` — A11Y-01 as Partial per the traceability correction above) complete and hand off to the orchestrator for STATE.md/ROADMAP.md updates.

- No architectural or scope concerns in Tasks 1-2's work
- Phase 3 (client behavior — scroll-spy, smooth scroll, mobile dropdown, `aria-current`) is unblocked to plan against the same server-rendered `<nav aria-label="Table of contents">` / `role="list"` / `#toc-` anchor contract Plans 02-01/02-02 shipped, once this checkpoint clears

---
*Phase: 02-public-rendering-two-column-layout*
*Completed: Tasks 1-2 only — 2026-08-05; Task 3 pending*

## Self-Check: PASSED

- FOUND: spec/requests/blogs_toc_spec.rb
- FOUND: .planning/phases/02-public-rendering-two-column-layout/02-MANUAL-QA.md
- FOUND: .planning/REQUIREMENTS.md
- FOUND: .planning/phases/02-public-rendering-two-column-layout/02-03-SUMMARY.md
- FOUND commit: ada4dc6 (test: extend request spec with Phase 2 coverage)
- FOUND commit: 2103b5c (docs: add manual QA checklist, correct A11Y-01 traceability)
