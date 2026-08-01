# Project Research Summary

**Project:** Blog Layout Upgrade — Table of Contents & Reading UX
**Domain:** Server-rendered Rails 8 + Hotwire blog — auto-generated TOC, heading anchors, scroll-spy, sticky/collapsible navigation, admin override
**Researched:** 2026-08-01
**Confidence:** HIGH

## Executive Summary

This is a well-trodden CMS feature (every mature blog platform ships one) being retrofitted onto a codebase with two specific hazards: the body HTML is sanitized **twice** with an allowlist that omits `id`, and **100% of existing posts contain zero H2/H3 headings**. The feature itself is small — one Ruby PORO, two columns, one Stimulus controller, two partials. Zero new gems, zero new npm packages: Nokogiri (already transitive via loofah), Stimulus 3.2.2, native `IntersectionObserver`, and Tailwind v4 utilities cover everything. The research is unanimous that no dependency should be added.

The single load-bearing decision, and all four research tracks converge on it: **inject heading `id`s at render time, after sanitization, never in the sanitizer allowlist.** A `Blog::TableOfContents` PORO takes `(body, toc_overrides)`, runs `sanitize` → `Nokogiri::HTML5.fragment` → inject machine-generated `toc-`-prefixed slugs → serialize. Because injection happens downstream of the sanitizer and the slug character class is `[a-z0-9-]`, no author-controlled string ever reaches an `id` — which means `Blog::ALLOWED_ATTRIBUTES` stays untouched, no DOM-clobbering surface opens, no `body` backfill migration runs, and no `updated_at` gets bumped across the archive. FEATURES.md's "add `id` to the allowlist" framing is the one dissent and it should be rejected: STACK, ARCHITECTURE, and PITFALLS all independently show it incurs the security cost without delivering stability (Tiptap's StarterKit Heading node drops unknown attributes on editor round-trip anyway). Overrides live in a `jsonb` column keyed by anchor, following the existing `keywords` precedent — **not** the `faq_schema` text-holding-JSON pattern, which costs ~30 lines of custom writer/parser/rescue ceremony to emulate what Postgres does natively.

The three risks that actually threaten delivery are not technical. First: **an audit of the dev DB found 10/10 posts with zero H2/H3 headings** (all headings are legacy Trix `<h1>`), so an H2/H3-only extractor ships an empty TOC on every current post. **Resolved during questioning: H2/H3 only, matching original scope — legacy posts simply won't have a usable TOC until rewritten, which is fine since the feature is opt-in.** Second: PROJECT.md contained a **direct contradiction** — "reading-experience typography pass" versus "existing posts render exactly as before." **Resolved: typography/spacing polish is scoped to the new TOC-on two-column layout only; posts with TOC off keep today's exact layout untouched.** Third: the zero-regression constraint is most likely to be violated by widening `max-w-4xl` on the shared container that also wraps the title, hero image, and excerpt — the mitigation is two explicit layout branches plus a golden-master request spec landed *before* the layout change.

## Key Findings

### Recommended Stack

Nothing to install. Every capability the feature needs is already in `Gemfile.lock` and `package.json`, and every candidate addition (tocbot, `stimulus-use`, `@tiptap/extension-table-of-contents`, ViewComponent, Nokolexbor) was evaluated and rejected — mostly because they build the TOC client-side, which forfeits crawler visibility, `view-source` anchors, CLS stability, and the admin-override capability all at once.

**Core technologies:**
- **Nokogiri `HTML5.fragment`** (1.18.10 locked) — parse sanitized body, extract `h2`/`h3`, inject anchor ids — gumbo parser matches browser tree construction, so server-generated ids can't desync from the client DOM. `Nokogiri::HTML()` (no `.fragment`) wraps content in DOCTYPE/`<html>`/`<body>` — verified, and the most-copied Rails tutorial gets this wrong.
- **PostgreSQL `jsonb`** — `toc_overrides` ordered array of `{anchor, label, hidden}` — mirrors the proven `keywords` column on the same table; array order *is* TOC order, so no `position` integers to keep consistent.
- **Boolean `toc_enabled`, `default: false, null: false`** — per-post opt-in enforced at the schema level, a stronger zero-regression guarantee than a view conditional.
- **Stimulus 3.2.2** (already latest) — `toc_controller.js` for scroll-spy, smooth scroll, mobile collapse — house style is `faq_builder_controller.js`: thin, targets-based, no external deps.
- **Native `IntersectionObserver`** — scroll-spy — runs off the main thread; no scroll-event throttling, no per-frame `getBoundingClientRect()` layout thrash.
- **Tailwind v4** (4.1.14 locked) — `sticky top-* self-start max-h-[calc(100vh-8rem)] overflow-y-auto overscroll-contain` sidebar recipe; `scroll-mt-*` on headings for anchor offset.
- **`ActiveSupport#parameterize`** — slug generation — but **must be wrapped**: verified to return `""` for CJK and emoji, and to collide on duplicate headings.

### Expected Features

**Must have (table stakes):**
- Server-rendered TOC list of H2/H3 with working anchor links
- Stable unique heading `id`s with `-2`/`-3` dedupe and `section-N` fallback for empty slugs
- Per-post toggle, default OFF, TOC-off render path byte-identical to today
- Smooth scroll gated on `prefers-reduced-motion` + `scroll-margin-top` on headings
- Sticky sidebar desktop/tablet; collapsible "Contents" disclosure on mobile, rendered **once** and repositioned by CSS
- Scroll-spy with a `rootMargin` reading band, correct at page top, at the last section, and on hash deep-link load
- Accessibility floor: `<nav aria-label>`, `aria-current="location"`, focus moved to target heading on click, real `<button aria-expanded>` for the mobile disclosure
- Minimum-visible-entry threshold (suppress below 3, counted **after** hides)
- Admin override: relabel / reorder / hide, with graceful orphan handling when headings change

**Should have (competitive):**
- TOC internal scroll + auto-scroll active item into view (needed once a post has >10 headings)
- H3 flat indentation under H2 (not collapse-under-active — that doubles the scroll-spy state machine)
- Heading permalink `#` affordance — nearly free once ids exist
- Reading time estimate near the TOC

**Defer (v2+):**
- Reading progress bar (contested UX value)
- `scroll-target-group` / `:target-current` CSS-only spy — Chromium-only, not Baseline
- TOC engagement analytics
- Persisted ID mapping for rename-proof deep links
- H4–H6, manual (non-heading-backed) entries, TOC structured data, floating mobile FAB, extension to case studies/legal docs

### Architecture Approach

Derive-don't-store: the TOC and anchor ids are never persisted; only the admin's *deviations* (`toc_overrides`) and the *toggle* (`toc_enabled`) are stored, and everything else is recomputed from `body` on every render (benchmarked at 2.5–3.3 ms worst case on a 65–99 KB / 30-heading post). The same PORO serves both the public page and the admin form — non-negotiable: divergent anchor algorithms produce override rows keyed to anchors that don't exist, and every override becomes a silent no-op.

**Major components:**
1. **`Blog::TableOfContents`** (`app/models/blog/table_of_contents.rb`) — pure function of `(body, toc_overrides)`; extracts headings, generates ids, merges overrides, returns `#entries` and `#body_html`. `Data.define(:anchor, :label, :level, :hidden)` for entries.
2. **Migration + `Blog`** — `toc_enabled:boolean` and `toc_overrides:jsonb`, plus `normalize_toc_overrides`. No backfill, no `body` rewrite, inert-by-default for the `Article` STI subclass (confirmed in scope — same toggle/render path).
3. **`BlogsHelper` + `_article_body` / `_table_of_contents` partials + `show.html.erb` branch** — helper is a memoizing adapter with no logic; `show.html.erb` branches at the *container* level so the TOC-off path is structurally identical to today.
4. **`toc_controller.js`** — one controller on the grid wrapper; IntersectionObserver scroll-spy, smooth scroll with focus management, mobile panel toggle, `disconnect()` + the app's `teardown()` convention.
5. **Admin surface** — strong params `toc_overrides: [:anchor, :label, :hidden]` (same nested-array shape as `faq_schema`), `_toc_row_fields.html.erb`, `toc_builder_controller.js` mirroring `faq_builder_controller.js`.

### Critical Pitfalls

1. **The render-time `sanitize` in `show.html.erb:76` silently deletes every heading `id`** — verified. Fixing only the model allowlist passes `rails console` checks while the page stays broken. Inject *after* the last sanitizer in the chain; assert `id=` in the **rendered response body**, not the model attribute.
2. **100% of existing posts have zero H2/H3 headings** — verified against the dev DB. Resolved: H2/H3-only scope stands; empty/thin-TOC fallback renders nothing, no layout change, no error.
3. **The "typography pass" vs "zero visual regression" contradiction** — resolved: typography scoped to TOC-on layout only.
4. **Widening `max-w-4xl` regresses every existing post** — the shared container wraps title, hero image, excerpt, *and* body. Two explicit branches, not conditional class interpolation. Land a golden-master request spec **before** the layout change.
5. **Naive slug generation breaks four ways** — duplicates, digit-leading (`querySelector` DOMException), empty (CJK/emoji → `""`), DOM-clobbering values. Prefix every id with `toc-`, dedupe with a seen-counter, fall back to `toc-section-N`; use `getElementById` in JS, never string-concatenated selectors.
6. **Never write TOC markup into `body`** — `Blog#seo_description` is `strip_tags(body).truncate(160)`, and `.md` export / `api/v1/blogs/show.json` read `body` directly. Splicing nav markup in would regress meta descriptions and API output site-wide.

## Implications for Roadmap

### Phase 1: TOC Domain Core
**Rationale:** Pure Ruby, no UI, no render path. Defines the anchor-id contract every other component references.
**Delivers:** `Blog::TableOfContents` PORO (extract → slug → dedupe → merge overrides); migration adding `toc_enabled` + `toc_overrides`; `Blog#toc?` and `normalize_toc_overrides`; golden-master request spec capturing today's TOC-off rendering.
**Avoids:** Pitfalls 1, 2, 5 (extract with `.text`, never `inner_html`).
**Specs must cover:** duplicate headings, punctuation-only, CJK/emoji, digit-leading, empty body, no-headings body, HTML5 fragment round-trip fidelity, idempotency, and `seo_description`/`.md`/JSON output unchanged.

### Phase 2: Public Rendering & Layout
**Rationale:** First demoable vertical slice — auto-TOC works end-to-end with empty overrides. Validates the layout switch and zero-regression guarantee before any admin surface exists.
**Delivers:** `BlogsHelper` adapter; `_article_body.html.erb` extracted verbatim; `_table_of_contents.html.erb` (one `<nav>`, one `<aside>`, mobile `<button aria-expanded>`); conditional two-column grid in `show.html.erb`; entry-threshold suppression; sticky sidebar CSS; typography/spacing pass scoped to the TOC-on layout.
**Avoids:** Pitfalls 1, 3, 4.
**Manual QA matrix is a deliverable:** 2-heading post, 25-heading post, article shorter than the sidebar, 1280/1024/768px widths, footer non-overlap.

### Phase 3: Client Behavior (Scroll-Spy & Navigation)
**Rationale:** Needs real anchored headings in the DOM to develop against. Cleanly separable from layout.
**Delivers:** `toc_controller.js` — IntersectionObserver with a reading band, active state recomputed as a pure function of the intersecting set, explicit top/bottom-of-document handling, `scrollIntoView` gated on `prefers-reduced-motion`, `history.pushState` for the hash, focus management after scroll settles, mobile toggle with Escape + focus return, `disconnect()` + `teardown()`.
**Hard rule:** no `scroll-behavior: smooth` on `html`/`:root` — breaks Turbo restoration visits site-wide.
**Flag for phase research:** `rootMargin` tuning is LOW confidence (community starting point); no `spec/system` infra exists in this repo — decide whether to stand one up or use a written manual QA checklist.

### Phase 4: Admin Override UI
**Rationale:** Must come after Phase 1 (stores anchors the PORO produces) and Phase 2 (effect only observable once entries render). Mirrors the existing `faq_builder` pattern.
**Delivers:** `blog_params` extension; TOC section in `_form.html.erb`; `_toc_row_fields.html.erb` (locked read-only anchor, label text field, hidden checkbox, drag handle); `toc_builder_controller.js`; toggle checkbox.
**Avoids:** relabel must never change the anchor; labels are plain text (auto-escaped, `strip_tags` on write, length cap).

### Phase Ordering Rationale

- Everything depends on the anchor-id contract, so the PORO is Phase 1.
- Public-before-admin: override UI has no observable effect until the public page renders entries; Phase 2 is the first shippable slice.
- Layout and behavior are split: Phase 2 fails as a visual regression (caught by golden-master spec); Phase 3 fails as jank/leaks/a11y defects (caught by manual QA). Bundling them makes the diff unreviewable.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Server-side claims verified by executing against this repo's actual locked gems. No new dependencies. |
| Features | MEDIUM-HIGH | Conventions corroborated across many CMS implementations. Reference UX (views4you.com) unverifiable (403), known only from user description. |
| Architecture | HIGH | Every recommendation traces to a verified codebase fact or local benchmark. |
| Pitfalls | HIGH | Codebase-specific pitfalls reproduced empirically, including the two that reshaped scope (empty content, requirements contradiction — both now resolved). |

**Overall confidence:** HIGH

### Gaps to Address

- **Tiptap StarterKit Heading dropping unknown `id` attributes on round-trip** is MEDIUM confidence (inferred, not empirically tested) — quick manual check during Phase 1; the render-time recommendation holds either way.
- **`rootMargin` reading band** is LOW confidence — tune in-browser during Phase 3.
- **views4you.com reference UX** unverifiable (HTTP 403) — verify visually during Phase 2/3 if precise interaction details matter.
- **Pre-existing sanitizer vendor mismatch** (model uses HTML4 vendor, view helper uses HTML5 per `load_defaults 8.0`) — use `Nokogiri::HTML5.fragment` for injection so ids match the browser DOM; switching the model itself is out of scope for this project.
- **No `spec/system` infrastructure exists** — decide during Phase 3 planning: stand up a smoke test, or commit a written manual QA checklist executed before merge.
- **JSON API asymmetry:** with render-time injection, `api/v1/blogs/show.json`'s `content_html` carries no anchors while the HTML page does — document as expected, not a bug.

## Sources

### Primary (HIGH confidence)
- This repository, executed not inferred — sanitizer allowlist test, `parameterize` edge-case probe, `Nokogiri::HTML` vs `HTML5.fragment` round-trip, parse+inject benchmark, dev-DB heading audit
- `app/models/blog.rb`, `app/views/blogs/show.html.erb`, `app/controllers/blogs_controller.rb`, `app/views/api/v1/blogs/show.json.jbuilder`, `app/javascript/controllers/{tiptap_editor,faq_builder,cookie_consent}_controller.js`, `db/schema.rb`, `Gemfile.lock`, `package.json`
- rubygems.org + npm registry (2026-08-01); MDN (`scroll-target-group`, `IntersectionObserver`, `prefers-reduced-motion`); caniuse; W3C WCAG 2.1 SC 2.3.3; OWASP DOM Clobbering Prevention Cheat Sheet

### Secondary (MEDIUM confidence)
- css-tricks.com, benfrain.com, tj.ie, chriskirknielsen.com — IntersectionObserver TOC patterns
- polypane.app, frontendmasters.com, designcise.com — `position: sticky` failure modes
- hotwired/turbo#1255, Turbo Handbook — smooth-scroll/Turbo interaction
- WordPress ToC plugin comparisons — heading-level limits, dedupe suffixing, threshold defaults
- avohq.io "Dynamic TOC with Rails and Nokogiri" — shape reference only; contains bugs called out independently by two research tracks

### Tertiary (LOW confidence)
- views4you.com reference — 403 to automated fetch, known only from user description
- Reading-progress-bar value claims — contested in UX literature, deferred on those grounds

---
*Research completed: 2026-08-01*
*Ready for roadmap: yes*
