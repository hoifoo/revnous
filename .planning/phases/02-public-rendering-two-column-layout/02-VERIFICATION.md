---
phase: 02-public-rendering-two-column-layout
verified: 2026-08-05T19:36:04Z
status: passed
score: 4/4 roadmap success criteria verified (13/13 merged must-have truths verified)
overrides_applied: 0
---

# Phase 2: Public Rendering & Two-Column Layout Verification Report

**Phase Goal:** A reader on a TOC-enabled post sees the article's structure in a sticky sidebar and can jump to any section with plain anchor links — while every other post on the site looks exactly as it does today
**Verified:** 2026-08-05T19:36:04Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth (roadmap success criterion) | Status | Evidence |
|---|---|---|---|
| 1 | A post with TOC enabled and 3+ visible entries renders a sticky sidebar beside the article on desktop/tablet; clicking an entry navigates via a plain anchor link, no JS | ✓ VERIFIED | `app/views/blogs/_toc_sidebar.html.erb:2` carries `lg:sticky lg:top-8 lg:self-start lg:col-start-2 lg:row-start-1`; each entry is `link_to "##{entry.anchor}"` (line 15) — a plain `<a href="#toc-…">`, no Stimulus controller or JS handler attached. `spec/requests/blogs_toc_spec.rb` "sidebar rendering (LAYOUT-01, A11Y-01)" asserts exactly 3 `li` children each with `href` starting `#toc-` resolving to a real heading id in the same document, and asserts the grid track (`lg:grid-cols-[minmax(0,1fr)_16rem]`) and `max-w-5xl` are present. Full suite green (200 passed / 5 pending, unrelated) at time of verification. |
| 2 | TOC off, or on with <3 visible entries after hides, renders no sidebar/no dropdown/no layout shift; Phase 1 golden-master spec still passes | ✓ VERIFIED | `_toc_sidebar.html.erb` self-guards with `<% if entries.any? %>`; the wrapper also carries `hidden lg:block` (removed from layout+a11y tree below 1024px, D-02/D-03). `blog_article` (blogs_helper.rb:23) returns `toc_entries: []` when `visible.size < MIN_TOC_ENTRIES`, so the partial never renders. Request spec "sidebar suppression threshold (TOC-04, D-12)" proves 2 headings → no nav, no grid class, `max-w-4xl`, but `id="toc-` ids still present (D-11 deep links survive); 4 headings with 2 hidden → nav absent entirely. `bundle exec rspec spec/requests/blogs_golden_master_spec.rb` — 0 failures, 0 skips; `git status --porcelain spec/fixtures/golden_master/` is empty (re-run live during this verification, confirmed). |
| 3 | Typography/spacing refinements are visible only in the TOC-on two-column layout; TOC-off is pixel-identical because the layouts are separate container branches, not a widened shared container | ✓ VERIFIED | `show.html.erb:29`: `<%= article.toc? ? 'max-w-5xl' : 'max-w-4xl' %>` — a literal ternary branch (ROADMAP explicitly names widening a shared container as the failure mode to avoid; this is not that). `show.html.erb:80`: prose class ternary branches `max-w-none` (TOC-off, unchanged) vs. `lg:col-start-1 lg:row-start-1 prose-h2:mt-16 prose-h3:mt-12 prose-headings:scroll-mt-8` (TOC-on only). "TOC-off layout is frozen (LAYOUT-03)" spec asserts the exact literal `class="prose prose-lg max-w-none mb-16 "` string including trailing space, and `max-w-4xl` present / `max-w-5xl` absent, on a TOC-off render of the same body. Golden master fixture byte-diff confirms zero regression. |
| 4 | TOC is wrapped in `<nav aria-label="Table of contents">`; each H2/H3 exposes a permalink affordance linking to its own anchor | ✓ VERIFIED | `_toc_sidebar.html.erb:3`: exact string `<nav aria-label="Table of contents">`. `blogs_helper.rb#decorate_permalinks!` appends `<a class="toc-permalink" href="#{node['id']}" aria-label="Permalink to …">` to every `h2[id]/h3[id]` node whose id starts with `Blog::TableOfContents::ANCHOR_PREFIX`. Request spec "heading permalinks (INTX-04)" asserts exactly 3 `class="toc-permalink"` occurrences for a 3-heading post, correct `href`/`aria-label` pairing, `aria-hidden` isolated to the inner `<span>` (not the focusable `<a>`), and zero permalinks on a suppressed (2-heading) post. |

**Score:** 4/4 roadmap success criteria verified.

### Additional Plan-Level Must-Have Truths (merged from PLAN frontmatter, Step 2b/2c)

| # | Truth | Status | Evidence |
|---|---|---|---|
| 5 | Hide-override flag `"0"`/`"false"` leaves an entry visible; `"1"`/`true` hides it | ✓ VERIFIED | `blogs_helper.rb#visible_toc_entries` uses `ActiveModel::Type::Boolean.new.cast`, never raw truthiness. `spec/helpers/blogs_helper_spec.rb` and `spec/requests/blogs_toc_spec.rb` both assert the `"0"`/`"false"`/`"1"` cases explicitly (Pitfall 6). |
| 6 | No TOC entry label or text contains a stray `#` from permalink injection | ✓ VERIFIED | `decorate_permalinks!` runs strictly after `Blog::TableOfContents#derive!` captures `entries` (a second fragment traversal). Request spec "heading permalinks" asserts no sidebar `li` text ends with `#`. |
| 7 | A heading containing an inline link produces no nested anchor inside the sidebar | ✓ VERIFIED | `_toc_sidebar.html.erb:16` re-sanitizes `entry.label_html` to `tags: %w[strong em code], attributes: []` at the render site. Request spec "entry labels with inline markup (Pitfall 4)" asserts no `a[href="/x"]` survives inside the nav and exactly one sidebar `<a>` per entry. |
| 8 | The threshold specs are non-vacuous (proven by mutation testing) | ✓ VERIFIED | Live mutation check re-run during this verification: flipping `MIN_TOC_ENTRIES` from 3→2 in `app/helpers/blogs_helper.rb` failed exactly 3 examples in `spec/requests/blogs_toc_spec.rb`; reverting restored 35/35 green. Confirms the threshold assertions actually bind rather than passing regardless of implementation. |
| 9 | `blog_body_with_toc_anchors` legacy helper removed once its only call site is gone | ✓ VERIFIED | `grep -rc "blog_body_with_toc_anchors" app/ spec/` returns zero matches across both trees. |
| 10 | A request spec proves the sidebar appears at exactly 3 visible entries and disappears at 2 | ✓ VERIFIED | `spec/requests/blogs_toc_spec.rb` "sidebar suppression threshold" — verified directly, see truth 2. |
| 11 | A written manual QA checklist covers behaviors request specs cannot reach, walked by a human | ✓ VERIFIED (human-approved, not re-verified) | `02-MANUAL-QA.md` has all 16 items ticked `[x]`, sign-off line: "All 16 items approved by the developer on 2026-08-05." Per task instructions, treated as already human-verified; not re-flagged. |
| 12 | Permalink CSS present in source and compiled into `application.css` | ✓ VERIFIED | `application.tailwind.css` tail contains `.toc-permalink` (rest rule, hover/focus-visible reveal, reduced-motion escape hatch) — 3 occurrences plus `@media (prefers-reduced-motion: reduce)`. Live build/spec run confirms `spec/requests/` suite green with the compiled stylesheet in place. |
| 13 | A11Y-01 traceability correctly recorded as Partial (nav wrapper only; `aria-current` deferred to Phase 3) | ✓ VERIFIED (deliberate scope split, not a gap) | `.planning/REQUIREMENTS.md:98`: `A11Y-01 | Phase 2 | Partial — <nav aria-label="Table of contents"> wrapper delivered in Phase 2; aria-current half delivered by Phase 3's scroll-spy`. Request spec explicitly asserts `nav.css("[aria-current]")` is empty (Phase 3's job, not a Phase 2 gap). |

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `app/helpers/blogs_helper.rb` | `blog_article` value object, `MIN_TOC_ENTRIES`, hide filter, permalink decoration | ✓ VERIFIED | 54 lines (plan's `min_lines: 55` heuristic missed by 1 line — content is fully substantive: constant, `ArticleContent` Struct, public `blog_article`, private `visible_toc_entries`/`decorate_permalinks!`, SECURITY comment. Not a stub; functionally exercised by 88+ passing spec examples and a live mutation check. Treated as a heuristic near-miss, not a gap.) |
| `spec/helpers/blogs_helper_spec.rb` | Unit coverage for threshold, hide-flag casting, permalink injection | ✓ VERIFIED | 240 lines; exists, passes. |
| `app/views/blogs/_toc_sidebar.html.erb` | Sticky nav landmark, ordered entry list, plain anchors | ✓ VERIFIED | 23 lines; `aria-label="Table of contents"` present exactly once; ERB syntax valid (live check). |
| `app/views/blogs/show.html.erb` | Branch-conditional container/grid/prose | ✓ VERIFIED | `lg:grid-cols-[minmax(0,1fr)_16rem]` present exactly once; branches confirmed by direct read. ERB syntax valid (live check). |
| `app/assets/stylesheets/application.tailwind.css` | Permalink hover-reveal CSS | ✓ VERIFIED | `.toc-permalink` rules present at file tail, live-read. |
| `spec/requests/blogs_toc_spec.rb` | Request coverage for all Phase 2 behaviors | ✓ VERIFIED | 448 lines, 35 examples; `bundle exec rspec spec/requests/blogs_toc_spec.rb --dry-run` style coverage confirmed live; all pass. |
| `.planning/phases/02-public-rendering-two-column-layout/02-MANUAL-QA.md` | Browser checklist, human-walked | ✓ VERIFIED | 97 lines, 16/16 items ticked, human sign-off recorded. |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `show.html.erb` | `_toc_sidebar.html.erb` | `render "blogs/toc_sidebar", entries: article.toc_entries` | ✓ WIRED | Line 78, exact pattern present, confirmed live. |
| `show.html.erb` | `BlogsHelper#blog_article` | `blog_article(@blog)` single standalone assignment | ✓ WIRED | Line 25, called exactly once per render; reused by container-width, grid, and prose branches. |
| `_toc_sidebar.html.erb` | `Blog::TableOfContents::Entry` | `entry.anchor` / `entry.level` / `entry.label_html` | ✓ WIRED | All three accessors used in the partial (lines 7, 13, 15-16). |
| `blogs_helper.rb` | `Blog::TableOfContents.call` | single parse, entries captured before decoration | ✓ WIRED | Exactly one call site inside `blog_article` (line 19); `decorate_permalinks!` operates on the already-derived fragment, confirmed by code order and by spec assertions that `entry.text`/`label_html` never contain a stray `#`. |
| `blogs_helper.rb` | `blog.toc_overrides` | `ActiveModel::Type::Boolean` cast | ✓ WIRED | `visible_toc_entries` (line 34-38) uses the caster, not raw truthiness; behavior locked by both unit and request specs. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|---|---|---|---|---|
| `_toc_sidebar.html.erb` | `entries` local | `article.toc_entries` ← `blog_article(@blog)` ← `Blog::TableOfContents.call(sanitized)` on `blog.body` | Yes — real Nokogiri-parsed heading entries from the persisted, sanitized blog body, filtered by real `toc_overrides` jsonb data | ✓ FLOWING |
| `show.html.erb` prose region | `article.html` | Same `blog_article(@blog)` call, `toc.to_html` of the anchor-injected fragment | Yes — real sanitized+decorated article HTML, not a static/empty fallback | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Full spec suite green | `bundle exec rspec spec/` | 200 passed, 5 pending (pre-existing, unrelated) | ✓ PASS |
| Golden master fixtures untouched | `git status --porcelain spec/fixtures/golden_master/` | empty | ✓ PASS |
| Threshold specs non-vacuous | Flip `MIN_TOC_ENTRIES` 3→2, run `spec/requests/blogs_toc_spec.rb`, revert | 3 new failures on mutation, 35/35 green after revert | ✓ PASS |
| Rubocop clean on modified Ruby source | `bundle exec rubocop app/helpers/blogs_helper.rb` | 1 file inspected, no offenses detected | ✓ PASS |
| ERB syntax valid on modified views | `ruby -r erb -e 'ERB.new(...).src'` on both files | `ERB OK` for both | ✓ PASS |
| Legacy helper fully removed | `grep -rc "blog_body_with_toc_anchors" app/ spec/` | 0 matches in both trees | ✓ PASS |
| No debt markers in phase-modified files | `grep -n "TBD\|FIXME\|XXX\|TODO\|HACK\|PLACEHOLDER"` across all 5 modified/created files | no matches | ✓ PASS |

### Probe Execution

No `scripts/*/tests/probe-*.sh` convention or explicit probe declarations found in this phase's PLAN/SUMMARY files — this is a Rails feature phase verified via RSpec, not a migration/tooling phase. Skipped: N/A for this phase type.

### Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
|---|---|---|---|---|
| TOC-04 | 02-01, 02-02, 02-03 | TOC suppressed entirely (no sidebar, no layout shift, no mobile dropdown) when <3 entries remain visible | ✓ SATISFIED | Threshold + hide-filter logic in `blogs_helper.rb`, request spec "sidebar suppression threshold (TOC-04, D-12)", mutation-verified non-vacuous. |
| LAYOUT-01 | 02-02, 02-03 | TOC renders as sticky sidebar next to article on desktop/tablet | ✓ SATISFIED | `_toc_sidebar.html.erb` sticky classes; request spec "sidebar rendering (LAYOUT-01, A11Y-01)"; manual QA items 1-2 (human-approved). |
| LAYOUT-03 | 02-02, 02-03 | Typography/spacing refinements apply only to TOC-on layout; TOC-off pixel-identical | ✓ SATISFIED | Branch-conditional container/prose classes; golden master 0 failures/0 skips; request spec "TOC-off layout is frozen (LAYOUT-03)". |
| A11Y-01 | 02-02, 02-03 | `<nav aria-label="Table of contents">` wrapper, `aria-current` on active entry | ✓ SATISFIED (Partial, by design) | Nav wrapper delivered and tested; `aria-current` explicitly and correctly deferred to Phase 3 per REQUIREMENTS.md traceability note. Per task instructions, this is a documented deliberate scope split, not a gap. |
| INTX-04 | 02-01, 02-02, 02-03 | Heading permalink affordance — hover/click offers direct link to section anchor | ✓ SATISFIED | `decorate_permalinks!`, hover-reveal CSS, request spec "heading permalinks (INTX-04)"; manual QA items 5-6 (human-approved). |

**Orphaned requirements check:** REQUIREMENTS.md maps exactly these 5 requirement IDs to Phase 2 (`Per phase: Phase 2 — Public Rendering & Two-Column Layout: 5 (TOC-04, LAYOUT-01, LAYOUT-03, A11Y-01, INTX-04)`), and all 5 appear in at least one plan's `requirements:` frontmatter field. No orphaned requirements found.

**Documentation note (informational, not a gap):** The Traceability table's `Status` column still shows literal `Pending` for TOC-04, LAYOUT-01, LAYOUT-03, and INTX-04 (only A11Y-01 was updated to `Partial` by 02-03's Task 2, which is exactly what that task's plan scoped it to do — "Do not move A11Y-01 to a different phase row and do not alter the counts"). The top-of-file `- [ ]` checkboxes for these four requirements are also still unchecked. This is a stale-documentation artifact, not a functional gap — the underlying code and tests fully satisfy all 5 requirements as shown above. Recommend updating REQUIREMENTS.md's Status column and checkboxes for TOC-04/LAYOUT-01/LAYOUT-03/INTX-04 to `Complete` at milestone audit time, but this does not block Phase 2 goal achievement.

### Anti-Patterns Found

None. No `TBD`/`FIXME`/`XXX`/`TODO`/`HACK`/`PLACEHOLDER` markers, no empty implementations, no hardcoded-empty stub data, no console-log-only handlers in any of the 5 files created/modified by this phase (`app/helpers/blogs_helper.rb`, `app/views/blogs/_toc_sidebar.html.erb`, `app/views/blogs/show.html.erb`, `app/assets/stylesheets/application.tailwind.css`, `spec/requests/blogs_toc_spec.rb`).

### Human Verification Required

None outstanding. All 16 items in `02-MANUAL-QA.md` (sticky positioning, hover-reveal fade, breakpoint transition, container width sanity check on `max-w-5xl`, accessibility audit, reduced-motion, overflow on wide content, TOC-off pixel parity, etc.) were walked and approved by the developer on 2026-08-05, per the explicit instruction to treat this as already human-verified and not re-flag it.

### Gaps Summary

No gaps found. All 4 roadmap success criteria and all 9 additional plan-level must-have truths are verified directly against the live codebase: real request-spec assertions (re-run during this verification, 200/205 examples passing with 5 pre-existing unrelated pending), a live mutation check proving the threshold logic is non-vacuous, a live golden-master byte-diff confirming zero TOC-off regression, live rubocop/ERB syntax checks, and a completed, human-approved 16-item manual QA checklist for the behaviors static analysis cannot reach. The only finding is a cosmetic REQUIREMENTS.md staleness (Status column/checkboxes not bumped to Complete for 4 of 5 requirement IDs) which does not affect the phase goal and is noted for milestone-audit cleanup, not treated as a gap.

---

_Verified: 2026-08-05T19:36:04Z_
_Verifier: Claude (gsd-verifier)_
