# Blog Layout Upgrade — Table of Contents & Reading UX

## What This Is

An enhancement to the Revnous public blog that adds an optional, auto-generated Table of Contents to individual blog posts — a sticky sidebar (collapsible dropdown on mobile) that scroll-spies the active section and smooth-scrolls on click, matching the pattern on views4you.com's blog. Paired with a reading-experience UX pass (typography, spacing, active-section highlighting) on the blog show page. Admin gets a per-post toggle plus the ability to override/reorder/hide auto-generated TOC entries.

## Core Value

A reader on a long blog post can see the article's structure at a glance and jump straight to any section — without the marketing team touching code or affecting how any existing post looks.

## Requirements

### Validated

- ✓ Tiptap editor producing sanitized HTML in `blogs.body` (replaces old Trix/ActionText) — prior milestone
- ✓ Author profiles (avatar, bio, Person schema) linked to `User`, rendered via `_author_card.html.erb` — prior milestone
- ✓ SEO fields: keywords, canonical URL override, OG image override, FAQ schema (`_faq_section.html.erb`) — prior milestone
- ✓ `Blog` model sanitizes body HTML server-side (`Rails::Html::SafeListSanitizer`, fixed `ALLOWED_TAGS`) — existing
- ✓ Public blog show/index pages at `app/views/blogs/show.html.erb`, `index.html.erb` — existing

### Active

- [ ] Blog post (and `Article` STI subtype) has a per-post toggle (default OFF) to enable Table of Contents
- [ ] TOC entries auto-generate from H2/H3 headings only in the sanitized `body` HTML (legacy H1-only content simply produces no TOC until rewritten — acceptable since the feature is opt-in)
- [ ] TOC suppressed entirely (no sidebar, no layout shift) when fewer than 3 visible entries remain after admin hides
- [ ] Admin can override generated TOC: relabel, reorder, or hide individual entries, stored as a `jsonb` column keyed by anchor (not spliced into `body` itself)
- [ ] Each heading gets a stable, unique anchor `id` (`toc-` prefixed, deduped, blank/CJK/emoji-safe) injected at render time, after sanitization — never added to the sanitizer's attribute allowlist
- [ ] TOC renders as a sticky sidebar next to the article body on desktop/tablet
- [ ] TOC collapses into a tappable "Contents" dropdown above the article on mobile widths
- [ ] Clicking a TOC entry smooth-scrolls to the corresponding section and moves focus to it (keyboard/screen-reader users)
- [ ] Active section is highlighted in the TOC as the reader scrolls (scroll-spy via IntersectionObserver)
- [ ] Reading-experience pass (typography/spacing) applies only to the new TOC-on two-column layout — the TOC-off layout is untouched
- [ ] Existing published posts (and any post with TOC off) render exactly as before — zero visual/layout regression, verified with a golden-master test
- [ ] Admin UI (blog edit form) exposes the TOC toggle and entry-override controls, mirroring the existing `faq_builder` pattern

### Out of Scope

- Multi-page blog posts (`/blog/:slug/:sub-page` sub-pages, TOC items navigating between pages instead of scrolling within one page) — user's own idea for a *future* feature project, explicitly not this project
- Extracting the blog section into a standalone Rails gem / generic CMS (blogs + product tutorials + docs) for reuse across other Revnous projects — desired long-term direction, but user decided extraction happens in a separate project after this feature ships; do not couple this work to gem boundaries
- Broader navigation/discovery UX (related posts redesign, category browsing, on-blog search) — user scoped UX work down to reading experience + TOC layout only

## Context

- This is a follow-on to the "Blog CMS & SEO Overhaul" milestone (archived at `.planning/_archive/v1-blog-cms-seo-overhaul/`), which shipped Tiptap, author profiles, and SEO/FAQ schema fields. That milestone's phase 3 was left at 13/19 requirements complete when this project started; it's archived as reference, not abandoned mid-task — this project has its own independent scope.
- Reference UX pattern: https://views4you.com/blog/move-tiktok-audience-to-instagram/ — sticky sidebar TOC, scroll-spy active-section highlight, smooth-scroll on click. (Site returned HTTP 403 to automated fetch; behavior confirmed via user description, not direct inspection — verify visually during implementation if precise details matter.)
- `Blog#body` stores pre-sanitized HTML (`ALLOWED_TAGS` in `app/models/blog.rb`) — TOC heading extraction must parse this HTML server-side or client-side without re-introducing XSS risk.
- Existing headings in body HTML currently have no guaranteed `id` attributes — anchor IDs need to be injected (either at save-time via sanitizer pass, or at render-time) without breaking the existing sanitization allowlist.

## Constraints

- **Tech stack**: Rails/Stimulus/esbuild only — no React/Vue for the TOC/scroll-spy behavior (matches project-wide constraint)
- **Backward compatibility**: TOC must be strictly opt-in (default off); existing posts must render identically until an admin explicitly enables it
- **No new editor storage format**: TOC generation reads the existing sanitized `body` HTML column — no schema change to how content itself is stored
- **Scope discipline**: Gem extraction and multi-page posts are explicitly parked; do not let this project's plan grow to cover them

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| TOC entries are auto-generated with manual override, not purely manual or purely automatic | Zero admin work by default (auto), but marketing team can fix bad heading labels without touching code (override) | — Pending |
| Default TOC state is OFF per post | Explicit requirement: must not impact old blogs | — Pending |
| Scroll-spy + sticky sidebar + smooth scroll, mobile collapses to dropdown | Matches confirmed reference pattern from views4you.com | — Pending |
| Multi-page posts (`/blog/:slug/:sub-page`) deferred | User's own idea, explicitly flagged as a future project not this one | — Pending |
| Gem/CMS extraction deferred to separate project | User: "extraction can be done in separate projects" — keep this project focused on the TOC feature | — Pending |
| Heading scope is H2/H3 only, not in-body H1 | Research found 100% of dev-DB posts have zero H2/H3 (legacy Trix used H1); including H1 would require title-vs-section disambiguation. Accepted the tradeoff — feature is opt-in, legacy posts wait until rewritten | — Pending |
| Typography/spacing pass scoped to TOC-on layout only | PROJECT.md originally required both a global typography pass and zero regression when TOC is off — contradictory. Resolved: reading-experience polish only applies to the new two-column layout | — Pending |
| `Article < Blog` STI subtype included in TOC scope | Inherits column/template automatically; no reason to special-case it | — Pending |
| Anchor IDs injected at render time (never persisted to `body`, never added to sanitizer allowlist) | `show.html.erb` re-sanitizes at render with an allowlist lacking `id` — persisting IDs in `body` would still get stripped. Injecting post-sanitization avoids a backfill migration and avoids opening a DOM-clobbering surface | — Pending |
| Admin overrides stored as `jsonb` keyed by anchor, following the `keywords` column pattern | Matches existing house style; avoids the ~30 lines of custom writer/parser ceremony the `faq_schema` text-column pattern requires | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-08-01 after initialization*
