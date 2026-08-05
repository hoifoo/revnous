# Roadmap: Blog Layout Upgrade — Table of Contents & Reading UX

## Overview

The blog gains an opt-in, auto-generated Table of Contents built from a single derived source of truth. The work starts in pure Ruby: a `Blog::TableOfContents` PORO that parses the already-sanitized `body`, extracts H2/H3 headings, and mints stable `toc-` prefixed anchor ids at render time — plus the two schema columns (`toc_enabled`, `toc_overrides`) and a golden-master spec that freezes today's rendering before anything visual moves. From there the public page grows a conditional two-column layout with a sticky sidebar, permalink affordances, and a typography pass scoped strictly to the TOC-on branch. Then client behavior lands: IntersectionObserver scroll-spy, focus-managed smooth scroll, sidebar auto-scroll, and the mobile "Contents" disclosure. Finally the admin form exposes the toggle and override controls so the marketing team can relabel, reorder, and hide entries — with orphaned overrides surfaced instead of silently dropped. Every phase preserves the hard constraint: a post with the TOC off renders exactly as it does today.

## Phases

**Phase Numbering:**

- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: TOC Domain Core & Regression Baseline** - Anchor-id contract, schema columns, and a golden-master spec locking today's rendering (completed 2026-08-02)
- [ ] **Phase 2: Public Rendering & Two-Column Layout** - Server-rendered sticky sidebar TOC with typography pass scoped to the TOC-on layout
- [ ] **Phase 3: Reading Navigation Behavior** - Scroll-spy, focus-managed smooth scroll, sidebar tracking, mobile Contents disclosure
- [ ] **Phase 4: Admin TOC Control** - Per-post toggle plus relabel/reorder/hide overrides with orphan handling

## Phase Details

### Phase 1: TOC Domain Core & Regression Baseline

**Goal**: The system can derive a stable, uniquely anchored TOC from any post's body HTML, and today's public rendering is frozen under an executable test before anything visual changes
**Depends on**: Nothing (first phase)
**Requirements**: TOC-01, TOC-02, TOC-03, LAYOUT-04
**Success Criteria** (what must be TRUE):

  1. Given a post body, the TOC derivation returns ordered H2/H3 entries only (H1 and H4–H6 excluded), each carrying a `toc-` prefixed anchor that is unique within the post — duplicate headings dedupe with a counter suffix, and headings that slugify to empty (emoji-only, CJK-only, punctuation-only) fall back to a positional `toc-section-N` anchor
  2. The rendered `/blog/:slug` response body — not just the model attribute — contains matching `id` attributes on exactly those H2/H3 headings, injected downstream of the last sanitizer, with `Blog::ALLOWED_ATTRIBUTES` unchanged and no `id` in any sanitizer allowlist
  3. Every post carries a `toc_enabled` boolean defaulting to false and a `toc_overrides` jsonb store, with no backfill: existing rows' `body`, `updated_at`, `seo_description`, `.md` export, and `api/v1/blogs/show.json` output are all byte-for-byte unchanged
  4. A golden-master request spec captures the current HTML of a TOC-off blog show page and passes, so any later layout change that regresses an existing post fails CI

**Plans**: 4 plans

Plans:
**Wave 1**

- [x] 01-01-PLAN.md — Add `toc_enabled`/`toc_overrides` columns with a proven zero-row-touch migration and the admin-only write seam
- [x] 01-02-PLAN.md — `Blog::TableOfContents` PORO: H2/H3 derivation, unique `toc-` anchors, inline-markup labels

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 01-03-PLAN.md — Golden-master baseline freezing today's TOC-off rendering across five curated fixtures

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 01-04-PLAN.md — Render-time anchor injection with a TOC-off short-circuit, plus the full regression gate

### Phase 2: Public Rendering & Two-Column Layout

**Goal**: A reader on a TOC-enabled post sees the article's structure in a sticky sidebar and can jump to any section with plain anchor links — while every other post on the site looks exactly as it does today
**Depends on**: Phase 1
**Requirements**: TOC-04, LAYOUT-01, LAYOUT-03, A11Y-01, INTX-04
**Success Criteria** (what must be TRUE):

  1. A post with the TOC enabled and 3+ visible entries renders a sticky sidebar beside the article on desktop/tablet; clicking an entry navigates to that section with no JavaScript involved
  2. A post with the TOC off — or enabled but with fewer than 3 entries remaining visible after admin hides — renders no sidebar, no dropdown, and no layout shift, and the Phase 1 golden-master spec still passes
  3. Typography and spacing refinements (measure, heading rhythm, vertical spacing) are visible only in the TOC-on two-column layout; the TOC-off page is pixel-identical to today because the two layouts are separate container branches, not a widened shared container
  4. The TOC is wrapped in `<nav aria-label="Table of contents">` and each H2/H3 in the article exposes a permalink affordance linking to its own anchor

**Plans**: 3 plans
**UI hint**: yes

Plans:
**Wave 1**

- [ ] 02-01-PLAN.md — Single-parse `ArticleContent` value object: hide-override filtering, 3-entry suppression threshold, heading permalink injection

**Wave 2** *(blocked on Wave 1 completion)*

- [ ] 02-02-PLAN.md — Sticky sidebar partial, byte-safe conditional two-column grid, TOC-on typography pass, permalink hover CSS

**Wave 3** *(blocked on Wave 2 completion)*

- [ ] 02-03-PLAN.md — Request-spec coverage for sidebar/threshold/a11y/permalinks, manual QA checklist, human verification gate

### Phase 3: Reading Navigation Behavior

**Goal**: A reader moves through a long post fluidly — the TOC tracks where they are, jumping lands them (and their keyboard focus) in the right place, and the mobile disclosure behaves like a real control
**Depends on**: Phase 2
**Requirements**: LAYOUT-02, INTX-01, INTX-02, INTX-03, A11Y-02, A11Y-03
**Success Criteria** (what must be TRUE):

  1. Clicking a TOC entry smooth-scrolls to that section (instant jump when `prefers-reduced-motion` is set), the heading lands clear of the sticky site header, and keyboard focus moves to the heading so screen-reader and keyboard users land where sighted users land
  2. The entry for the section currently being read is visually highlighted and marked `aria-current` as the reader scrolls, and stays correct at the very top of the page, on the final section, and on initial load from a `#anchor` deep link
  3. On a post with more than 10 headings the sidebar scrolls internally within the viewport and keeps the active entry visible without moving the page
  4. On mobile widths the TOC is a tappable "Contents" disclosure above the article that opens and closes via keyboard and Escape, reports state with `aria-expanded`, auto-closes after an entry is selected, and returns focus predictably
  5. Page-level scrolling behavior is untouched site-wide: no `scroll-behavior: smooth` on the root, and observers/listeners are torn down on Turbo navigation so repeated visits leave nothing running

**Plans**: TBD
**UI hint**: yes

### Phase 4: Admin TOC Control

**Goal**: The marketing team can turn the TOC on for a post and correct its entries — relabel, reorder, hide — entirely from the blog edit form, without touching content or code
**Depends on**: Phase 3
**Requirements**: ADMIN-01, ADMIN-02, ADMIN-03
**Success Criteria** (what must be TRUE):

  1. The blog edit form shows a TOC on/off toggle; saving it flips whether the sidebar appears on the public post, with no other change to the page
  2. Admin can relabel, reorder, and hide individual auto-generated entries in the form, and the public TOC reflects those edits on the next page load — stored as a jsonb array keyed by anchor, never spliced into `body`
  3. Relabeling an entry never changes its anchor, so existing deep links to that section keep working
  4. After body headings change, the form clearly distinguishes overrides whose heading no longer exists from newly detected headings that have no override yet — nothing is silently dropped or applied to the wrong section

**Plans**: TBD
**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. TOC Domain Core & Regression Baseline | 4/4 | Complete   | 2026-08-02 |
| 2. Public Rendering & Two-Column Layout | 0/3 | Planned | - |
| 3. Reading Navigation Behavior | 0/TBD | Not started | - |
| 4. Admin TOC Control | 0/TBD | Not started | - |

## Coverage

All 18 v1 requirements mapped to exactly one phase. No orphans, no duplicates.

| Phase | Requirements | Count |
|-------|--------------|-------|
| 1 | TOC-01, TOC-02, TOC-03, LAYOUT-04 | 4 |
| 2 | TOC-04, LAYOUT-01, LAYOUT-03, A11Y-01, INTX-04 | 5 |
| 3 | LAYOUT-02, INTX-01, INTX-02, INTX-03, A11Y-02, A11Y-03 | 6 |
| 4 | ADMIN-01, ADMIN-02, ADMIN-03 | 3 |

---
*Roadmap created: 2026-08-01*
