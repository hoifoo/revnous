# Phase 2: Public Rendering & Two-Column Layout - Research

**Researched:** 2026-08-02
**Domain:** Server-rendered CSS Grid layout, `position: sticky`, Tailwind CSS v4 + `@tailwindcss/typography`, Nokogiri DOM decoration, byte-identical ERB regression safety
**Confidence:** HIGH (all load-bearing claims verified empirically against this repo or against official docs)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Two-Column Layout & Mobile Fallback**
- **D-01:** Sidebar renders on the right side of the article (matches the views4you.com reference pattern).
- **D-02:** The two-column layout activates at the `lg` breakpoint (1024px+) only. Below `lg`, the page is single-column — this errs toward giving the sidebar column enough room rather than cramming it into tablet-portrait widths.
- **D-03:** Below the `lg` breakpoint, Phase 2 renders nothing for the TOC — no sidebar, no fallback list, no dropdown. The container simply doesn't render below the breakpoint. Phase 3 builds the mobile "Contents" disclosure as new markup entirely; Phase 2 doesn't build interim markup for Phase 3 to rework.
- **D-04:** Sidebar uses a fixed-width column in the CSS grid (not a proportional fraction) so the article's reading measure stays stable regardless of viewport width.

**Sidebar Visual Design**
- **D-05:** The sidebar heading label reads **"Table of Contents"** (user's explicit choice — more formal/explicit than the shorter "Contents" or docs-style "On this page"). Note for Phase 3: the mobile disclosure trigger button's own label is Phase 3's decision and does not need to match this text.
- **D-06:** H3 entries are visually distinguished from H2 entries with left indent **plus** smaller/lighter text (e.g. `text-gray-500 text-sm` vs `text-gray-900` for H2) — communicates hierarchy without needing the H3-collapse-under-H2 behavior deferred to v2 (TOCV2-01).
- **D-07:** Sticky sidebar top offset is `top-8` (32px). The site header (`_navigation.html.erb`) is `position: relative`, not sticky/fixed (`h-16`, no sticky class) — so the sidebar doesn't need to offset for a persistent header height.
- **D-08:** TOC link default/hover style: gray text by default, `text-pink-600` on hover — matches the brand color already used for links/CTAs throughout `show.html.erb` and the site nav.

**toc_overrides Data Shape & Scope (locks Phase 4's contract)**
- **D-09:** Phase 2 only respects the **hide** override behavior — filtering hidden anchors out of the entry list before rendering and before the 3-entry-minimum count. Relabel and reorder are read/rendered starting in Phase 4, alongside the admin UI that produces that data. Phase 2 should not build speculative rendering logic for override fields nothing can write yet.
- **D-10:** `toc_overrides` jsonb shape is a **hash keyed by anchor**: `{"toc-intro": {"hidden": true}, ...}`. Matches the `keywords`-column jsonb precedent noted in Phase 1 D-05, and anchors are already the natural unique key `Blog::TableOfContents` produces.
- **D-11:** Hiding an entry only removes it from the rendered TOC sidebar list. It never affects the heading itself in the article body — the `toc-` anchor `id` stays exactly as `Blog::TableOfContents` derives it, so existing deep links to a hidden section keep working.
- **D-12:** The 3-entry suppression threshold is inclusive at the boundary: exactly 3 visible entries still renders the sidebar; 2 or fewer suppresses it entirely (TOC-04 says "fewer than 3").

**Typography Pass & Permalink Affordance**
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

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within Phase 2 scope. Relabel/reorder override rendering is not deferred as a new capability, just sequenced into Phase 4 per D-09 (already scoped there in ROADMAP.md/REQUIREMENTS.md). Multi-page posts, gem extraction, and broader nav/discovery UX remain deferred at the project level per PROJECT.md Out of Scope — not raised again here.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| **TOC-04** | TOC is suppressed entirely (no sidebar, no layout shift, no mobile dropdown) when fewer than 3 entries remain visible after admin hides | Pattern 2 (single-pass value object computes `visible_entries` once, `toc?` returns false below threshold); Pitfall 6 (jsonb boolean casting for the `hidden` flag); Code Example 1 |
| **LAYOUT-01** | TOC renders as a sticky sidebar next to the article body on desktop/tablet widths | Pattern 3 (CSS Grid two-column); Pitfall 1 (`align-self: start` required for sticky grid items — VERIFIED); Pitfall 2 (`minmax(0,1fr)` blowout — VERIFIED); Code Example 3 |
| **LAYOUT-03** | Reading-experience typography/spacing refinements apply only to the new TOC-on two-column layout — the TOC-off layout is pixel-identical to today | Pattern 1 (Erubi `trim: true` emits zero bytes for standalone `<% %>` lines — VERIFIED empirically); Pitfall 3 (golden-master byte fidelity incl. trailing space in the `class` attribute — VERIFIED via `od -c`); Pattern 4 (`prose-h2:`/`prose-h3:` element modifiers — VERIFIED in installed plugin) |
| **A11Y-01** | TOC is wrapped in `<nav aria-label="Table of contents">` with the active entry marked `aria-current` | Pattern 5 (nav landmark, `role="list"`, non-heading visible label); Open Question 3 (`aria-current` belongs to Phase 3's scroll-spy — Phase 2 ships the nav wrapper only, matching ROADMAP criterion 4) |
| **INTX-04** | Heading permalink affordance — hovering/clicking a heading offers a direct link to that section's anchor | Pattern 6 (server-side Nokogiri injection AFTER entry capture — VERIFIED); Pitfall 4 (nested `<a>` breaks the TOC link — VERIFIED empirically); Pitfall 5 (label/text contamination if injected too early — VERIFIED); Code Examples 2, 4, 5 |
</phase_requirements>

## Summary

This phase is **pure server-side rendering plus CSS**. No new packages, no new JavaScript, no schema change. The entire risk surface is (a) not breaking the Phase 1 golden-master byte-fidelity gate, (b) getting `position: sticky` to actually stick inside a CSS Grid, and (c) not corrupting the TOC entry labels or the article HTML while decorating headings with permalinks.

Three findings dominate planning:

1. **The golden-master gate is byte-exact, and Erubi's default trim mode is what makes this phase safe.** `spec/fixtures/golden_master/*.article.html` freezes the `div.prose` element down to a *trailing space inside the `class` attribute* (verified via `od -c`), and `*.page.html` freezes the entire normalized page. But Rails compiles ERB with `trim: true` (`ActionView::Template::Handlers::ERB.erb_trim_mode == "-"`, verified in the installed actionview gem), and I confirmed empirically that a line containing only `<% if ... %>` / `<% end %>` emits **zero bytes** when the branch is skipped. That means the two-column wrapper can be added as conditional standalone ERB lines around the untouched `div.prose` and the TOC-off output stays byte-identical. Any approach that re-indents the existing block, wraps it in a partial, or uses `capture` will break the gate.

2. **Two independent CSS Grid landmines, both verified.** A grid item defaults to `align-items: stretch`, so a `position: sticky` sidebar that *is* a grid item is already as tall as its row and cannot travel — `lg:self-start` is mandatory. And `1fr` expands to `minmax(auto, 1fr)`, whose `auto` minimum is min-content; blog bodies here contain `<pre>` and `<table>` (both are golden-master fixtures), so the article column must be `minmax(0,1fr)` or it will blow out the grid and cause horizontal page overflow.

3. **The permalink affordance has two ordering/nesting traps I reproduced in this repo.** Appending the `<a class="toc-permalink">#</a>` to a heading *before* `Blog::TableOfContents` captures `label_html`/`text` leaks a literal `#` into every sidebar entry (reproduced: `"Getting Started & Beyond#"`). And separately, `LABEL_TAGS` already permits `a`, so a heading containing a link produces a nested `<a>` inside the sidebar's own `<a>` — which the HTML parser splits, silently breaking the TOC link (reproduced: `<a href="#a">Getting </a><a href="/x">Started</a> Beyond`). Both need explicit handling.

One item CONTEXT.md states that research contradicts: the claim that TOC anchor links "get free smooth-scroll enhancement" from the global handler in `_navigation.html.erb` holds **only on full page loads**. That handler is registered inside `DOMContentLoaded`, which never fires on Turbo Drive visits, so navigating from `/blog` to `/blog/:slug` leaves it unbound. This does not block Phase 2 (native anchor jump still works, which is exactly what the phase promises) but it invalidates an assumption Phase 3 would otherwise inherit.

**Primary recommendation:** Restructure `blog_body_with_toc_anchors` into a single-call value object (`html` + `toc_entries` + `toc?`) computed once per render from one Nokogiri parse; wrap the *existing, unmoved* `div.prose` in conditional standalone-ERB grid lines; render the sidebar as `hidden lg:block lg:col-start-2 lg:row-start-1 lg:self-start lg:sticky lg:top-8`; inject permalinks in a second traversal of the already-derived fragment (never inside `derive!`'s entry loop).

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Sanitize `body` HTML | Frontend Server (Rails view) | — | Already the established trust boundary (`show.html.erb` line 78); Phase 1 explicitly kept anchor injection downstream of it |
| Derive TOC entries + inject anchor ids | Frontend Server (`Blog::TableOfContents` PORO) | — | Render-time transform of view-sanitized HTML; never touches persisted `body` (Phase 1 D-03) |
| Filter hidden entries + apply 3-entry threshold | Frontend Server (helper / value object) | — | Presentation policy, not persistence policy; must be computed once and shared by the suppression check and the sidebar list |
| Inject heading permalink `<a>` | Frontend Server (Nokogiri, same fragment) | — | Reuses the single parse; doing it client-side would cause FOUC and fail no-JS/crawler readers |
| Two-column grid + sticky positioning | CDN / Static (CSS, compiled by Tailwind CLI) | — | Pure CSS; no layout JS in this phase by design (D-03, phase boundary) |
| Anchor click → jump to section | Browser / Client (native anchor navigation) | — | Zero JS required; ROADMAP criterion 1 explicitly demands this |
| Reading measure / heading rhythm | CDN / Static (CSS via `prose-*` modifiers) | — | Utility-class driven per project convention; scoped to the TOC-on branch only |
| Scroll-spy, smooth scroll, focus management, mobile disclosure | **Out of scope — Phase 3** | — | Phase boundary in CONTEXT.md `<domain>` |
| Writing `toc_overrides` | **Out of scope — Phase 4** | — | D-09; Phase 2 reads only |

## Project Constraints (from CLAUDE.md)

Actionable directives extracted from `/Users/irfan/projects/revnous/web/CLAUDE.md` that the planner must comply with:

| Directive | Applies to this phase |
|-----------|----------------------|
| **Rails/Stimulus/esbuild only — no React/Vue** | Trivially satisfied: Phase 2 adds no JS at all |
| **TOC must be strictly opt-in (default off); existing posts render identically** | The whole point of Pattern 1 + Pitfall 3 |
| **No new editor storage format; TOC reads existing sanitized `body`** | No schema change; `Blog::TableOfContents.call` already consumes view-sanitized HTML |
| **Scope discipline: gem extraction and multi-page posts are parked** | Not touched |
| **Rubocop `rails-omakase`; 2-space indent** | Applies to new Ruby (helper / value object / PORO changes). ERB is not linted (no `erb_lint` in the Gemfile) |
| **Brakeman for security scanning** | Permalink injection is post-sanitize HTML construction — see Security Domain; keep the existing `# SECURITY:` comment convention in `blogs_helper.rb` |
| **Views: ERB + Tailwind utility-first; custom CSS is a narrow exception** | `application.tailwind.css` already has exactly two exceptions (`.tiptap-editor …`, `.prose-paragraph-relaxed p`) — the permalink hover-reveal is a legitimate third (needs a parent-hover selector) |
| **Private methods grouped at bottom after `private`** | Applies to helper/PORO edits |
| **GSD workflow enforcement — no direct edits outside a GSD command** | Planner/executor concern |
| **Guard clauses / early return pattern** | The existing `return sanitized_html unless blog.toc_enabled?` short-circuit is the model to extend |

## Standard Stack

**No new packages are required or recommended for this phase.** Everything needed is already installed and in use.

### Core (already present)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Rails / ActionView | 8.0.5 (installed; Gemfile.lock pins `~> 8.0.3`) | ERB rendering, `sanitize`, helper layer | Already the app's rendering tier `[VERIFIED: local gem path]` |
| Erubi | 1.13.1 | ERB compiler; `trim: true` is what makes byte-identical conditional wrappers possible | Rails default, non-negotiable `[VERIFIED: Gemfile.lock + empirical test]` |
| Nokogiri (HTML5) | via Rails / Phase 1 PORO | Single-parse DOM decoration of headings | Phase 1 D-03 already mandates HTML5 vendor for byte fidelity `[VERIFIED: app/models/blog/table_of_contents.rb]` |
| Tailwind CSS | 4.1.14 | Grid, sticky, responsive breakpoints, spacing | Project standard `[VERIFIED: package.json]` |
| `@tailwindcss/typography` | 0.5.19 | `prose` / `prose-lg` and `prose-h2:` element modifiers | Already loaded via `@plugin` `[VERIFIED: node_modules + application.tailwind.css:3]` |

### Supporting (already present)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| RSpec + rspec-rails | 7.1.1 | Request specs asserting rendered markup | All Phase 2 automated verification |
| Capybara 3.40 + selenium-webdriver 4.36 | installed, **unconfigured** | Would be needed for sticky/hover behavior specs | Only if the planner elects to stand up `spec/system` — see Open Question 4 |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| CSS Grid two-column | Flexbox (`lg:flex` + `lg:w-64 shrink-0`) | Works and needs `self-start` for sticky just the same; Grid's explicit `col-start`/`row-start` placement is what lets the sidebar precede the article in DOM order while rendering right (see Pattern 5) — flexbox would need `order`, which is a documented WCAG 1.3.2 smell |
| Server-injected permalink `<a>` | CSS `h2[id]:hover::after { content: "#" }` | Not clickable, so it fails INTX-04's "offers a direct link" |
| Server-injected permalink `<a>` | Stimulus controller that appends links client-side | Violates the phase's "no JS" boundary, causes FOUC, and invisible to crawlers |
| Flat `<ol>` with indent (D-06) | Nested `<ol>` (h3s inside the preceding h2's `<li>`) | Nested is more semantic for screen readers at identical visual cost, but requires a grouping pass and an edge case for an h3 preceding any h2. D-06 locks the *visual* treatment, not the markup — see Open Question 2 |
| Widening the TOC-on container | Keeping `max-w-4xl` for both branches | See Open Question 1 — this is the single most consequential unresolved design decision |

**Installation:** None. `yarn build:css` must be re-run after CSS/class changes (see Environment Availability).

## Package Legitimacy Audit

**Not applicable — this phase installs zero external packages.** No `npm install`, no `bundle add`, no new gems. Every library used is already present in `package.json` / `Gemfile.lock` and was verified against the local `node_modules` / installed gem tree rather than a registry.

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```
  GET /blog/:slug  (HTML format)
        │
        ▼
  BlogsController#show ──► @blog { body, toc_enabled, toc_overrides, spacing }
        │
        ▼
  app/views/blogs/show.html.erb
        │
        ├─► blog_article(@blog)          ◄── ONE helper call, ONE Nokogiri parse
        │        │
        │        ├─ sanitize(body, ALLOWED_TAGS, ALLOWED_ATTRIBUTES)   ══ TRUST BOUNDARY ══
        │        │
        │        ├─ toc_enabled? == false ──────────────────────► ArticleContent(html: sanitized, entries: [])
        │        │
        │        ├─ Blog::TableOfContents.call(sanitized)
        │        │       ├─ fragment: h2/h3 get id="toc-…"
        │        │       └─ entries[]: {level, anchor, label_html, text}   ← captured HERE, before decoration
        │        │
        │        ├─ visible = entries.reject { overrides[anchor]["hidden"] }      (D-09/D-10)
        │        │
        │        ├─ visible.size < 3 ────────────────────────────► ArticleContent(html: to_html, entries: [])
        │        │                                                   (ids stay — D-11 deep links survive)
        │        │
        │        ├─ inject <a class="toc-permalink"> into each h2/h3   ← AFTER entries captured (Pitfall 5)
        │        │
        │        └──────────────────────────────────────────────► ArticleContent(html: to_html, entries: visible)
        │
        ▼
  branch on article.toc?
        │
        ├── false ──► EXACT current markup, byte-for-byte
        │             <div class="max-w-4xl …"> … <div class="prose prose-lg max-w-none mb-16 "> … </div> … </div>
        │
        └── true  ──► <div class="max-w-5xl …">                            (wider container — Open Question 1)
                        <div class="lg:grid lg:grid-cols-[minmax(0,1fr)_16rem] lg:gap-12">
                          ├─ <nav aria-label="Table of contents">          col-start-2 row-start-1
                          │     hidden lg:block · lg:self-start · lg:sticky lg:top-8
                          │     <ol role="list"> → <a href="#toc-…">       ← plain anchors, zero JS
                          │
                          └─ <div class="prose prose-lg …">                col-start-1 row-start-1
                                h2 id="toc-…" … <a class="toc-permalink" href="#toc-…">#</a>
                        </div>
                      </div>
        │
        ▼
  Browser: native anchor navigation (no JS). On a hard page load only, the
  legacy DOMContentLoaded handler in _navigation.html.erb additionally
  preventDefaults and calls scrollIntoView({behavior:'smooth'}).
  On Turbo Drive visits that handler is never bound.  ← See Pitfall 7
```

### Recommended Project Structure

```
app/
├── helpers/
│   └── blogs_helper.rb             # blog_article(blog) → value object (replaces blog_body_with_toc_anchors)
├── models/blog/
│   └── table_of_contents.rb        # unchanged public contract; optional #decorate_permalinks!
├── views/blogs/
│   ├── show.html.erb               # conditional grid wrapper + conditional container width
│   └── _toc_sidebar.html.erb       # NEW: nav + ol + entries
└── assets/stylesheets/
    └── application.tailwind.css    # NEW: ~5 lines for .toc-permalink hover reveal

spec/
├── requests/
│   ├── blogs_toc_spec.rb           # extend: sidebar present/absent, threshold, permalinks
│   └── blogs_golden_master_spec.rb # MUST stay green WITHOUT regenerating fixtures
└── helpers/
    └── blogs_helper_spec.rb        # NEW (optional): threshold + override filtering in isolation
```

### Pattern 1: Byte-Safe Conditional Wrapper (the LAYOUT-03 enabler)

**What:** Add markup around the existing `div.prose` using ERB lines that contain *only* an ERB tag, so the skipped branch emits nothing at all.

**Why it works:** Rails compiles templates with Erubi `trim: true` (`erb_trim_mode` defaults to `"-"`, and the handler passes `trim: (self.class.erb_trim_mode == "-")`). With trim on, a line whose entire content is `<% ... %>` contributes no output — not even a newline.

**VERIFIED empirically in this repo:**

```ruby
# ruby -e with erubi 1.13.1
src = <<~ERB
  <div class="a">
  <% if false %>
    <div class="grid">
  <% end %>
      <div class="prose">
        BODY
      </div>
  <% if false %>
    SIDEBAR
    </div>
  <% end %>
  </div>
ERB
Erubi::Engine.new(src, trim: true)  # →
# <div class="a">
#     <div class="prose">
#       BODY
#     </div>
# </div>
```

With `trim: false` the same source emits two stray blank lines. So this pattern is *entirely dependent* on the Rails default — do not set `config.action_view.erb_trim_mode` and do not hand-compile.

**Critical corollary:** the `<div class="prose …">` line, its children, and its closing tag must keep their **current indentation and position**. Do not indent them into the `if` branch. Do not extract them into a partial. Do not use `capture`.

### Pattern 2: Single-Parse Value Object

**What:** Replace `blog_body_with_toc_anchors(blog, sanitized_html)` with one helper returning a small value object exposing `#html`, `#toc_entries`, and `#toc?`.

**When to use:** Always — the view needs the anchor-injected HTML *and* the entry list *and* the suppression verdict, and Phase 1 D-03 forbids a second parse.

**Why not the alternatives:**
- Computing `toc?` in the view by calling the helper twice → two parses, violates D-03.
- Putting the filter in `Blog::TableOfContents` → couples the PORO to `Blog#toc_overrides` and would tempt filtering the *fragment* too, violating D-11.
- Instance variable set in the controller → sanitization currently lives in the view; moving it is a larger diff with no benefit.

Keep `Blog::TableOfContents#entries` as the **complete** list. Filtering is a presentation policy that belongs one layer up.

### Pattern 3: Sticky Sidebar in CSS Grid

**What:**
```
container : lg:grid lg:grid-cols-[minmax(0,1fr)_16rem] lg:gap-12
article   : lg:col-start-1 lg:row-start-1        (+ prose classes)
sidebar   : hidden lg:block lg:col-start-2 lg:row-start-1 lg:self-start lg:sticky lg:top-8
```

Three non-obvious requirements, each verified:

1. **`lg:self-start` is mandatory.** Grid items default to `align-self: stretch`, so the sidebar is already as tall as the row and `top: 2rem` gives it nowhere to travel. `[VERIFIED: defensivecss.dev, ishadeed.com, css-tricks.com — three independent sources agree]`
2. **`minmax(0,1fr)`, never bare `1fr`.** `1fr` == `minmax(auto, 1fr)`; the `auto` floor is min-content, and this app's bodies contain `<pre>` and `<table>` (both are golden-master fixtures) which can exceed the intended track. `[VERIFIED: MDN minmax() + makandra + gridbugs#55]`
3. **No clipping ancestor.** Sticky is constrained by the nearest ancestor with `overflow` of `hidden`/`scroll`/`auto`/`overlay`. `[CITED: developer.mozilla.org/en-US/docs/Web/CSS/position]` I grepped `app/views/layouts/` and `_navigation.html.erb` and found **zero** `overflow-hidden`/`overflow-x-hidden` in the sticky element's ancestor chain (`html > body.flex.flex-col.min-h-screen > main.flex-1 > div.bg-white.py-16 > div.max-w-*`). `[VERIFIED: grep]` If anyone later adds `overflow-x-hidden` to `body` to paper over a horizontal-scroll bug, the sidebar silently stops sticking.

`display: none` below `lg` (i.e. `hidden lg:block`) is the only server-renderable way to satisfy D-03 — there is no viewport information at render time. This still satisfies "renders no sidebar, no dropdown, no layout shift" because a `display: none` element is removed from both layout and the accessibility tree.

### Pattern 4: Typography Scoped to the TOC-On Branch

Use `@tailwindcss/typography` **element modifiers** rather than custom CSS. `[VERIFIED: node_modules/@tailwindcss/typography/README.md:149-172]` — `prose-headings:`, `prose-h2:`, `prose-h3:`, `prose-a:`, `prose-img:` are all available in 0.5.19.

Measured `prose-lg` baselines from the installed plugin `[VERIFIED: node_modules/@tailwindcss/typography/src/styles.js]`:

| Property | `prose-lg` value | Notes |
|----------|-----------------|-------|
| base `font-size` | `18px` | `rem(18)` |
| base `line-height` | `1.7778` | `32/18` |
| `h2` font-size / margin-top / margin-bottom | `30px` / `56px` / `32px` | `em(30,18)`, `em(56,30)`, `em(32,30)` |
| `h3` font-size / margin-top / margin-bottom | `24px` / `40px` / `16px` | `em(24,18)`, `em(40,24)`, `em(16,24)` |
| `max-width` | **`65ch`** | set once in the DEFAULT config (`styles.js:1414`); **`prose-lg` does NOT override it** |

Note: CONTEXT.md D-13 says "~75ch". The actual plugin value is **65ch**. `[VERIFIED: styles.js:1414]` At 18px in the default `ui-sans-serif` stack, 65ch lands around 610–645px depending on platform font `[ASSUMED — `ch` is font-metric dependent]`.

So D-13 is implemented by **dropping `max-w-none`** in the TOC-on branch (letting the plugin's own 65ch apply), not by adding a new max-width. D-14 is `prose-h2:mt-20 prose-h3:mt-12` (or similar) appended in the same branch-conditional class slot.

### Pattern 5: Accessible TOC Nav

```
sidebar wrapper (grid item, sticky)
└── <nav aria-label="Table of contents">          ← A11Y-01, exact string from the requirement
    ├── <p class="…">Table of Contents</p>        ← D-05 visible label, NOT a heading (see below)
    └── <ol role="list" class="list-none …">
        └── <li><a href="#toc-…" class="…">label</a></li>
```

- **Use `<p>`/`<div>` for the visible "Table of Contents" label, not `<h2>`.** The article's own H2s are what the TOC lists; adding a sibling H2 named "Table of Contents" pollutes the heading outline that the TOC itself is describing. `[ASSUMED — judgment call, not a spec requirement]`
- **`role="list"` on the `<ol>`.** Tailwind's `list-none` sets `list-style-type: none`, which makes Safari/VoiceOver drop list semantics; `role="list"` restores them. `[ASSUMED — widely documented Safari behavior, not verified in this session]`
- **Do not put "navigation" in the `aria-label`** — screen readers already announce the role. "Table of contents" is correct. `[CITED: MDN ARIA navigation role guidance, via search]`
- **Two `<nav>` landmarks will now exist.** The site header nav at `_navigation.html.erb:12` has **no** `aria-label` `[VERIFIED: grep]`. Guidance says name each when 2+ exist — but **do not fix the site nav in this phase**: `_navigation.html.erb` renders on every page and any edit invalidates all five `*.page.html` golden masters (Pitfall 3).
- **DOM order:** placing the sidebar *before* the article in DOM (and using `lg:col-start-2` to render it visually right) puts the TOC ahead of the article for screen-reader and keyboard users, which is the meaningful reading sequence. `[CITED: WCAG 1.3.2 guidance via search — MEDIUM confidence that this is strictly better than article-first]` This is compatible with Pattern 1 either way: the sidebar render line sits inside an `<% if %>` block and emits nothing when TOC is off, regardless of which side of the prose div it is on.

### Pattern 6: Server-Side Permalink Injection

Traverse the **already-derived** fragment a second time and append a permalink anchor to every `h2[id]`/`h3[id]`. Verified round-trip in this repo:

```ruby
f = Nokogiri::HTML5.fragment('<h2>Getting <a href="/x">Started</a> &amp; Beyond</h2>')
h = f.at_css("h2"); h["id"] = "toc-getting-started-beyond"
h.add_child(%q{<a class="toc-permalink" href="#toc-…" aria-label="Permalink"><span aria-hidden="true">#</span></a>})
f.to_html
# → <h2 id="toc-…">Getting <a href="/x">Started</a> &amp; Beyond<a class="toc-permalink" …><span aria-hidden="true">#</span></a></h2>
```
`&amp;` survives (no entity mangling), `add_child` accepts an HTML string, and the heading's opening tag is untouched — so `blogs_toc_spec.rb`'s `include('<h2 id="toc-intro">')` assertions still pass. `[VERIFIED: bundle exec ruby, this repo]`

**Where to put it:** a separate method (`decorate_permalinks!` on the PORO, or a private helper method). Do **not** inline it into `derive!`'s `each_with_index` block — see Pitfall 5.

### Anti-Patterns to Avoid

- **Regenerating the golden masters to make the build green.** `UPDATE_GOLDEN=1` exists for deliberate, reviewed changes. ROADMAP criterion 2 explicitly requires the Phase 1 spec to *still pass*. If it goes red, the TOC-off branch changed and that is the bug.
- **Widening the shared container.** ROADMAP criterion 3 names this exact failure mode: "separate container branches, not a widened shared container."
- **Filtering hidden entries out of the fragment.** D-11: the `id` must stay on the heading so existing deep links keep resolving. Filter only the entry list.
- **Adding `overflow-hidden` anywhere in the ancestor chain** — silently kills sticky.
- **Building the sidebar entry list from a second `Blog::TableOfContents.call`.** Two parses; Phase 1 D-03 forbids it.
- **Interpolating Tailwind class names** (`"lg:col-start-#{n}"`). Tailwind v4 scans source files as plain text and cannot resolve concatenation. `[CITED: tailwindcss.com/docs/detecting-classes-in-source-files]` Write full class names in ternaries.
- **`aria-hidden="true"` on a focusable permalink link.** D-15 says "hover/focus", which implies focusable; `aria-hidden` on a focusable element is an ARIA violation. Pick one of the two coherent designs in Open Question 5.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Constrain reading measure | A custom `max-w-[65ch]` / `max-w-prose` utility | Drop `max-w-none`; the plugin's own `max-width: 65ch` applies | Already there, and it tracks the plugin's own scale `[VERIFIED: styles.js:1414]` |
| Heading rhythm override | Custom CSS block targeting `.prose h2` | `prose-h2:mt-20` element modifier | Plugin emits `:where()` at zero specificity precisely so modifiers win cleanly `[VERIFIED: README.md:149]` |
| Slug/anchor generation | Any new slugifier | `Blog::TableOfContents` (Phase 1) | Already handles dedup, 80-char truncation, trailing-hyphen strip, and the empty-slug positional fallback |
| HTML sanitization of entry labels | A regex/`gsub` tag stripper | `sanitize(entry.label_html, tags: %w[strong em code])` | Rails' Rails::HTML5::SafeListSanitizer; regex HTML stripping is a classic XSS bug source |
| Sticky positioning | Scroll listener + `position: fixed` + manual offset math | `position: sticky` + `align-self: start` | Native, jank-free, and this phase forbids JS anyway |
| Boolean coercion of the jsonb `hidden` flag | `value == "true" \|\| value == true \|\| value == 1` | `ActiveModel::Type::Boolean.new.cast(value)` | Handles `"1"`, `"0"`, `"true"`, `"false"`, `""`, `nil` — and `"0"`/`"false"` are exactly what a Rails checkbox will hand Phase 4 |
| Escaping the permalink `aria-label` | Manual `.gsub('"', '&quot;')` | `ERB::Util.html_escape` / `CGI.escapeHTML` | Heading text is author-controlled |

**Key insight:** Every hand-rolled candidate here already exists one layer down — Rails' sanitizer, the typography plugin's scale, and Phase 1's PORO. The failure mode in this phase is not "missing capability," it is "re-implementing a capability slightly differently and breaking byte fidelity."

## Common Pitfalls

### Pitfall 1: Sticky sidebar silently doesn't stick (grid stretch)
**What goes wrong:** Sidebar renders correctly, scrolls away with the article, never sticks.
**Why it happens:** Grid/flex items default to `align-items: stretch`. The sidebar box is already the full height of the grid row, so it reaches its `top` inset and immediately "unsticks" because its own containing block is scrolling away.
**How to avoid:** `lg:self-start` on the sticky grid item (or `lg:items-start` on the container). Equivalent alternative: keep the item stretched and make a *child* div the sticky one.
**Warning signs:** The element has `position: sticky` in DevTools, `top` is set, and nothing happens. Check computed `align-self`.
**Confidence:** HIGH `[VERIFIED: three independent sources]`

### Pitfall 2: Grid column blowout from `<pre>` / `<table>` / long URLs
**What goes wrong:** On a post with a wide code block or table, the article column expands past its track, the sidebar gets squeezed or pushed off, and the whole page gets a horizontal scrollbar.
**Why it happens:** `1fr` is `minmax(auto, 1fr)`; `auto` floors at min-content, and `<pre>` has an enormous min-content width.
**How to avoid:** `grid-cols-[minmax(0,1fr)_16rem]`. Optionally also `min-w-0` on the article item.
**Warning signs:** Horizontal page scroll appearing only on posts with code blocks.
**Test coverage:** `code_post` and `tables_post` golden fixtures already contain exactly this content — reuse those bodies in a TOC-on request spec.
**Confidence:** HIGH `[VERIFIED: MDN minmax() + 2 corroborating sources]`

### Pitfall 3: Golden-master byte fidelity (the phase's #1 risk)
**What goes wrong:** `blogs_golden_master_spec.rb` goes red for all five fixtures on a change that "looks visually identical."
**Why it happens:** Layer A is `Nokogiri::HTML5(html).at_css("div.prose").to_html` with **zero normalization**. Layer B is the **entire page** with only three regexes applied (asset digest, ISO-8601 timestamps, host). Every byte of indentation, every attribute-value space, and every wrapper element counts.

The exact frozen bytes, dumped with `od -c` from `spec/fixtures/golden_master/minimal_post.article.html`:
```
<div class="prose prose-lg max-w-none mb-16 ">\n      <p>Just a sentence.</p>\n    </div>
                                          ^^^ trailing space, from the empty `spacing` conditional
```
So: `class` attribute has a **trailing space**, inner content starts with `\n` + 6 spaces, and closes with `\n` + 4 spaces.

**How to avoid:**
- Apply Pattern 1 (standalone `<% %>` lines only).
- Build the branch-conditional class as an *inserted segment*, preserving the surrounding literal text and the trailing `<%= '…' if @blog.spacing == 'relaxed' %>` exactly:
  `class="prose prose-lg <%= article.toc? ? '…' : 'max-w-none' %> mb-16 <%= 'prose-paragraph-relaxed' if @blog.spacing == 'relaxed' %>"`
  → TOC-off renders `class="prose prose-lg max-w-none mb-16 "`, byte-identical.
- Same technique for the container width on line 28: `class="<%= … ? 'max-w-5xl' : 'max-w-4xl' %> mx-auto px-4 sm:px-6 lg:px-8"`.
- **Never touch `_navigation.html.erb`, `_footer.html.erb`, `layouts/application.html.erb`, `_faq_section`, `_author_card`, or `_notice_banner`** — all are in every `*.page.html` baseline.
- Run `bundle exec rspec spec/requests/blogs_golden_master_spec.rb` after *every* view edit, not just at the end.

**Warning signs:** Layer A green but Layer B red → you changed something *outside* `div.prose`, most likely a wrapper or a shared partial.
**Confidence:** HIGH `[VERIFIED: od -c on the fixture, source read of spec/support/golden_master.rb]`

### Pitfall 4: Nested `<a>` silently breaks the TOC link
**What goes wrong:** For a heading that contains a link (e.g. `<h2>Getting <a href="/x">Started</a> Beyond</h2>`), only part of the sidebar entry is clickable and the rest becomes bare text pointing nowhere.
**Why it happens:** `Blog::TableOfContents::LABEL_TAGS` includes `a` `[VERIFIED: table_of_contents.rb:15]`, so `label_html` can contain an anchor. Rendering that inside the sidebar's own `<a href="#toc-…">` produces nested anchors, which the HTML parser resolves by closing the outer one early.

Reproduced in this repo:
```
input : <a href="#a">Getting <a href="/x">Started</a> Beyond</a>
parsed: <a href="#a">Getting </a><a href="/x">Started</a> Beyond
```
**How to avoid:** In `_toc_sidebar.html.erb`, render `sanitize(entry.label_html, tags: %w[strong em code], attributes: [])` — Rails' sanitizer drops the disallowed `<a>` tag while keeping its text. Do **not** change `LABEL_TAGS` (that is Phase 1's contract, D-08, and `label_html` may have other consumers in Phase 4).
**Warning signs:** A heading with an inline link; the sidebar entry looks fine but the second half isn't a link.
**Confidence:** HIGH `[VERIFIED: bundle exec ruby, this repo]`

### Pitfall 5: Permalink `#` leaks into TOC entry labels
**What goes wrong:** Every sidebar entry reads "Introduction#" and `entry.text` is polluted, which would also corrupt anything Phase 4 builds on `text`.
**Why it happens:** `derive!` computes `label_html: sanitized_label(node)` from `node.inner_html` and `text: node.text.strip` **inside** the heading loop. If permalink injection happens in that same loop before the `Entry` is constructed — or in any pass that runs before entries are captured — the `#` is part of the heading's inner HTML and text.

Reproduced: after appending the permalink, `h.text.strip` → `"Getting Started & Beyond#"`.
**How to avoid:** Inject permalinks in a **separate traversal after `derive!` has returned**. If the planner instead adds it inside `derive!`, the `entries << Entry.new(...)` line must come strictly before the `add_child` call, and a spec must lock that ordering.
**Warning signs:** `spec/models/blog/table_of_contents_spec.rb:99` (`expect(entry.text).to eq("Getting Started")`) goes red — good, Phase 1 already guards this.
**Confidence:** HIGH `[VERIFIED: bundle exec ruby, this repo]`

### Pitfall 6: jsonb `hidden` flag truthiness
**What goes wrong:** Phase 4's admin checkbox writes `"0"` for unchecked, `blog.toc_overrides["toc-x"]["hidden"]` returns the **string** `"0"`, and `if hidden` is truthy in Ruby — so unchecking "hide" hides the entry.
**Why it happens:** Postgres jsonb round-trips whatever Rails wrote; Rails form checkboxes submit `"1"`/`"0"` strings, and every non-`nil`/non-`false` value is truthy in Ruby.
**How to avoid:** `ActiveModel::Type::Boolean.new.cast(overrides.dig(entry.anchor, "hidden"))`. Establish this in Phase 2 so Phase 4 inherits a forgiving contract. Also guard `(blog.toc_overrides || {})` even though the column is `null: false, default: {}` `[VERIFIED: db/schema.rb:142]`.
**Warning signs:** Won't surface until Phase 4 — which is exactly why it must be handled now.
**Confidence:** HIGH (Ruby truthiness + Rails checkbox behavior are both well established) `[ASSUMED for the specific Phase 4 form shape]`

### Pitfall 7: The "free smooth scroll" assumption does not survive Turbo
**What goes wrong:** CONTEXT.md and the canonical-refs section state that TOC anchor links "get free smooth-scroll enhancement" from the global handler in `_navigation.html.erb`. That is only true on a full page load.
**Why it happens:** The handler is registered inside `document.addEventListener('DOMContentLoaded', …)` `[VERIFIED: _navigation.html.erb:201]`. `@hotwired/turbo-rails` is imported and Turbo Drive is not disabled anywhere (`grep` for `data-turbo="false"` → no matches) `[VERIFIED]`. Turbo Drive replaces `<body>` and fires `turbo:load`, never `DOMContentLoaded` — so on any in-app navigation to a blog post, the entire nav script (mega menu, mobile menu, *and* smooth scroll) never binds. This is a **pre-existing site-wide bug**, not something this phase introduces.

Secondary consequence, on the pages where it *does* bind: the handler calls `e.preventDefault()`, so the URL hash is never updated, `:target` never activates, and focus never moves. That is Phase 3's problem (INTX-01, A11Y-02), but Phase 3 must not assume the existing handler is a working foundation.

**How to avoid (Phase 2):** Nothing to do — plain anchor navigation works with or without the handler, which is exactly ROADMAP criterion 1. Just do not *depend* on smooth scroll being present, and do not write a Phase 2 verification step that asserts smooth-scrolling.
**Confidence:** HIGH `[VERIFIED: source read + grep]`

### Pitfall 8: Tall TOC gets its bottom permanently cut off
**What goes wrong:** On a post with 15+ headings, the sticky sidebar is taller than the viewport; once stuck, the entries below the fold are unreachable.
**Why it happens:** `position: sticky` + no `max-height`.
**How to avoid:** `lg:max-h-[calc(100vh-4rem)] lg:overflow-y-auto` on the sticky element. Note: `overflow` on the *sticky element itself* is harmless — only clipping **ancestors** break stickiness.
**Scope note:** This overlaps INTX-03 (Phase 3), but INTX-03's substance is "keeps the *active entry* in view," which needs scroll-spy. The `max-height` + `overflow-y-auto` half is pure CSS and arguably belongs to this phase's layout scope. See Open Question 6.
**Confidence:** HIGH (mechanism); MEDIUM (scope assignment)

## Code Examples

> These are illustrative shapes, not prescriptive final code. They encode the verified constraints; the planner owns naming and decomposition.

### Example 1: Single-parse value object + helper

```ruby
# app/helpers/blogs_helper.rb
module BlogsHelper
  MIN_TOC_ENTRIES = 3 # TOC-04, inclusive at the boundary (D-12)

  ArticleContent = Struct.new(:html, :toc_entries, keyword_init: true) do
    def toc? = toc_entries.any?
  end

  # SECURITY: `body` is sanitized here with Blog::ALLOWED_TAGS/ALLOWED_ATTRIBUTES
  # before any mutation. Downstream mutations add only (a) `id` attributes whose
  # values are `parameterize` output constrained to [a-z0-9-] and always
  # `toc-` prefixed, and (b) an app-authored permalink <a> whose href is that
  # same anchor and whose aria-label is HTML-escaped heading text. No author
  # markup is reintroduced and no allowlist is widened.
  def blog_article(blog)
    sanitized = sanitize(blog.body, tags: Blog::ALLOWED_TAGS,
                                    attributes: Blog::ALLOWED_ATTRIBUTES)
    return ArticleContent.new(html: sanitized, toc_entries: []) unless blog.toc_enabled?

    toc     = Blog::TableOfContents.call(sanitized) # the ONE parse (Phase 1 D-03)
    visible = visible_toc_entries(toc.entries, blog.toc_overrides)

    # D-11: ids stay on the headings even when suppressed, so deep links survive.
    return ArticleContent.new(html: toc.to_html.html_safe, toc_entries: []) if visible.size < MIN_TOC_ENTRIES

    # Pitfall 5: strictly AFTER toc.entries has been captured.
    decorate_permalinks!(toc.fragment)

    ArticleContent.new(html: toc.to_html.html_safe, toc_entries: visible)
  end

  private

  # D-09/D-10: hide-only, keyed by anchor. Pitfall 6: cast, never truthiness-test.
  def visible_toc_entries(entries, overrides)
    overrides = overrides.presence || {}
    caster    = ActiveModel::Type::Boolean.new
    entries.reject { |e| caster.cast(overrides.dig(e.anchor, "hidden")) }
  end
end
```

### Example 2: Permalink decoration (INTX-04)

```ruby
# app/helpers/blogs_helper.rb (private)
def decorate_permalinks!(fragment)
  fragment.css("h2[id], h3[id]").each do |node|
    next unless node["id"].to_s.start_with?(Blog::TableOfContents::ANCHOR_PREFIX)

    label = ERB::Util.html_escape("Permalink to #{node.text.strip}")
    node.add_child(
      %(<a class="toc-permalink" href="##{node['id']}" aria-label="#{label}">) \
      %(<span aria-hidden="true">#</span></a>)
    )
  end
end
```
Verified: `add_child` with an HTML string parses in context, preserves surrounding entities (`&amp;` stays `&amp;`), and leaves the heading's opening tag untouched so `blogs_toc_spec.rb`'s `include('<h2 id="toc-intro">')` assertions keep passing.

### Example 3: Byte-safe ERB in `show.html.erb`

```erb
<%# line 28 — container width branches; TOC-off renders the literal string "max-w-4xl" %>
  <div class="<%= article.toc? ? 'max-w-5xl' : 'max-w-4xl' %> mx-auto px-4 sm:px-6 lg:px-8">
...
    <!-- Content -->
<% if article.toc? %>
    <div class="lg:grid lg:grid-cols-[minmax(0,1fr)_16rem] lg:gap-12">
      <%= render "blogs/toc_sidebar", entries: article.toc_entries %>
<% end %>
    <div class="prose prose-lg <%= article.toc? ? 'lg:col-start-1 lg:row-start-1 prose-h2:mt-20 prose-h3:mt-12' : 'max-w-none' %> mb-16 <%= 'prose-paragraph-relaxed' if @blog.spacing == 'relaxed' %>">
      <%= article.html %>
    </div>
<% if article.toc? %>
    </div>
<% end %>
```

TOC-off output, byte-for-byte:
```
    <div class="prose prose-lg max-w-none mb-16 ">
      …body…
    </div>
```
Note the `div.prose` line, its child line, and its closing line are **unmoved and unindented**. The `<% if %>` / `<% end %>` lines emit nothing. `article` is assigned once earlier via a standalone `<% article = blog_article(@blog) %>` line (also zero-output).

### Example 4: `_toc_sidebar.html.erb`

```erb
<div class="hidden lg:block lg:col-start-2 lg:row-start-1 lg:self-start lg:sticky lg:top-8 lg:max-h-[calc(100vh-4rem)] lg:overflow-y-auto">
  <nav aria-label="Table of contents">
    <p class="text-sm font-semibold uppercase tracking-wide text-gray-900 mb-4">Table of Contents</p>
    <ol role="list" class="list-none space-y-2 pl-0">
      <% entries.each do |entry| %>
        <li class="<%= entry.level == 3 ? 'pl-4' : '' %>">
          <%= link_to "##{entry.anchor}",
                      class: "block no-underline transition-colors #{entry.level == 3 ? 'text-sm text-gray-500' : 'text-gray-900'} hover:text-pink-600" do %>
            <%= sanitize(entry.label_html, tags: %w[strong em code], attributes: []) %>
          <% end %>
        </li>
      <% end %>
    </ol>
  </nav>
</div>
```
The inner `sanitize` is Pitfall 4's fix — it strips a nested `<a>` while keeping its text. Whitespace here is unconstrained: this partial only ever renders on the TOC-on branch, which has no golden master.

### Example 5: Permalink hover-reveal CSS

```css
/* app/assets/stylesheets/application.tailwind.css — append, after the @import */
.toc-permalink {
  margin-left: 0.35em;
  text-decoration: none;
  opacity: 0;
  transition: opacity 150ms ease-in-out;
}
.prose h2:hover .toc-permalink,
.prose h3:hover .toc-permalink,
.toc-permalink:focus-visible {
  opacity: 1;
}
@media (prefers-reduced-motion: reduce) {
  .toc-permalink { transition: none; }
}
```
Why plain CSS rather than utilities: revealing a child on **parent** hover needs either `group`/`group-hover:` (which would require injecting `class="group"` onto author headings — more mutation of author markup) or a descendant selector. `application.tailwind.css` already carries two precedents for narrow custom rules (`.prose-paragraph-relaxed p`, the `.tiptap-editor` block), and rules written after `@import "tailwindcss"` sit outside Tailwind's cascade layers so they reliably beat the plugin's zero-specificity `:where()` base styles.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `tailwind.config.js` with a `content: []` array | Tailwind v4 CSS-first config; automatic source detection scans all non-gitignored, non-`node_modules`, non-CSS, non-binary files as plain text | Tailwind v4.0 | No config file needed; classes written in `.rb`, `.erb`, or `.html` are all picked up — but string concatenation still fails `[CITED: tailwindcss.com/docs/detecting-classes-in-source-files]` |
| `theme()` / JS plugin config for typography overrides | `@plugin "@tailwindcss/typography"` + `prose-h2:` element modifiers | typography 0.5.x + Tailwind v4 | D-14 needs no config change at all |
| JS scroll listeners for sticky sidebars | `position: sticky` (Baseline widely available) | ~2019 | Phase 2's zero-JS layout is straightforwardly achievable |
| `1fr` grid tracks | `minmax(0,1fr)` for any track holding overflowing content | long-standing known behavior | Non-optional here given `<pre>`/`<table>` bodies |

**Deprecated/outdated:**
- `document.addEventListener('DOMContentLoaded', …)` in a Turbo Drive app: superseded by `turbo:load`. `_navigation.html.erb:201` still uses the old form and is effectively dead code after the first navigation. **Not this phase's job to fix** (it would break every `*.page.html` golden master) — record it for a separate quick task.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | 65ch renders at ~610–645px at 18px in the default `ui-sans-serif` stack | Pattern 4 | Column width math is off by ±10%; only affects the container-width recommendation in Open Question 1, verifiable in-browser in seconds |
| A2 | Placing the TOC nav *before* the article in DOM order is preferable for screen readers | Pattern 5 | Either order is WCAG-conformant; this is a quality judgment, not a compliance requirement |
| A3 | A visible `<p>` label (not `<h2>`) for "Table of Contents" is better for the heading outline | Pattern 5 | Purely stylistic; no requirement mandates either |
| A4 | `role="list"` is needed because `list-style: none` drops list semantics in Safari/VoiceOver | Pattern 5 | Adding it is harmless; omitting it may degrade VoiceOver announcement |
| A5 | Phase 4's admin form will submit the `hidden` flag as a Rails checkbox (`"1"`/`"0"`) | Pitfall 6 | If Phase 4 writes real JSON booleans instead, the `Boolean.cast` is simply redundant — cost of being wrong is zero |
| A6 | `max-w-5xl` is the right TOC-on container width | Open Question 1 | Article measure ends up too narrow or too wide; trivially adjustable, but it changes the hero/title width too — **user-visible, should be confirmed** |
| A7 | Widening the TOC-on container at all is within the user's intent | Open Question 1 | If the user expected the hero/title to stay at `max-w-4xl`, the article column drops to ~528px. Needs confirmation |
| A8 | Adding `max-height`/`overflow-y-auto` to the sticky sidebar belongs in Phase 2 rather than Phase 3 | Pitfall 8 / Open Question 6 | Scope-boundary disagreement only; the CSS is 2 classes either way |

## Open Questions (RESOLVED — 6/8 implemented in plans, 2 routed to Plan 02-03's human checkpoint)

1. **Does the TOC-on branch widen its container, and to what?** *(UNRESOLVED — routed to 02-03-PLAN.md's human-verify checkpoint, item 11 of the manual QA checklist)*
   - **What we know:** `show.html.erb:28` wraps hero, title, image, excerpt, body, FAQ, author card, and share section in a single `max-w-4xl mx-auto px-4 sm:px-6 lg:px-8`. At `lg`, that is 896px minus 64px padding = **832px of content box**. Subtracting a 16rem (256px) sidebar and a 3rem (48px) gap leaves the article at **528px** — narrower than the plugin's own 65ch (~620px), so D-13's "constrained to prose-lg's max-width" would be satisfied only incidentally, by the grid rather than by prose. CONTEXT.md's D-01–D-04 never addressed the container width; ROADMAP criterion 3 explicitly blesses "separate container branches," so widening the TOC-on branch **is** permitted.
   - **What's unclear:** Whether the user anticipated that the TOC-on hero/title/image also widen. Widening only the content row while leaving the hero at `max-w-4xl` would misalign the article's left edge against the title's — both are `mx-auto` centered at different widths.
   - **Recommendation:** Branch the container on line 28 (`max-w-5xl` when TOC-on, `max-w-4xl` otherwise). At 1024px content box minus 64px padding minus 256px sidebar minus 48px gap = **656px** article column, so the plugin's 65ch binds with ~36px slack — D-13 satisfied *by prose*, everything stays aligned, and no horizontal overflow at exactly the `lg` breakpoint (the container clamps to viewport width there). Flag this to the user during planning; it is one class and trivially reversible, but it is user-visible.

2. **RESOLVED — Flat `<ol>` or nested `<ol>` for H3 entries?** Shipped flat, per recommendation, in 02-02-PLAN.md.
   - **What we know:** D-06 locks the *visual* treatment (indent + smaller/lighter). It does not specify markup. `Blog::TableOfContents#entries` is a flat, ordered array with a `level` field.
   - **What's unclear:** Nested lists convey hierarchy to screen readers for free at identical visual cost, but need a grouping pass plus an edge case for an H3 that precedes any H2 (possible — nothing forces authors to start with H2).
   - **Recommendation:** Ship flat (Example 4) for Phase 2. It satisfies D-06 and A11Y-01 exactly, and TOCV2-01 already parks hierarchy work. Note nesting as a candidate if a11y review later asks for it.

3. **RESOLVED — Where does `aria-current` come from?** A11Y-01 scoped to the `<nav aria-label>` half for Phase 2 only, per recommendation; `aria-current` deferred to Phase 3. REQUIREMENTS.md traceability corrected accordingly by 02-03-PLAN.md Task 2.
   - **What we know:** A11Y-01's full text includes "with the active entry marked `aria-current`," but "active entry" only exists once scroll-spy does. ROADMAP's Phase 2 criterion 4 mentions only the `<nav aria-label>` wrapper and the permalink affordance. INTX-02 (scroll-spy) is Phase 3.
   - **Recommendation:** Phase 2 delivers the `<nav aria-label="Table of contents">` half; Phase 3 delivers `aria-current="location"` (the correct token for "current item in a set of links"). The planner should mark A11Y-01 as **partially** covered so REQUIREMENTS.md traceability doesn't claim it as done at the end of this phase.

4. **RESOLVED — How is the sticky/hover behavior verified with no system-spec infrastructure?** Implemented per recommendation: request specs for statically-verifiable behavior plus a written manual QA checklist (`02-MANUAL-QA.md`), both delivered in 02-03-PLAN.md.
   - **What we know:** `capybara` 3.40 and `selenium-webdriver` 4.36 are in the `:test` group, but `spec/rails_helper.rb` contains **zero** Capybara/system configuration and `spec/system/` does not exist `[VERIFIED: grep + ls]`. STATE.md already logs this as an open blocker for Phase 3.
   - **Recommendation:** Phase 2 should verify everything statically-verifiable with request specs (sidebar present/absent, entry count, threshold at exactly 2/3/4, `<nav aria-label>` string, permalink `href` matches heading `id`, golden masters green) and cover sticky/hover/measure with a short written manual QA checklist. Standing up `spec/system` is real infrastructure work that Phase 3 needs more than Phase 2 does — don't spend Phase 2's budget on it unless the planner deliberately front-loads it.

5. **RESOLVED — Is the permalink focusable?** Shipped focusable (option a), per D-15 and Example 2, in 02-01/02-02-PLAN.md.
   - **What we know:** D-15 says "fades in on hover/focus," which implies it takes focus. But a focusable, tabbable link adds one tab stop per heading, and its accessible name becomes part of the heading's accessible name.
   - **Two coherent designs:**
     - **(a) Focusable** — `<a class="toc-permalink" href="#…" aria-label="Permalink to X"><span aria-hidden="true">#</span></a>`. Matches D-15. Heading is announced as "Getting Started, Permalink to Getting Started, heading level 2" (verbose but not wrong).
     - **(b) Mouse-only, GitHub's actual pattern** — `aria-hidden="true" tabindex="-1"`. Zero a11y-tree noise, no extra tab stops; keyboard users navigate via the sidebar instead. But contradicts D-15's "focus."
   - **Recommendation:** (a), since D-15 is a locked decision. Example 2 implements it. Do **not** combine `aria-hidden` with a focusable element.

6. **RESOLVED — Does the sticky sidebar get `max-height` + `overflow-y-auto` in this phase?** Yes, per recommendation — included in the sidebar CSS in 02-02-PLAN.md.

7. **RESOLVED — Should `prose-headings:scroll-mt-8` be added now?** Yes, per recommendation — included in 02-02-PLAN.md; overlap with Phase 3's INTX-01 noted in the plan.

8. **UNRESOLVED — views4you.com reference verification.** STATE.md logs the site returned HTTP 403 to automated fetch. Routed to 02-03-PLAN.md's human-verify checkpoint (same manual QA checklist item 11 as Question 1) since precise spacing/sizing is settled visually, not by research.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Ruby | Everything | ✓ | 3.4.2 (arm64-darwin24) | — |
| Bundler | Gem loading | ✓ | 2.6.2 | — |
| Node.js | esbuild / Tailwind CLI | ✓ | 24.2.0 | — |
| Yarn | `yarn build:css` | ✓ | 1.22.22 | `npm run build:css` |
| PostgreSQL | Request specs | ✓ | accepting connections on `/tmp:5432` | — |
| `@tailwindcss/cli` | Compiling new utility classes | ✓ | 4.1.14 (node_modules) | — |
| `@tailwindcss/typography` | `prose-*` modifiers | ✓ | 0.5.19 (node_modules) | — |
| Built `application.css` | Request specs (Propshaft resolves it) | ✓ | present, 95.5K in `app/assets/builds/` | run `yarn build:css` |
| Nokogiri (HTML5) | Permalink injection | ✓ | via Rails; `Nokogiri::HTML5.fragment` verified working | — |
| `spec/system` infrastructure | Sticky/hover behavior specs | ✗ | Capybara + Selenium installed but **unconfigured**, no `spec/system/` dir | Manual QA checklist (recommended) — see Open Question 4 |
| Context7 MCP / `ctx7` CLI | Library docs | ✗ | not installed | Used WebFetch against official docs + direct `node_modules` source reads instead (equal or better fidelity here, since the installed versions are what actually matter) |

**Missing dependencies with no fallback:** none — nothing blocks execution.

**Missing dependencies with fallback:**
- System-spec infrastructure → written manual QA checklist for sticky, hover-reveal, measure, and breakpoint behavior.
- `ctx7` → all library facts in this document were read directly from the installed `node_modules`/gem source or from official docs via WebFetch, which is strictly more accurate for this phase than a docs index would have been.

**Operational note carried from Phase 1's deferred items:** `app/assets/builds/*` is gitignored; a fresh worktree without a CSS build produces 24 unrelated request-spec failures (`Propshaft::MissingAssetError`). This worktree has a built `application.css`, but any executor working in a new worktree must run `yarn build:css` before running request specs. Since this phase introduces new Tailwind classes, `yarn build:css` must be re-run before verification regardless — and the golden `*.page.html` fixtures already normalize the asset digest, so a CSS rebuild will not falsely fail them.

## Security Domain

`security_enforcement` is not set in `.planning/config.json`, so it is treated as enabled.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Public read-only page; Devise untouched |
| V3 Session Management | no | No session interaction |
| V4 Access Control | no | Public blog show action; no new authorization surface |
| **V5 Input Validation / Output Encoding** | **yes** | View-level `sanitize` with `Blog::ALLOWED_TAGS`/`ALLOWED_ATTRIBUTES` remains the sole trust boundary. All Phase 2 mutations happen **downstream** of it and must introduce only app-authored markup. `ERB::Util.html_escape` for the permalink `aria-label`. A second, narrower `sanitize(tags: %w[strong em code])` when rendering `entry.label_html` inside the sidebar link |
| V6 Cryptography | no | None involved |
| V7 Error Handling / Logging | no | No new error paths |
| V13 API / Data Integrity | **yes (regression guard)** | `blogs_toc_spec.rb` already asserts `blogs.body` is never mutated and that the `.md` export and `/api/v1/blogs/:slug` `content_html` stay byte-equal to `body`. Permalink injection must not change that — it mutates the in-memory fragment only |

### Known Threat Patterns for Rails 8 + Nokogiri + ERB

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Stored XSS via author heading text reaching an unescaped attribute | Tampering / Elevation | `ERB::Util.html_escape(node.text)` before interpolating into `aria-label`; never build attributes by raw string interpolation of author content |
| Sanitizer-bypass by widening the allowlist to accommodate new markup | Tampering | **Do not touch `Blog::ALLOWED_TAGS`/`ALLOWED_ATTRIBUTES`.** Phase 1 D-03 established render-time injection precisely so `id` never enters the allowlist; the permalink `<a>`/`class` must follow the same route |
| `html_safe` on a value that is not actually sanitized | Tampering | Only `to_html` output of the fragment derived from already-sanitized input gets `.html_safe`. `entry.label_html` is already a SafeBuffer from `ActionController::Base.helpers.sanitize`; re-sanitizing it (Pitfall 4) keeps it safe |
| Anchor href injection via a crafted heading | Tampering | `entry.anchor` is `parameterize` output constrained to `[a-z0-9-]`, `toc-` prefixed, with numeric dedup suffixes `[VERIFIED: table_of_contents.rb:57-80]`. Prefer `link_to "##{anchor}"` (Rails escapes the attribute) over hand-built `<a href=...>` |
| **Future (Phase 4):** stored XSS via admin-supplied override *labels* | Tampering | Flag now: when Phase 4 renders `toc_overrides[anchor]["label"]`, it must be escaped or sanitized. Phase 2 reads only the boolean `hidden` flag and never renders override-sourced strings, so there is no exposure yet |
| Open redirect / SSRF | — | Not applicable; all generated hrefs are same-document fragments |

**Brakeman note:** `.html_safe` calls draw Brakeman's attention. Keep the existing `# SECURITY:` comment convention in `blogs_helper.rb` (it currently documents exactly this) and extend it to cover the permalink injection, so the reviewer has the argument in-line.

## Sources

### Primary (HIGH confidence — verified in this repo or against installed source)
- `app/models/blog/table_of_contents.rb` — `Entry` struct fields, `LABEL_TAGS` (includes `a`), `ANCHOR_PREFIX`, `derive!` entry-capture ordering, `MAX_SLUG_LENGTH`
- `app/helpers/blogs_helper.rb` — current `blog_body_with_toc_anchors` and its SECURITY comment convention
- `app/views/blogs/show.html.erb:28,75-80` — `max-w-4xl` container, `prose prose-lg max-w-none mb-16` + `spacing` conditional
- `spec/support/golden_master.rb` — `article_region` = `at_css("div.prose").to_html` (zero normalization); `NORMALIZERS` (3 regexes only)
- `od -c spec/fixtures/golden_master/minimal_post.article.html` — exact frozen bytes incl. the trailing space in the `class` attribute
- Empirical Erubi test (`erubi` 1.13.1, `trim: true` vs `false`) — standalone `<% %>` lines emit zero bytes
- `/Users/irfan/.rbenv/.../actionview-8.0.5/lib/action_view/template/handlers/erb.rb:12-14,83` — `erb_trim_mode` defaults to `"-"` → `trim: true`
- Empirical Nokogiri test (`bundle exec ruby`) — permalink `add_child` round-trip, entity preservation, `node.text` contamination, nested-`<a>` parser split
- `node_modules/@tailwindcss/typography/src/styles.js:1414` — `maxWidth: '65ch'` set once in DEFAULT, not overridden by `lg`
- `node_modules/@tailwindcss/typography/src/styles.js` (`lg:` block) — `prose-lg` font sizes and heading margins
- `node_modules/@tailwindcss/typography/README.md:149-172` — element-modifier list (`prose-headings:`, `prose-h2:`, `prose-a:`, …), v0.5.19
- `app/views/shared/_navigation.html.erb:12,200-278` — unlabeled `<nav>`, `DOMContentLoaded`-bound smooth-scroll handler
- `app/views/layouts/application.html.erb`, `app/javascript/application.js` — Turbo Drive active, no `data-turbo="false"` anywhere
- `db/schema.rb:141-142` — `toc_enabled` boolean default false, `toc_overrides` jsonb default `{}` null:false
- `Gemfile` `:test` group + `spec/rails_helper.rb` — Capybara/Selenium present, zero system-spec configuration
- `spec/requests/blogs_toc_spec.rb`, `spec/models/blog/table_of_contents_spec.rb` — existing assertions Phase 2 must not break
- Local environment probe — Ruby 3.4.2, Node 24.2.0, Yarn 1.22.22, Bundler 2.6.2, Postgres accepting connections, `application.css` built

### Secondary (MEDIUM-HIGH confidence — official documentation)
- https://developer.mozilla.org/en-US/docs/Web/CSS/position — sticky constraint rectangle; `overflow: hidden|scroll|auto|overlay` ancestors create the scroll container; at least one non-`auto` inset required
- https://tailwindcss.com/docs/grid-template-columns — Tailwind v4 arbitrary value syntax; underscores represent spaces
- https://tailwindcss.com/docs/detecting-classes-in-source-files — v4 automatic source detection scans all non-gitignored, non-`node_modules`, non-CSS, non-binary files as plain text; concatenated class names are not detected
- https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Values/minmax — `1fr` == `minmax(auto, 1fr)`; `auto` floors at min-content

### Tertiary (MEDIUM confidence — corroborating community sources, cross-checked against each other)
- https://defensivecss.dev/tip/position-sticky-grid/ — `align-self: start` fix for sticky grid items
- https://ishadeed.com/article/position-sticky-css-grid/ — same, with the stretch-height explanation
- https://css-tricks.com/using-position-sticky-with-css-grid/ — same
- https://polypane.app/blog/getting-stuck-all-the-ways-position-sticky-can-fail/ — comprehensive sticky failure catalogue
- https://makandracards.com/makandra/608104-prevent-1fr-grid-column-overflow — `minmax(0,1fr)` fix
- https://github.com/rachelandrew/gridbugs/issues/55 — `fr`-only tracks and overflow in grandchildren
- https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/navigation_role — naming multiple nav landmarks; avoid "navigation" in the accessible name
- https://usability.yale.edu/web-accessibility/articles/navigation — DOM order drives screen-reader order (WCAG 1.3.2)

## Metadata

**Confidence breakdown:**
- Standard stack: **HIGH** — zero new packages; every version read from the installed `node_modules`/gem tree rather than a registry or training data
- Architecture / layout mechanics: **HIGH** — the two CSS Grid landmines and the ERB trim behavior were each verified against three independent sources or reproduced locally
- Golden-master byte-fidelity strategy: **HIGH** — exact bytes dumped with `od -c`, spec source read, Erubi behavior reproduced
- Permalink injection: **HIGH** — both failure modes (label contamination, nested `<a>`) reproduced in this repo with `bundle exec ruby`
- Pitfalls: **HIGH** for 1–5 and 7–8; **MEDIUM** for 6 (depends on Phase 4's not-yet-written form)
- Container-width recommendation (Open Question 1): **MEDIUM** — the arithmetic is sound, but the `ch`→px conversion is font-metric dependent and the design intent needs user confirmation
- A11y markup choices (nav DOM order, `<p>` vs `<h2>` label, `role="list"`): **MEDIUM** — conformant either way; these are quality judgments, logged in the Assumptions table

**Research date:** 2026-08-02
**Valid until:** 2026-09-01 (30 days — the stack is stable and all findings are pinned to installed versions; the only external-facing claims are CSS behaviors that do not churn)
