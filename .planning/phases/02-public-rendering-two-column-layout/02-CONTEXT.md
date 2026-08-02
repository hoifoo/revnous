# Phase 2: Public Rendering & Two-Column Layout - Context

**Gathered:** 2026-08-02
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase delivers the server-rendered visual layer for the TOC: a two-column layout on desktop/tablet where the sidebar TOC sits beside the article, permalink affordances on H2/H3 headings, and a typography pass scoped strictly to the TOC-on layout. No client-side JS behavior (scroll-spy, smooth scroll, mobile disclosure) — that's Phase 3. Concretely:

- A CSS-grid two-column layout that activates only when `toc_enabled?` is true AND 3+ TOC entries remain visible after filtering hidden overrides.
- The sidebar renders `Blog::TableOfContents` entries as a sticky, plain-anchor-link nav (`<nav aria-label="Table of contents">`), with no JavaScript required for the "click → jump" behavior (native browser anchor navigation, enhanced for free by the site's existing global smooth-scroll script in `_navigation.html.erb`).
- Every H2/H3 in the article gets a hover-revealed permalink affordance linking to its own anchor (INTX-04).
- Typography/spacing refinements apply only inside the TOC-on two-column container — the TOC-off layout remains pixel-identical (LAYOUT-03, verified by the Phase 1 golden-master spec).
- Mobile widths (below the two-column breakpoint) render no sidebar and no dropdown in this phase — Phase 3 owns the mobile "Contents" disclosure entirely as new markup/behavior.

Explicitly NOT this phase: scroll-spy, smooth-scroll JS, focus management on click, sidebar internal auto-scroll, mobile disclosure interactivity (Phase 3); admin toggle/override UI (Phase 4). Phase 2 does read `toc_overrides` for hide-flags (data already exists from Phase 1), but only Phase 4 ships the UI to write them.

</domain>

<decisions>
## Implementation Decisions

### Two-Column Layout & Mobile Fallback (discussed)
- **D-01:** Sidebar renders on the right side of the article (matches the views4you.com reference pattern).
- **D-02:** The two-column layout activates at the `lg` breakpoint (1024px+) only. Below `lg`, the page is single-column — this errs toward giving the sidebar column enough room rather than cramming it into tablet-portrait widths.
- **D-03:** Below the `lg` breakpoint, Phase 2 renders nothing for the TOC — no sidebar, no fallback list, no dropdown. The container simply doesn't render below the breakpoint. Phase 3 builds the mobile "Contents" disclosure as new markup entirely; Phase 2 doesn't build interim markup for Phase 3 to rework.
- **D-04:** Sidebar uses a fixed-width column in the CSS grid (not a proportional fraction) so the article's reading measure stays stable regardless of viewport width.

### Sidebar Visual Design (discussed)
- **D-05:** The sidebar heading label reads **"Table of Contents"** (user's explicit choice — more formal/explicit than the shorter "Contents" or docs-style "On this page"). Note for Phase 3: the mobile disclosure trigger button's own label is Phase 3's decision and does not need to match this text.
- **D-06:** H3 entries are visually distinguished from H2 entries with left indent **plus** smaller/lighter text (e.g. `text-gray-500 text-sm` vs `text-gray-900` for H2) — communicates hierarchy without needing the H3-collapse-under-H2 behavior deferred to v2 (TOCV2-01).
- **D-07:** Sticky sidebar top offset is `top-8` (32px). The site header (`_navigation.html.erb`) is `position: relative`, not sticky/fixed (`h-16`, no sticky class) — so the sidebar doesn't need to offset for a persistent header height.
- **D-08:** TOC link default/hover style: gray text by default, `text-pink-600` on hover — matches the brand color already used for links/CTAs throughout `show.html.erb` and the site nav.

### toc_overrides Data Shape & Scope (discussed — locks Phase 4's contract)
- **D-09:** Phase 2 only respects the **hide** override behavior — filtering hidden anchors out of the entry list before rendering and before the 3-entry-minimum count. Relabel and reorder are read/rendered starting in Phase 4, alongside the admin UI that produces that data. Phase 2 should not build speculative rendering logic for override fields nothing can write yet.
- **D-10:** `toc_overrides` jsonb shape is a **hash keyed by anchor**: `{"toc-intro": {"hidden": true}, ...}`. Matches the `keywords`-column jsonb precedent noted in Phase 1 D-05, and anchors are already the natural unique key `Blog::TableOfContents` produces.
- **D-11 (Claude's call, not asked — only one sane option):** Hiding an entry only removes it from the rendered TOC sidebar list. It never affects the heading itself in the article body — the `toc-` anchor `id` stays exactly as `Blog::TableOfContents` derives it, so existing deep links to a hidden section keep working.
- **D-12 (Claude's call, not asked — directly follows TOC-04's literal wording):** The 3-entry suppression threshold is inclusive at the boundary: exactly 3 visible entries still renders the sidebar; 2 or fewer suppresses it entirely (TOC-04 says "fewer than 3").

### Typography Pass & Permalink Affordance (discussed)
- **D-13:** Article reading measure in the TOC-on layout stays constrained to Tailwind's `prose-lg` default max-width (~75ch) rather than filling the entire remaining grid column width — prevents overly long lines on ultra-wide viewports now that the container is a two-column grid rather than the current `max-w-none` single column.
- **D-14:** Heading vertical rhythm gets a top-margin increase beyond current prose defaults, purely additive CSS (no structural change), to reinforce section breaks now that a sidebar is tracking them.
- **D-15:** Permalink affordance (INTX-04) is a hover-revealed `#` icon/link, positioned after the heading text, that fades in on hover/focus — clean default reading view, common docs-site pattern (GitHub README style).

### Claude's Discretion
- Exact Tailwind grid classes/structure for the two-column layout (`grid-cols-[1fr_280px]` vs explicit `lg:grid` utilities, etc.) as long as D-01–D-04 hold.
- How `blog_body_with_toc_anchors` (currently discards `Blog::TableOfContents#entries`, only uses `.to_html`) is restructured so the view/controller can access both the anchor-injected HTML *and* the entries list for sidebar rendering — needs a single parse pass per D-03 from Phase 1 (no re-parsing HTML twice).
- Where the "3+ visible entries after hiding" filter logic lives (helper, PORO method, view) — must be computed once and reused for both the suppression check and the rendered entry list.
- Exact permalink icon markup/SVG and hover transition styling.
- Precise Tailwind spacing scale values for D-14's heading margin increase.
- Whether `toc_overrides` needs a DB index — not expected to matter at current scale, but not precluded.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project scope & decisions
- `.planning/PROJECT.md` — full project scope, constraints, Key Decisions table
- `.planning/REQUIREMENTS.md` — this phase covers TOC-04, LAYOUT-01, LAYOUT-03, A11Y-01, INTX-04
- `.planning/ROADMAP.md` — Phase 2 goal and success criteria (verbatim contract for this phase)
- `.planning/STATE.md` — accumulated decisions and open Blockers/Concerns (views4you.com reference returned HTTP 403 to automated fetch — verify visually if precise interaction details matter)
- `.planning/phases/01-toc-domain-core-regression-baseline/01-CONTEXT.md` — Phase 1 decisions this phase builds on directly, especially D-03 (render-time anchor injection point), D-05 (jsonb override column precedent), D-08 (label formatting keeps inline markup)

### Existing code this phase touches or must respect
- `app/models/blog/table_of_contents.rb` — `Blog::TableOfContents` PORO; `derive!` returns `entries` (Struct: `level`, `anchor`, `label_html`, `text`) and mutates `fragment` for `to_html`. Sidebar rendering needs `entries`; current helper only calls `.to_html` and discards them — same `.call` result must supply both.
- `app/helpers/blogs_helper.rb` — `blog_body_with_toc_anchors(blog, sanitized_html)`, the TOC-off short-circuit (`return sanitized_html unless blog.toc_enabled?`) that this phase's suppression logic (TOC-04) extends
- `app/views/blogs/show.html.erb` (lines 74-80) — the `prose prose-lg max-w-none` article container this phase wraps in a two-column grid; existing `spacing == 'relaxed'` conditional class must keep working
- `app/views/shared/_navigation.html.erb` (lines 1, 261-278) — header is `position: relative` (not sticky, `h-16`), and a global `document.querySelectorAll('a[href*="#"]')` smooth-scroll handler already exists site-wide — TOC anchor links get free smooth-scroll enhancement without any new JS in this phase
- `db/schema.rb` — `toc_enabled` (boolean, default false) and `toc_overrides` (jsonb, default `{}`) columns already exist from Phase 1, no migration needed this phase
- `spec/requests/blogs_toc_spec.rb`, `spec/requests/blogs_golden_master_spec.rb` — existing specs this phase's changes must not break (TOC-off rendering must stay byte-identical)
- `app/assets/stylesheets/application.tailwind.css` (line 6, 21) — existing `prose` and `prose-paragraph-relaxed` custom CSS this phase's typography pass extends, scoped to the TOC-on branch only

No external specs/ADRs beyond the project's own `.planning/` docs.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Blog::TableOfContents.call(sanitized_html)` — single parse/mutation pass already exists from Phase 1; exposes `.entries` (ordered, leveled, with `label_html` preserving inline markup) and `.to_html` (anchor-injected). Both come from one `Nokogiri::HTML5` parse — reuse this instance rather than re-deriving.
- Existing brand link color (`pink-600` / `pink-700` hover) used consistently across `show.html.erb` (breadcrumb, share links) and `_navigation.html.erb` — reuse for TOC link styling (D-08).
- `prose prose-lg` Tailwind typography classes already applied to article body — extend rather than replace for the TOC-on measure/rhythm changes (D-13, D-14).

### Established Patterns
- View-level `sanitize` call + helper-based post-processing (`blog_body_with_toc_anchors`) is the established pattern for content transformation — sidebar entries should flow through the same helper/call site, not a separate re-parse.
- Tailwind utility-first styling, no custom CSS beyond a couple of narrow exceptions (`application.tailwind.css` lines 6, 21) — this phase's typography/layout additions should stay utility-class-driven, consistent with the rest of the view.
- Global vanilla-JS behaviors (mega menu, mobile menu toggle, smooth-scroll) live inline in `_navigation.html.erb`'s `<script>` tag rather than as Stimulus controllers — Phase 2 needs no new JS at all, so this pattern isn't extended here (Phase 3 will decide whether new client behavior becomes a Stimulus controller).

### Integration Points
- `app/views/blogs/show.html.erb` lines 74-80 is the single integration point: the container div and the `blog_body_with_toc_anchors` call both need to change to (a) wrap in a two-column grid conditionally and (b) surface entries to a new sidebar partial.
- `Blog#toc_enabled?` (Rails auto-generated boolean predicate, no custom code) and `Blog#toc_overrides` (jsonb hash) are the two data inputs the layout/suppression logic reads.

</code_context>

<specifics>
## Specific Ideas

- Reference UX pattern: https://views4you.com/blog/move-tiktok-audience-to-instagram/ — sticky sidebar TOC, right-aligned, scroll-spy highlight, smooth scroll (behavior confirmed via user description; site blocks automated fetch, so verify visually if exact spacing/sizing details matter during implementation).
- Sidebar heading label is explicitly "Table of Contents", not the shorter "Contents" — user's deliberate choice (D-05).
- Permalink affordance should follow the familiar hover-reveal `#` link pattern (GitHub README style) rather than always-visible icons.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within Phase 2 scope. Relabel/reorder override rendering is not deferred as a new capability, just sequenced into Phase 4 per D-09 (already scoped there in ROADMAP.md/REQUIREMENTS.md). Multi-page posts, gem extraction, and broader nav/discovery UX remain deferred at the project level per PROJECT.md Out of Scope — not raised again here.

</deferred>

---

*Phase: 2-public-rendering-two-column-layout*
*Context gathered: 2026-08-02*
