# Requirements: Blog Layout Upgrade — Table of Contents & Reading UX

**Defined:** 2026-08-01
**Core Value:** A reader on a long blog post can see the article's structure at a glance and jump straight to any section — without the marketing team touching code or affecting how any existing post looks.

## v1 Requirements

### TOC Generation

- [ ] **TOC-01**: Admin can toggle Table of Contents on/off per post (Blog and Article STI subtype), default OFF
- [ ] **TOC-02**: TOC entries auto-generate from H2/H3 headings in the sanitized `body` HTML (H1, H4-H6 not included)
- [ ] **TOC-03**: Every listed heading gets a stable, unique anchor `id` (`toc-` prefixed, deduplicated on collision, safe positional fallback for headings that slugify to empty — e.g. emoji/CJK-only text), injected at render time after sanitization — never added to the sanitizer's attribute allowlist
- [ ] **TOC-04**: TOC is suppressed entirely (no sidebar, no layout shift, no mobile dropdown) when fewer than 3 entries remain visible after admin hides

### Layout & Placement

- [ ] **LAYOUT-01**: TOC renders as a sticky sidebar next to the article body on desktop/tablet widths
- [ ] **LAYOUT-02**: TOC collapses into a tappable "Contents" dropdown above the article on mobile widths, auto-closing after an entry is selected
- [ ] **LAYOUT-03**: Reading-experience typography/spacing refinements apply only to the new TOC-on two-column layout — the TOC-off layout is pixel-identical to today
- [ ] **LAYOUT-04**: Existing published posts (and any post with TOC off) render with zero visual/layout regression, verified with a golden-master test

### Interaction

- [ ] **INTX-01**: Clicking a TOC entry smooth-scrolls to the corresponding section, gated on `prefers-reduced-motion`, with correct scroll offset (`scroll-margin-top`) so the sticky header doesn't cover the target
- [ ] **INTX-02**: Active section is highlighted in the TOC as the reader scrolls (scroll-spy via IntersectionObserver), correct at page top, at the last section, and on initial load via a `#hash` deep link
- [ ] **INTX-03**: TOC sidebar internally scrolls and keeps the active entry in view when the entry list is taller than the viewport (long posts, >10 headings)
- [ ] **INTX-04**: Heading permalink affordance — hovering/clicking a heading offers a direct link to that section's anchor

### Accessibility

- [ ] **A11Y-01**: TOC is wrapped in `<nav aria-label="Table of contents">` with the active entry marked `aria-current`
- [ ] **A11Y-02**: Clicking a TOC entry moves keyboard focus to the target heading (not just scroll position), so keyboard/screen-reader users land where sighted users land
- [ ] **A11Y-03**: Mobile "Contents" dropdown is a real disclosure control (`aria-expanded` button or `<details>/<summary>`), fully keyboard-operable

### Admin

- [ ] **ADMIN-01**: Blog edit form exposes the TOC on/off toggle
- [ ] **ADMIN-02**: Admin can relabel, reorder, or hide individual auto-generated TOC entries; overrides stored as a `jsonb` column keyed by anchor (never spliced into `body` itself)
- [ ] **ADMIN-03**: When body headings change after an override was set, the admin UI surfaces orphaned overrides (heading removed/changed) and new un-overridden headings clearly, rather than silently dropping or misapplying overrides

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Reading Polish

- **POLISH-01**: Reading progress indicator (contested UX value; add if requested)
- **POLISH-02**: "Back to top" control for long posts
- **POLISH-03**: Print stylesheet handling for the TOC sidebar
- **POLISH-04**: Numbered TOC entries (1, 2, 2.1)
- **POLISH-05**: Estimated reading time near the TOC

### TOC Behavior

- **TOCV2-01**: H3 entries collapse under the active H2 instead of always-visible flat indentation
- **TOCV2-02**: CSS-only `:target-current` scroll-spy as a progressive-enhancement layer, once Baseline
- **TOCV2-03**: Persisted (rename-stable) anchor ID mapping, if a heading rename ever breaks a real inbound deep link
- **TOCV2-04**: TOC click engagement analytics

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Multi-page blog posts (`/blog/:slug/:sub-page`) | User's own idea for a future feature project, explicitly not this one |
| Extracting the blog section into a reusable Rails gem / generic CMS | Desired long-term direction; user decided extraction happens in a separate project after this feature ships |
| Broader navigation/discovery UX (related-posts redesign, category browsing, on-blog search) | User scoped UX work down to reading experience + TOC layout only |
| H4–H6 headings in the TOC | A deep TOC stops being scannable; fix is better headings, not a deeper TOC |
| Client-side JS-only TOC generation | Invisible to crawlers/no-JS readers, causes layout shift, deep links fail on load |
| Auto-inserting inline TOC markup into `body` | Mutates stored content; can't cleanly toggle off; breaks Tiptap round-trip; would corrupt `seo_description`/`.md` export/JSON API which all read `body` directly |
| Fully manual (non-heading-backed) TOC entries | Creates entries with no scroll target; auto-generate + override already covers the real need |
| TOC structured data (`SiteNavigationElement`, custom `ItemList`) | Jump-to sitelinks are algorithmic from real anchor links; markup can't force them, and this is the same misuse pattern that got FAQPage penalized |
| Persisting per-user TOC collapse state (localStorage/cookie) | Drags in cookie-consent machinery for a trivial UI preference; deterministic defaults suffice |
| Backfilling/auto-enabling TOC on existing posts | Directly contradicts default-OFF, zero-regression constraint |
| Floating action button / overlay TOC on mobile | Overlays content, competes with cookie-consent banner/CTAs, needs focus trapping |
| Extending TOC to case studies, legal documents, or index pages | Scope creep into models with different content shapes; `Article` (STI) is free/in-scope, others are not |
| Rich TOC entries (icons, thumbnails, per-section read time) | Multiplies admin override surface for little value; text + hierarchy matches the reference UX |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| TOC-01 | Phase 1 | Pending |
| TOC-02 | Phase 1 | Pending |
| TOC-03 | Phase 1 | Pending |
| TOC-04 | Phase 2 | Pending |
| LAYOUT-01 | Phase 2 | Pending |
| LAYOUT-02 | Phase 3 | Pending |
| LAYOUT-03 | Phase 2 | Pending |
| LAYOUT-04 | Phase 1 | Pending |
| INTX-01 | Phase 3 | Pending |
| INTX-02 | Phase 3 | Pending |
| INTX-03 | Phase 3 | Pending |
| INTX-04 | Phase 2 | Pending |
| A11Y-01 | Phase 2 | Pending |
| A11Y-02 | Phase 3 | Pending |
| A11Y-03 | Phase 3 | Pending |
| ADMIN-01 | Phase 4 | Pending |
| ADMIN-02 | Phase 4 | Pending |
| ADMIN-03 | Phase 4 | Pending |

**Coverage:**
- v1 requirements: 18 total
- Mapped to phases: 18 ✓
- Unmapped: 0

**Per phase:**
- Phase 1 — TOC Domain Core & Regression Baseline: 4 (TOC-01, TOC-02, TOC-03, LAYOUT-04)
- Phase 2 — Public Rendering & Two-Column Layout: 5 (TOC-04, LAYOUT-01, LAYOUT-03, A11Y-01, INTX-04)
- Phase 3 — Reading Navigation Behavior: 6 (LAYOUT-02, INTX-01, INTX-02, INTX-03, A11Y-02, A11Y-03)
- Phase 4 — Admin TOC Control: 3 (ADMIN-01, ADMIN-02, ADMIN-03)

---
*Requirements defined: 2026-08-01*
*Last updated: 2026-08-01 after roadmap creation (traceability mapped)*
