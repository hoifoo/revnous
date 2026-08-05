---
phase: 02-public-rendering-two-column-layout
plan: 02
subsystem: ui
tags: [rails, erb, tailwind, accessibility, golden-master, css]

# Dependency graph
requires:
  - phase: 02-public-rendering-two-column-layout (plan 01)
    provides: "BlogsHelper#blog_article(blog) returning an ArticleContent value object (html, toc_entries, toc?)"
provides:
  - "app/views/blogs/_toc_sidebar.html.erb — sticky right-hand nav landmark, flat role=\"list\" anchor list"
  - "Branch-conditional show.html.erb: container width, two-column grid, prose classes all keyed on article.toc?"
  - "Permalink hover-reveal CSS (.toc-permalink) with reduced-motion escape hatch, compiled into application.css"
affects: [02-03-css-layout, phase-3-scroll-spy, phase-4-admin-overrides]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Single `blog_article(@blog)` call per render assigned to a standalone-`<% %>`-line local, consumed by every branch point in the template"
    - "Independent if/end blocks (not a single wrapping if) for the grid container's opening and closing tags, so the div.prose block in between stays unconditional and byte-stable"
    - "Zero-byte standalone ERB lines at column 0 (Erubi trim) as the mechanism for adding conditional markup without disturbing frozen golden-master byte counts"
    - "Ternary branches written as complete literal Tailwind class strings (never interpolated fragments), matching Tailwind v4's plain-text source scanning"

key-files:
  created:
    - app/views/blogs/_toc_sidebar.html.erb
  modified:
    - app/views/blogs/show.html.erb
    - app/helpers/blogs_helper.rb
    - app/assets/stylesheets/application.tailwind.css

key-decisions:
  - "Sidebar link classes built via a local array joined with ' ' (each Tailwind token as its own array element) rather than one long interpolated string, so focus-visible: utilities land on separate source lines per Task 1's own acceptance grep"
  - "article = blog_article(@blog) inserted directly after the notice_banner render line (not as a new blank-line-separated paragraph) so the zero-byte Erubi-trimmed line consumes no net bytes and the existing single blank line before <!-- Hero Section --> is preserved exactly"
  - "Grid container's opening and closing <div> tags are each wrapped in their own independent `<% if article.toc? %>...<% end %>` rather than one large if spanning the whole content block, keeping the div.prose block itself unconditional and its indentation/position untouched (EDIT D constraint)"

patterns-established:
  - "Sticky-in-grid: `lg:self-start` alongside `lg:sticky lg:top-8` is mandatory — grid items default to align-self: stretch, which silently defeats position: sticky with no DevTools signal"

requirements-completed: [LAYOUT-01, LAYOUT-03, A11Y-01, INTX-04, TOC-04]

# Metrics
duration: 30min
completed: 2026-08-05
---

# Phase 02 Plan 02: Public Rendering Two-Column Layout Summary

**Sticky right-hand TOC sidebar wired into a branch-conditional two-column grid in `show.html.erb`, with permalink hover-reveal CSS — TOC-off article region remains byte-identical to its frozen golden master**

## Performance

- **Duration:** ~30 min
- **Started:** 2026-08-05T19:45:00Z
- **Completed:** 2026-08-05T20:14:00Z
- **Tasks:** 3
- **Files modified:** 4 (`app/views/blogs/_toc_sidebar.html.erb` created; `app/views/blogs/show.html.erb`, `app/helpers/blogs_helper.rb`, `app/assets/stylesheets/application.tailwind.css` modified)

## Accomplishments
- `app/views/blogs/_toc_sidebar.html.erb` — self-guarded `<nav aria-label="Table of contents">` wrapping a flat `role="list"` `<ol>` of plain `#toc-` anchor links; H3 entries indented and de-emphasized (D-06); every sticky-in-grid class present (`lg:col-start-2 lg:row-start-1 lg:self-start lg:sticky lg:top-8`, plus overflow clipping for long posts); re-sanitizes `entry.label_html` to `%w[strong em code]` at the render site to prevent a nested-`<a>` break (T-02-07); hover-only reveal is never used without a `focus-visible` pair (SC 2.4.7)
- `show.html.erb` now calls `blog_article(@blog)` exactly once per render, assigned to a zero-byte standalone-`<% %>` line; container width, the two-column grid wrapper, and prose classes all branch on `article.toc?`
- The grid container is `lg:grid lg:grid-cols-[minmax(0,1fr)_16rem] lg:gap-12` — `minmax(0,1fr)` (not bare `1fr`) prevents `<pre>`/`<table>` content from blowing out the article track (T-02-09); the sidebar renders before the article `<div>` in DOM order (WCAG 1.3.2) while landing visually right via `lg:col-start-2`
- TOC-on prose gets `lg:col-start-1 lg:row-start-1 prose-h2:mt-16 prose-h3:mt-12 prose-headings:scroll-mt-8` and drops `max-w-none` so the typography plugin's own 65ch measure binds (D-13); TOC-off prose is byte-identical to the pre-plan template
- Legacy `blog_body_with_toc_anchors` deleted from `BlogsHelper`; zero references remain anywhere in `app/` or `spec/`
- `.toc-permalink` CSS: invisible at rest (opacity 0, gray-500), reveals to pink-600 on parent-heading hover or the glyph's own `:focus-visible`, with a `prefers-reduced-motion: reduce` escape hatch; rebuilt `application.css` so this plan's new Tailwind utilities resolve through Propshaft in a fresh worktree
- Golden master spec (`spec/requests/blogs_golden_master_spec.rb`) is fully green with **zero fixture regeneration** — both the byte-exact `div.prose` region and the normalized full page match their frozen baselines

## Task Commits

Each task was committed atomically:

1. **Task 1: Create the TOC sidebar partial** - `2e20483` (feat)
2. **Task 2: Wire the byte-safe conditional two-column layout into show.html.erb** - `f4d4407` (feat)
3. **Task 3: Add permalink hover-reveal CSS and rebuild the stylesheet** - `b93d50e` (feat)

_Note: worktree-mode execution — plan metadata commit (this SUMMARY) is committed separately by this agent; STATE.md/ROADMAP.md are owned by the orchestrator._

## Files Created/Modified
- `app/views/blogs/_toc_sidebar.html.erb` — new partial; sticky sidebar nav, flat anchor list, re-sanitized labels
- `app/views/blogs/show.html.erb` — single `blog_article(@blog)` call; branch-conditional container width, grid wrapper, prose classes; legacy helper call site removed
- `app/helpers/blogs_helper.rb` — `blog_body_with_toc_anchors` and its dedicated SECURITY comment block deleted; `blog_article`'s own SECURITY comment left untouched
- `app/assets/stylesheets/application.tailwind.css` — `.toc-permalink` rest/reveal/reduced-motion rules appended after the existing tiptap custom-CSS block; `application.css` rebuilt (gitignored, not committed)

## Decisions Made
- See `key-decisions` in frontmatter above — all three were mechanical choices required to satisfy the plan's explicit byte-safety and acceptance-grep constraints, not scope changes.

## Deviations from Plan

None functionally — plan executed as written, task-for-task and edit-for-edit as specified. One environment-setup fix was required to run verification (matches the identical, already-documented Plan 02-01 pattern for this worktree).

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Missing `node_modules` and unbuilt assets in fresh worktree checkout**
- **Found during:** Task 2 verification (`bundle exec rspec spec/requests/blogs_golden_master_spec.rb ...`)
- **Issue:** All 33 request specs in the verify command failed with `Error: The asset 'application.css' was not found in the load path` — this worktree had no `node_modules/` and no `app/assets/builds/` output (fresh worktree checkout, `app/assets/builds/` is gitignored)
- **Fix:** Ran `npm install` (already-declared dependencies from the committed `package.json`/lockfiles, not a new or unverified package), then reverted the resulting `package-lock.json`/`yarn.lock` resync noise with `git checkout -- package-lock.json yarn.lock`, then ran `npm run build` and `npm run build:css` (also re-run explicitly at the end of Task 3 per that task's own action) to compile the asset pipeline
- **Files modified:** none committed — `app/assets/builds/*` is gitignored build output; lockfile noise was reverted before any task commit and confirmed via `git status --short`
- **Verification:** Full spec suite (175 examples, 5 pending — all pre-existing pending, none related to this plan) green after asset build; `git status --porcelain` confirmed clean of anything beyond the plan's four target files before each task commit
- **Committed in:** not committed (build artifacts and lockfile noise, out of scope for this plan)

---

**Total deviations:** 1 auto-fixed (blocking/environment)
**Impact on plan:** Necessary to run and pass verification; no application code beyond the four planned files was touched, and no lockfile/build-artifact changes were committed.

## Issues Encountered

None beyond the auto-fixed environment issue above.

## User Setup Required

None - no external service configuration required.

## Known Stubs

None. `article.toc_entries` on a TOC-off post is always `[]`, which correctly short-circuits `_toc_sidebar.html.erb`'s self-guard (`<% if entries.any? %>`) to render nothing — this is intended behavior (D-01/D-02), not a stub.

## Threat Flags

None. All threat-model dispositions (T-02-07 through T-02-11, T-02-SC) were addressed exactly as specified: `sanitize(entry.label_html, tags: %w[strong em code], attributes: [])` at the sidebar render site, `link_to "##{entry.anchor}"` for Rails-escaped hrefs, `minmax(0,1fr)` for the grid track, byte-safe standalone-`<% %>` lines for the TOC-off regression guard, container width kept strictly branch-conditional (never a shared widen), and zero new packages installed (`yarn build:css` used the already-installed `@tailwindcss/cli`).

## Next Phase Readiness

- `_toc_sidebar.html.erb`, the two-column grid, and the permalink CSS are all in place and covered by the full request-spec suite (`bundle exec rspec spec/` — 175 passed, 5 pending unrelated)
- Plan 02-03 (per ROADMAP) can build on this branch-conditional layout for further CSS/layout polish or additional golden-master fixture coverage (`code_post`, `tables_post` already exercise the `minmax(0,1fr)` grid track per T-02-09's mitigation note)
- Phase 3 (client behavior — scroll-spy, smooth scroll, mobile dropdown) has a stable server-rendered `<nav aria-label="Table of contents">` / `role="list"` / `#toc-` anchor contract to progressively enhance; no `aria-current` or active-state styling exists yet by design (explicitly out of contract for this plan)
- No architectural or scope concerns

---
*Phase: 02-public-rendering-two-column-layout*
*Completed: 2026-08-05*

## Self-Check: PASSED

- FOUND: app/views/blogs/_toc_sidebar.html.erb
- FOUND: app/views/blogs/show.html.erb
- FOUND: app/helpers/blogs_helper.rb
- FOUND: app/assets/stylesheets/application.tailwind.css
- FOUND: .planning/phases/02-public-rendering-two-column-layout/02-02-SUMMARY.md
- FOUND commit: 2e20483 (feat: create TOC sidebar partial)
- FOUND commit: f4d4407 (feat: wire byte-safe conditional two-column layout)
- FOUND commit: b93d50e (feat: permalink hover-reveal CSS + rebuild stylesheet)
