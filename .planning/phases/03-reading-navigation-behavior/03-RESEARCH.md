# Phase 3: Reading Navigation Behavior - Research

**Researched:** 2026-08-08
**Domain:** Browser scroll/intersection APIs, native disclosure a11y, Stimulus/Turbo event ordering, Rails 8 Capybara system-spec infrastructure
**Confidence:** HIGH

## Summary

Nearly every open technical question in this phase was resolved by **direct empirical measurement** against this repo's actual blog page in headless Chrome 151, driven through the project's own Capybara/Selenium stack. That includes the `rootMargin` band arithmetic, the bottom-of-page special case, the `<details>` accessibility tree mapping, the legacy-handler collision, and whether the existing DatabaseCleaner configuration breaks system specs. Very little of this research is inference.

Three findings materially change the shape of the plan:

1. **The D-14 landmine is worse than CONTEXT.md assumed, and the fix CONTEXT.md proposed does not work.** `stopPropagation()` or `stopImmediatePropagation()` on the TOC link itself does **not** suppress the legacy handler, because the legacy handler registers its listener on the anchor *before* Stimulus does. The only approach that works without editing `_navigation.html.erb` is a **capture-phase listener on an ancestor** that calls `stopPropagation()`. This is measured, not theorised.
2. **System-spec infrastructure is nearly free.** rspec-rails 7.1 on Rails 8 already defaults system specs to `:selenium_chrome_headless`; Selenium Manager already resolves chromedriver with no `webdrivers` gem; CI already installs Chrome and builds assets; and — critically — the existing `use_transactional_fixtures` + DatabaseCleaner `:transaction` config **already works** with a real browser. A working end-to-end system spec was run against this repo during research. D-13's scope shrinks to "add `spec/system/`, declare `type: :system`".
3. **`app/assets/builds/` was stale and Phase 2's CSS was not compiling into the test environment.** `scroll-margin-top` computed to `0px`, and `lg:sticky` / `lg:overflow-y-auto` computed to `static` / `visible`. After `npm run build:css` all of them work correctly. Any Phase 3 system spec touching layout or scroll offset will fail spuriously on a stale local build. CI is unaffected (it builds assets first).

**Primary recommendation:** Build one Stimulus controller (`toc`) mounted on a wrapper that contains both the desktop sidebar and the mobile `<details>`. Bind link clicks with `data-action="click->toc#navigate:capture"` and call `stopPropagation()` + `preventDefault()` inside. Drive scroll-spy with a single IntersectionObserver using `rootMargin: "<bigPx>px 0px -75% 0px"`, "last intersecting heading wins", a `headings[0]` fallback for page top, an explicit `atBottom()` override for the last section, and synchronous hash resolution in `connect()`. Add `spec/system/` with `type: :system` declared explicitly.

## User Constraints (from CONTEXT.md)

### Locked Decisions

**Scroll-spy active-section feel**
- **D-01:** The "active" trigger line sits in a near-top band — a heading becomes active once it crosses roughly the top 20-25% of the viewport (IntersectionObserver `rootMargin` tuned to that band). Matches common docs-site TOC patterns (GitBook/Docusaurus-style); feels responsive as new sections come into view near the top rather than lagging until they reach center.
- **D-02:** The first TOC entry is active by default at the very top of the page (before the reader has scrolled past the first heading) — the TOC is never in a state where nothing is highlighted.
- **D-03:** The last section's entry becomes active once the reader reaches the bottom of the page, even if that section is too short to naturally cross the top-band trigger — implemented as an explicit bottom-of-page special case (e.g. `scrollTop + clientHeight >= scrollHeight` check), not left to the IntersectionObserver alone. Required by success criterion #2's "correct... on the final section."
- **D-04:** On initial load via a `#anchor` deep link, the matching entry is computed and marked active synchronously on `connect()` from `window.location.hash`, before any scroll/observer event fires — avoids a flash of "first entry active" before the real position is known.

**Mobile Contents disclosure**
- **D-05:** Built as a native `<details>/<summary>` element, not a custom button+panel. Free keyboard toggle (Enter/Space), degrades with zero JS, no manual ARIA wiring for open/closed state. Escape-to-close is not native in all browsers and needs a small JS assist (D-06).
- **D-06:** Success criterion #4's "reports state with `aria-expanded`" is satisfied by the native `<details>` `open` attribute, not a literal `aria-expanded` attribute — screen readers already key off `open` for disclosure state, and it's the accessibility-equivalent contract. This is a deliberate reinterpretation of the roadmap's literal wording, made because the wording predates the implementation-pattern decision (D-05).
- **D-07:** The trigger (`<summary>`) label is the static string **"Contents"** — matches the roadmap's own phrasing ("tappable Contents disclosure"), and Phase 2 D-05 already established that the mobile trigger's label is independent of the desktop sidebar's "Table of Contents" heading.
- **D-08:** The trigger label stays static regardless of scroll position — it does NOT show the currently active section name. Keeps scroll-spy state and the (possibly collapsed) trigger decoupled; roadmap only requires open/close/auto-close/keyboard behavior, not a live label.
- **D-09 (follows from D-05, not separately asked):** `<details>` auto-closes after an entry is selected by setting `open = false` in the click handler (native `<details>` doesn't auto-close on internal link click).

**Focus management**
- **D-10:** Clicking a TOC entry — on desktop OR inside the mobile disclosure — moves keyboard focus to the target heading. Same code path for both; no separate "mobile returns to trigger first" step. Satisfies A11Y-02 uniformly.
- **D-11:** When the mobile disclosure is closed via Escape (not by selecting an entry), focus returns to the `<summary>` trigger button — standard disclosure/dialog convention: Escape is a pure cancel, so focus goes back to what opened it. Only entry-selection sends focus to a heading (D-10); Escape never does.

**Verifying dynamic JS behavior**
- **D-12:** This phase stands up `spec/system` with Capybara + `selenium_chrome_headless` (Selenium + headless Chrome). `selenium-webdriver` is already in the Gemfile's test group, unused — this phase is the first that needs a real JS driver, since scroll-spy/focus/keyboard behavior can't be meaningfully verified by request specs or a manual checklist alone (unlike Phase 2's static layout, which was manual-QA'd). System specs should cover at minimum: scroll-spy activates the correct entry as the page scrolls, clicking an entry moves focus to the heading, the mobile disclosure opens/closes via keyboard and Escape with focus returning to the trigger, and disclosure auto-closes on entry selection.
- **D-13:** No new gem required — `capybara` + `selenium-webdriver` are already present; the work is registering the `:selenium_chrome_headless` Capybara driver and adding `spec/system/` with `rails_helper` JS-driver config.

**Known landmine**
- **D-14:** `app/views/shared/_navigation.html.erb` (lines 261-278) already has a global inline smooth-scroll handler (`document.querySelectorAll('a[href*="#"]')` inside a `DOMContentLoaded` listener) that intercepts ALL anchor-hash links site-wide, including future TOC links. It does not respect `prefers-reduced-motion`, does not move focus, and — because it's `DOMContentLoaded`-scoped rather than `turbo:load`-scoped — does not rebind after a Turbo Drive navigation swaps in a new page's TOC links. Phase 3's new Stimulus controller must own TOC link clicks itself (`event.preventDefault()` + `stopPropagation()` or an equivalent exclusion) rather than relying on or fighting this existing handler, to avoid double-scroll or the global handler silently winning on same-session Turbo-navigated posts. This is an implementation detail, not something requiring a user decision — flagged here so the planner treats it as a required task, not a surprise.

> **Research correction to D-14:** the *diagnosis* is confirmed exactly (see Pitfall 1), but the suggested remedy is wrong. `stopPropagation()` on the link does not work. See "Verified fix" in Pitfall 1.

### Claude's Discretion
- Exact `rootMargin`/`threshold` values implementing D-01's near-top band (tunable in-browser).
- Stimulus controller name/file structure (e.g. `toc_controller.js`), whether scroll-spy and mobile-disclosure logic live in one controller or two.
- Exact IntersectionObserver vs scroll-listener implementation for keeping the active sidebar entry in view (INTX-03) — CSS container (`overflow-y-auto`) already exists from Phase 2.
- `prefers-reduced-motion` check implementation (`matchMedia` query, checked at click time).
- Exact system spec file organization and naming under `spec/system/`.
- Whether disclosure logic needs its own Stimulus controller or is folded into the same TOC controller as scroll-spy.

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within Phase 3 scope. Multi-page posts, gem extraction, and broader nav/discovery UX remain deferred at the project level per PROJECT.md Out of Scope.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| LAYOUT-02 | TOC collapses into a tappable "Contents" dropdown above the article on mobile widths, auto-closing after an entry is selected | Pattern 4 (`<details>` markup + Tailwind `open:`/`group-open:` variants, all compile-verified); Pattern 5 (auto-close via `open = false`) |
| INTX-01 | Clicking a TOC entry smooth-scrolls to the corresponding section, gated on `prefers-reduced-motion`, with correct scroll offset (`scroll-margin-top`) so the sticky header doesn't cover the target | Pattern 3 (`navigate()`); verified `scroll-margin-top: 32px` is honored by `scrollIntoView` after an asset rebuild; `matchMedia` gate; CDP emulation for tests |
| INTX-02 | Active section is highlighted in the TOC as the reader scrolls (scroll-spy via IntersectionObserver), correct at page top, at the last section, and on initial load via a `#hash` deep link | Pattern 1 + Pattern 2; full algorithm executed end-to-end against a real blog post covering all four cases |
| INTX-03 | TOC sidebar internally scrolls and keeps the active entry in view when the entry list is taller than the viewport (>10 headings) | Pattern 6; measured that `scrollIntoView({block:'nearest'})` does not move `window.scrollY` in this sticky container |
| A11Y-02 | Clicking a TOC entry moves keyboard focus to the target heading | Pattern 3 `focusHeading()`, modelled on Turbo's own `View#focusElement`; verified headings need `tabindex` to be focusable |
| A11Y-03 | Mobile "Contents" dropdown is a real disclosure control (`aria-expanded` button or `<details>/<summary>`), fully keyboard-operable | Accessibility-tree dump verifying `expanded: false/true` tracks `open`; Enter toggles; Tab skips closed content; Escape needs JS assist |
| A11Y-01 (partial) | `aria-current` on the active entry (Phase 2 delivered the `<nav>` landmark) | `aria-current="location"` recommended; Tailwind `aria-[current]:` variant compile-verified |

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Heading anchor IDs + TOC entry list | Backend (Rails helper) | — | Already delivered by Phase 1/2 at render time; Phase 3 reads the rendered DOM and must not recompute anchors |
| Two-column layout, sticky sidebar, scroll container | CDN/Static (Tailwind CSS) | — | Delivered by Phase 2; Phase 3 consumes `lg:sticky` / `lg:overflow-y-auto` / `prose-headings:scroll-mt-8` as-is |
| Mobile `<details>` disclosure markup | Frontend Server (ERB view) | Browser (Stimulus) | Markup must be server-rendered so it works with zero JS (D-05); JS only adds Escape + auto-close |
| Scroll-spy active-section tracking | Browser (Stimulus + IntersectionObserver) | — | Pure viewport geometry; no server knowledge possible |
| Click-to-jump, smooth scroll, focus move | Browser (Stimulus) | — | Requires `preventDefault` + focus APIs; must out-rank the legacy inline handler and Turbo's link observer |
| Sidebar internal auto-scroll (INTX-03) | Browser (Stimulus) | CDN/Static (CSS container from Phase 2) | Container exists in CSS; only the `scrollTop` adjustment is JS |
| Teardown on Turbo navigation | Browser (Stimulus `disconnect()`) | — | Turbo replaces `<body>`, Stimulus fires `disconnect()`; project also has a `turbo:before-cache` → `teardown()` convention |
| Behavioral regression coverage | Test infrastructure (RSpec system specs) | — | Only a real browser can exercise IntersectionObserver, focus, and keyboard behavior |

## Standard Stack

No new libraries. Everything required is already installed and verified present in this repo.

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `@hotwired/stimulus` | 3.2.2 | TOC controller (scroll-spy, click-to-jump, disclosure) | Project-wide constraint: Rails/Stimulus/esbuild only, no React/Vue [VERIFIED: package-lock.json] |
| `@hotwired/turbo-rails` | 8.0.18 | Page navigation; controller lifecycle boundary | Already the app's navigation layer [VERIFIED: package-lock.json] |
| `tailwindcss` | 4.1.14 | Active-entry styling, disclosure styling, responsive gating | Project styling system [VERIFIED: package-lock.json] |
| `capybara` (gem) | 3.40.0 | System-spec DSL | Already in `Gemfile` test group [VERIFIED: Gemfile.lock] |
| `selenium-webdriver` (gem) | 4.36.0 | Real-browser driver for system specs | Already in `Gemfile` test group [VERIFIED: Gemfile.lock] |
| `rspec-rails` (gem) | 7.1.1 | `type: :system` example group | Already the test framework [VERIFIED: Gemfile.lock] |

### Supporting (browser platform, no install)
| API | Purpose | When to Use |
|-----|---------|-------------|
| `IntersectionObserver` | Scroll-spy trigger | Core of INTX-02. Verified available in headless Chrome 151 in this repo's test env |
| `Element.scrollIntoView({behavior, block})` | Click-to-jump; sidebar containment | INTX-01, INTX-03. Honors `scroll-margin-top` |
| `HTMLElement.focus({preventScroll})` | Focus without fighting the smooth scroll | A11Y-02. `preventScroll: true` verified working |
| `window.matchMedia('(prefers-reduced-motion: reduce)')` | Motion gating | INTX-01 |
| `<details>` / `<summary>` + `toggle` event | Mobile disclosure | LAYOUT-02, A11Y-03 |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| IntersectionObserver | Throttled `scroll` listener + `getBoundingClientRect()` per heading | Simpler mental model and immune to `rootMargin` subtleties, but runs layout reads on every frame. IO is the requirement's own wording (INTX-02) and measurably works. Keep as a fallback only if IO proves flaky |
| `<details>`/`<summary>` | `<button aria-expanded>` + panel | Requires hand-wiring ARIA state, keyboard toggle, and content inertness. `<details>` gives all three free (verified). Locked by D-05 |
| Custom Capybara driver registration | Rails' built-in `driven_by :selenium, using: :headless_chrome` | Built-in is fewer moving parts **and** sets a deterministic window size (Capybara's own `:selenium_chrome_headless` does not) — see Pitfall 4 |
| `scrollIntoView({block:'nearest'})` for INTX-03 | Manual `container.scrollTop` arithmetic | Measured identical results with no page movement. Prefer `block:'nearest'`; manual math documented as fallback |

**Installation:** none. No `npm install`, no `bundle add`.

## Package Legitimacy Audit

**Not applicable — this phase installs zero external packages.** Every dependency it uses is already present in `package.json` / `Gemfile` and was verified installed in this working tree:

| Package | Registry | Already in lockfile | Verified how |
|---------|----------|--------------------|--------------|
| `@hotwired/stimulus` 3.2.2 | npm | yes | `package-lock.json` read directly |
| `@hotwired/turbo-rails` 8.0.18 | npm | yes | `package-lock.json` read directly |
| `tailwindcss` 4.1.14 | npm | yes | `package-lock.json` read directly |
| `capybara` 3.40.0 | rubygems | yes | `Gemfile.lock` read directly |
| `selenium-webdriver` 4.36.0 | rubygems | yes | `Gemfile.lock` read directly + gem source inspected on disk |

**Packages removed due to slopcheck [SLOP] verdict:** none — no packages proposed.
**Packages flagged as suspicious [SUS]:** none.

**Explicit non-recommendation:** do **not** add the `webdrivers` gem. It is deprecated and unnecessary — Selenium Manager (bundled in selenium-webdriver 4.36.0) already resolves chromedriver. Verified by running the bundled `selenium-manager` binary, which reported an already-cached driver at `~/.cache/selenium/chromedriver/mac-arm64/151.0.7922.77/chromedriver` for the installed Chrome 151.0.7922.108. [VERIFIED: local execution]

## Architecture Patterns

### System Architecture Diagram

```
                    ┌─────────────────────────────────────────┐
   HTTP GET         │  Rails: BlogsController#show            │
   /blog/:slug ────▶│    └─ BlogsHelper#blog_article          │
   (or Turbo Drive) │         ├─ sanitize(body)               │
                    │         ├─ Blog::TableOfContents.call   │  (Phase 1)
                    │         │    └─ injects toc-* ids       │
                    │         └─ visible_toc_entries          │  (Phase 2)
                    └───────────────┬─────────────────────────┘
                                    │ ArticleContent{html, toc_entries}
                                    ▼
              ┌──────────────────────────────────────────────────┐
              │ show.html.erb  (data-controller="toc" wrapper)    │
              │                                                  │
              │  ┌────────────────────┐   ┌────────────────────┐ │
              │  │ _toc_disclosure    │   │ _toc_sidebar       │ │
              │  │ <details> lg:hidden│   │ hidden lg:block    │ │
              │  │  <summary>Contents │   │  <nav aria-label>  │ │
              │  │  <nav><a href=#…>  │   │   <a href="#…">    │ │
              │  └─────────┬──────────┘   └─────────┬──────────┘ │
              │            │  data-toc-target="link"│            │
              │  ┌─────────▼────────────────────────▼──────────┐ │
              │  │ div.prose  (article HTML, h2/h3 have ids)   │ │
              │  └─────────────────────────────────────────────┘ │
              └──────────────────────────┬───────────────────────┘
                                         │ Stimulus connects
                                         ▼
        ┌────────────────────────────────────────────────────────────┐
        │  toc_controller.js                                         │
        │                                                            │
        │  connect()                                                 │
        │    ├─▶ collect links → resolve headings (getElementById)   │
        │    ├─▶ D-04: read location.hash ──▶ markActive() (sync)    │
        │    ├─▶ new IntersectionObserver(rootMargin band) ─┐        │
        │    ├─▶ window.addEventListener('scroll', …)  ─────┤        │
        │    └─▶ matchMedia('(prefers-reduced-motion)')     │        │
        │                                                   │        │
        │  ┌──── click (CAPTURE phase, on wrapper) ────┐    │        │
        │  │ navigate(event)                           │    │        │
        │  │  ├─ stopPropagation()  ◀── blocks legacy  │    │        │
        │  │  │                        inline handler  │    │        │
        │  │  │                        AND Turbo       │    │        │
        │  │  ├─ preventDefault()                      │    │        │
        │  │  ├─ markActive(heading)                   │    │        │
        │  │  ├─ closeDisclosure()      (D-09)         │    │        │
        │  │  ├─ focusHeading(preventScroll:true)      │    │        │
        │  │  └─ scrollIntoView({behavior: reduced ?   │    │        │
        │  │        'auto' : 'smooth', block:'start'}) │    │        │
        │  └───────────────────────────────────────────┘    │        │
        │                                                   ▼        │
        │  ┌──── IO callback / scroll ────────────────────────────┐  │
        │  │ recomputeActive()                                    │  │
        │  │  ├─ atBottom()? ──yes──▶ last heading      (D-03)    │  │
        │  │  ├─ any intersecting? ──▶ LAST one in doc order      │  │
        │  │  └─ none? ──────────────▶ headings[0]      (D-02)    │  │
        │  │        └─▶ markActive(): swap aria-current="location"│  │
        │  │              └─▶ keepEntryVisible()        (INTX-03) │  │
        │  └──────────────────────────────────────────────────────┘  │
        │                                                            │
        │  keydown.esc (on <details>) ─▶ close + focus <summary>     │
        │  disconnect() / teardown() ─▶ io.disconnect(),             │
        │                               removeEventListener          │
        └────────────────────────────────────────────────────────────┘
```

### Recommended Project Structure

```
app/javascript/controllers/
├── toc_controller.js              # NEW — scroll-spy + click-to-jump + disclosure
└── index.js                       # regenerate: bin/rails stimulus:manifest:update

app/views/blogs/
├── show.html.erb                  # add data-controller wrapper + render disclosure
├── _toc_sidebar.html.erb          # add data-toc-target, data-action wiring
└── _toc_disclosure.html.erb       # NEW — mobile <details>/<summary>

spec/system/
└── blogs/
    ├── toc_scroll_spy_spec.rb     # INTX-02, INTX-03
    ├── toc_navigation_spec.rb     # INTX-01, A11Y-02
    └── toc_disclosure_spec.rb     # LAYOUT-02, A11Y-03

spec/support/
└── system.rb                      # NEW (optional) — shared driven_by config
```

**On one controller vs two (Claude's discretion in CONTEXT.md):** recommend **one** `toc_controller`. The disclosure's auto-close (D-09) is triggered by the same click handler that does the scroll/focus, and Escape-close (D-11) shares the same element scope. Splitting forces cross-controller coordination for zero benefit.

### Pattern 1: IntersectionObserver near-top band (D-01)

**What:** A single observer whose root box is extended far *above* the viewport and cropped to end at the trigger line. A heading "intersects" precisely when its top has already crossed that line. Active entry = the **last** intersecting heading in document order.

**Why not a thin band:** `rootMargin: "-25% 0px -75% 0px"` produces a root box only **1px tall** at this viewport (measured: `rootTop: 64, rootBottom: 65`). Headings can scroll straight through it between frames, leaving nothing active. The extended-above form is monotonic and cannot skip.

**Verified arithmetic** (Chrome 151, viewport 1600×257):

| `rootMargin` | Measured `rootBounds` | Interpretation |
|---|---|---|
| `"0px 0px -50% 0px"` | top 0, bottom 129, height 129 | 129 ≈ 257 × 0.5 → **percentages resolve against viewport HEIGHT** |
| `"-25% 0px 0px 0px"` | top 64, height 193 | 64 ≈ 257 × 0.25 → height again |
| `"-25% 0px -75% 0px"` | top 64, bottom 65 | 1px band — fragile |
| `"9999px 0px -75% 0px"` | top −9999, bottom 65 | Extended above, trigger line at 25% of viewport height ✅ |

```javascript
// Source: measured in Chrome 151 headless against this repo (2026-08-08)
const TRIGGER_PCT = 25 // D-01: top 20-25% band. Tunable.

this.observer = new IntersectionObserver(
  (entries) => {
    entries.forEach((e) =>
      e.isIntersecting ? this.passed.add(e.target) : this.passed.delete(e.target)
    )
    this.recomputeActive()
  },
  {
    // Extend the root far above the viewport so any heading already scrolled
    // past still counts as intersecting; crop the bottom so the effective
    // trigger line sits TRIGGER_PCT down from the top of the viewport.
    rootMargin: `${Math.max(document.documentElement.scrollHeight, 10000)}px 0px -${100 - TRIGGER_PCT}% 0px`,
    threshold: 0,
  }
)
this.headings.forEach((h) => this.observer.observe(h))
```

### Pattern 2: Active-entry resolution with top and bottom special cases (D-02, D-03)

```javascript
atBottom() {
  const doc = document.documentElement
  // 2px tolerance: scrollY is fractional under devicePixelRatio/zoom.
  return Math.ceil(window.scrollY + window.innerHeight) >= doc.scrollHeight - 2
}

recomputeActive() {
  if (this.atBottom()) {
    return this.markActive(this.headings[this.headings.length - 1]) // D-03
  }
  const passed = this.headings.filter((h) => this.passed.has(h))
  this.markActive(passed.length ? passed[passed.length - 1] : this.headings[0]) // D-02
}

markActive(heading) {
  if (heading === this.activeHeading) return   // idempotent: avoid DOM churn per frame
  this.activeHeading = heading
  const index = this.headings.indexOf(heading)
  this.linkTargets.forEach((a) => a.removeAttribute("aria-current"))
  if (index >= 0) {
    this.linkTargets[index].setAttribute("aria-current", "location")
    this.keepEntryVisible(this.linkTargets[index])   // INTX-03
  }
}
```

**`atBottom()` needs a scroll listener, not just the observer.** The IO callback only fires when a heading crosses the trigger line. Scrolling the last 200px of a page fires nothing. Attach a passive `scroll` listener that calls `recomputeActive()` (the `markActive` early-return keeps it cheap):

```javascript
this.onScroll = () => this.recomputeActive()
window.addEventListener("scroll", this.onScroll, { passive: true })
```

**D-03 is empirically necessary, not defensive.** Measured on a page whose final section is 40px tall: at maximum scroll the observer reported only 3 of 4 headings as passed — the last heading's top never reached the 25% line, so without the `atBottom()` override the TOC would have stayed stuck on the second-to-last entry.

**D-04 (deep link), synchronously in `connect()`:**

```javascript
const hash = window.location.hash.slice(1)
const target = hash && this.headings.find((h) => h.id === decodeURIComponent(hash))
this.markActive(target || this.headings[0])
```

**End-to-end verification** — this exact algorithm executed against a real rendered blog post (6 headings, last one deliberately short, viewport 1400×1000):

```
TOP (scrollY=0)          -> toc-heading-1            aria-current="location"
scrollY=800              -> toc-heading-1
scrollY=1600             -> toc-heading-1
scrollY=3000             -> toc-heading-2
scrollY=5000             -> toc-heading-3
BOTTOM (scrollY=11118)   -> toc-heading-6-short-tail
DEEP LINK #toc-heading-4 -> toc-heading-4  (sync, and unchanged after observer settles)
                            heading top: 32px  ← scroll-mt-8 honored
```

### Pattern 3: Click-to-jump with focus (INTX-01, A11Y-02, D-10, D-14)

**Wiring — the capture phase is mandatory (see Pitfall 1):**

```erb
<%# On the WRAPPER element that contains both the sidebar and the disclosure. %>
<%# NOT on the individual <a> — capture at the target element is the target %>
<%# phase and runs in registration order, which the legacy handler wins.     %>
<div data-controller="toc"
     data-action="click->toc#navigate:capture">
```

```javascript
navigate(event) {
  const link = event.target.closest('a[href^="#"]')
  if (!link || !this.element.contains(link)) return

  const id = decodeURIComponent(link.hash.slice(1))
  const heading = document.getElementById(id)   // NOT querySelector("#" + id) — see Security Domain
  if (!heading) return

  event.stopPropagation()   // suppresses the legacy inline handler AND Turbo's LinkClickObserver
  event.preventDefault()

  this.markActive(heading)
  this.closeDisclosure()                        // D-09; no-op on desktop

  this.focusHeading(heading)
  heading.scrollIntoView({ behavior: this.scrollBehavior, block: "start" })

  // Keep the URL shareable without triggering another scroll.
  history.replaceState(history.state, "", `#${link.hash.slice(1)}`)
}

get scrollBehavior() {
  return window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth"
}
```

**`focusHeading` — copy Turbo's own transient-tabindex pattern.** Headings are not focusable by default (measured: `h.focus()` on a bare `<h2>` leaves `document.activeElement` unchanged). Turbo 8.0.18 solves this in `View#focusElement` by adding, focusing, and removing `tabindex`:

```javascript
// Source: node_modules/@hotwired/turbo/dist/turbo.es2017-esm.js, View#focusElement
focusHeading(heading) {
  if (heading.hasAttribute("tabindex")) {
    heading.focus({ preventScroll: true })
  } else {
    heading.setAttribute("tabindex", "-1")
    heading.focus({ preventScroll: true })
    heading.removeAttribute("tabindex")
  }
}
```

`preventScroll: true` is verified supported (window stayed at `scrollY: 0` after `focus({preventScroll:true})`) and is required so the focus call does not jump the page instantly, cancelling the smooth scroll.

**Alternative worth knowing:** if headings carried a permanent server-rendered `tabindex="-1"`, Turbo's *own* same-page anchor handling would already focus + scroll them (verified in Turbo source: `Visit`/`View.scrollToAnchor` → `focusElement` + `scrollToElement`). That still would not give smooth scroll or reduced-motion gating, so the Stimulus handler is still required — but it means a permanent `tabindex="-1"` is a legitimate simplification if the transient approach causes trouble.

### Pattern 4: Mobile `<details>` disclosure (LAYOUT-02, A11Y-03, D-05..D-08)

```erb
<%# app/views/blogs/_toc_disclosure.html.erb %>
<details class="lg:hidden group mb-8 rounded-md border border-gray-200"
         data-toc-target="disclosure"
         data-action="keydown.esc->toc#closeDisclosureAndRestoreFocus">
  <summary class="cursor-pointer list-none px-4 py-3 text-sm font-semibold
                  text-gray-900 flex items-center justify-between
                  focus-visible:ring-2 focus-visible:ring-pink-600"
           data-toc-target="summary">
    Contents
    <svg class="size-4 transition-transform group-open:rotate-180 motion-reduce:transition-none"
         aria-hidden="true" ...></svg>
  </summary>

  <nav aria-label="Table of contents" class="px-4 pb-4">
    <ol role="list" class="list-none space-y-2 pl-0">
      <% entries.each do |entry| %>
        <li class="<%= 'pl-4' if entry.level == 3 %>">
          <%= link_to "##{entry.anchor}", data: { toc_target: "link" }, class: "..." do %>
            <%= sanitize(entry.label_html, tags: %w[strong em code], attributes: []) %>
          <% end %>
        </li>
      <% end %>
    </ol>
  </nav>
</details>
```

**Verified `<details>` facts (Chrome 151, accessibility tree dumped via CDP `Accessibility.getPartialAXTree`):**

| Check | Result |
|---|---|
| `<summary>` AX role | `DisclosureTriangle`, accessible name `"Contents"` |
| AX properties when closed | `{ focusable: true, expanded: false }` |
| AX properties when open | `{ focusable: true, focused: true, expanded: true }` |
| Literal `aria-expanded` attribute | `null` — **not present, and not needed** |
| Enter key on focused `<summary>` | toggles `open` ✅ native |
| **Real Escape key on focused `<summary>`** | **does NOT close** — JS assist required |
| Tab from `<summary>` while closed | goes to `BODY`, i.e. skips the hidden links ✅ |
| `toggle` event `bubbles` | **`false`** — `data-action` must be on `<details>` itself |
| Stimulus default event for `<details>` | `toggle` (from `defaultEventNames` in stimulus.js) |

**D-06 is confirmed correct.** The `expanded` state in the accessibility tree tracks the `open` attribute automatically. Adding a literal `aria-expanded` would be redundant; adding `role="button"` would be actively harmful (Scott O'Hara: macOS Safari drops the expanded-state announcement).

**Do not remove the disclosure triangle marker without providing a replacement indicator.** Firefox + VoiceOver relies on the triangle direction to convey state; `list-style: none` on `<summary>` plus a rotating chevron (as above) is the safe substitution. [CITED: scottohara.me/blog/2022/09/12/details-summary.html]

### Pattern 5: Disclosure control from the controller (D-09, D-11)

```javascript
closeDisclosure() {
  if (this.hasDisclosureTarget) this.disclosureTarget.open = false   // D-09
}

closeDisclosureAndRestoreFocus(event) {
  if (!this.hasDisclosureTarget || !this.disclosureTarget.open) return
  event.preventDefault()
  this.disclosureTarget.open = false
  this.summaryTarget.focus()                                        // D-11
}
```

`keydown.esc` is a valid Stimulus key filter — `esc: "Escape"` is in Stimulus 3.2.2's default `keyMappings`. [VERIFIED: node_modules/@hotwired/stimulus/dist/stimulus.js]

Note D-10 and D-11 differ deliberately: selecting an entry sends focus to the heading (`navigate` calls `closeDisclosure`, which does **not** touch focus); Escape sends focus back to `<summary>`.

### Pattern 6: Keep the active entry visible in the sidebar (INTX-03)

```javascript
keepEntryVisible(link) {
  const container = this.sidebarScrollerTarget   // the div with lg:overflow-y-auto
  if (container.scrollHeight <= container.clientHeight) return  // not overflowing; nothing to do
  link.scrollIntoView({ block: "nearest" })
}
```

**Measured on a 24-heading post at viewport 1400×900** (sidebar `clientHeight: 693`, `scrollHeight: 796`, overflowing):

| Approach | `window.scrollY` before → after | container `scrollTop` before → after |
|---|---|---|
| `link.scrollIntoView({block:'nearest'})` | 4000 → **4000** | 0 → 7 |
| Manual `container.scrollTop` arithmetic | 4000 → **4000** | 0 → 7 |

Identical, and neither moved the page. `block: 'nearest'` is safe **because the sidebar is `position: sticky` and therefore always within the viewport**. If that ever changes, fall back to explicit arithmetic:

```javascript
const cr = container.getBoundingClientRect(), lr = link.getBoundingClientRect()
if (lr.top < cr.top)         container.scrollTop -= (cr.top - lr.top)
else if (lr.bottom > cr.bottom) container.scrollTop += (lr.bottom - cr.bottom)
```

Do **not** pass `behavior: 'smooth'` here — it competes with the page's own smooth scroll during click-to-jump.

### Pattern 7: Teardown (success criterion #5)

```javascript
disconnect() {
  this.teardown()
}

// This project already dispatches teardown() on turbo:before-cache
// (app/javascript/application.js). Implement both; make teardown idempotent.
teardown() {
  this.observer?.disconnect()
  this.observer = null
  if (this.onScroll) window.removeEventListener("scroll", this.onScroll)
  this.onScroll = null
  this.passed?.clear()
  this.activeHeading = null
}
```

Stimulus fires `disconnect()` when Turbo installs a new `<body>`; a controller may reconnect later and `connect()` runs again, so `connect()` must be safe to run repeatedly. [CITED: stimulus.hotwired.dev/reference/lifecycle-callbacks]

### Anti-Patterns to Avoid

- **Setting `scroll-behavior: smooth` on `html` or `body`.** Explicitly forbidden by success criterion #5, and it would make the `prefers-reduced-motion` gate meaningless. Verified currently `auto` in the test env — assert it in a spec so a regression is caught.
- **Binding TOC clicks on the `<a>` elements.** Loses the ordering race with the legacy handler (see Pitfall 1). Bind on an ancestor in the capture phase.
- **`querySelector("#" + id)` to resolve the target heading.** Anchor IDs are `toc-`-prefixed `parameterize` output today, but a positional-fallback anchor or a future change could produce a value that is a valid `id` and an invalid CSS selector, throwing `SyntaxError`. Use `document.getElementById`.
- **Recomputing `rootMargin` on every resize by tearing down and rebuilding the observer.** Percentages in `rootMargin` are evaluated live against the current root box; only the giant top margin is a fixed pixel value, and `Math.max(scrollHeight, 10000)` is already generous.
- **Duplicating anchor derivation in JS.** Phase 1 owns anchor generation server-side; the controller must read `link.hash` / `heading.id` from the DOM.
- **Assuming `heading.textContent` is the heading text.** Phase 2's INTX-04 permalink injects a literal `#` inside every heading. Measured: `document.getElementById('toc-section-2').textContent === "Section 2#"`. Match on `id`, not text.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Scroll-position tracking | Throttled/rAF scroll loop reading `getBoundingClientRect()` for every heading | `IntersectionObserver` | Off-main-thread intersection computation; no layout thrash; required by INTX-02's own wording |
| Disclosure open/closed state + ARIA | `<button aria-expanded>` + `hidden` panel + keyboard handlers | `<details>`/`<summary>` | Verified to give focusability, Enter toggle, `expanded` AX state, and content inertness with zero JS |
| Heading focusability | Permanent `tabindex="-1"` on every heading server-side | Turbo's transient add-focus-remove pattern | Avoids polluting the tab order and the a11y tree; battle-tested in Turbo itself |
| Scroll offset under the header | JS `window.scrollBy(0, -offset)` after jumping | `scroll-margin-top` (already `prose-headings:scroll-mt-8` from Phase 2) | Verified honored by both `scrollIntoView` and native fragment navigation (heading lands at `top: 32px`) |
| Sidebar containment scrolling | Manual `scrollTop` math | `scrollIntoView({block:'nearest'})` | Measured identical result, no page movement, one line |
| chromedriver management | `webdrivers` gem, vendored binary, or a download step | Selenium Manager (bundled in selenium-webdriver 4.36.0) | Verified resolving Chrome 151 + matching driver from cache with no configuration |
| Capybara driver registration | Custom `Capybara.register_driver` block | `driven_by :selenium, using: :headless_chrome, screen_size: [...]` | Rails' own path; additionally sets a deterministic window size that Capybara's built-in driver does not |
| Reduced-motion in tests | Hoping the CI machine has the OS setting | CDP `Emulation.setEmulatedMedia` | Verified working through Capybara (see Code Examples) |

**Key insight:** almost every "hard" part of this phase already has a correct implementation shipping inside Turbo, Rails, or the browser. The genuinely novel code is small: the `rootMargin` band, the `atBottom()` override, and the capture-phase click ownership.

## Runtime State Inventory

Not applicable — this is a feature/behavior phase, not a rename, refactor, or migration. No stored data, live service config, OS-registered state, secrets, or build artifacts encode any string this phase changes.

One adjacent item is worth stating explicitly because it bit this research:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Build artifacts | `app/assets/builds/application.css` and `application.js` are **gitignored** and were **stale** in this working tree — Phase 2's `prose-headings:scroll-mt-8`, `lg:sticky`, `lg:overflow-y-auto`, `lg:max-h-[...]` were all absent from the compiled CSS, so the test environment rendered them as no-ops | Run `npm run build && npm run build:css` before any layout/scroll system spec. **Already done during this research session** (gitignored files only; `git status` is clean). CI already does this before `rspec` |

## Common Pitfalls

### Pitfall 1: The legacy inline handler wins the click, and the obvious fixes don't stop it (D-14)

**What goes wrong:** `app/views/shared/_navigation.html.erb` binds a `click` listener to **every** `a[href*="#"]` on the page at `DOMContentLoaded`, calls `preventDefault()`, and smooth-scrolls with no reduced-motion check and no focus move. It is rendered on the blog show page. [VERIFIED: `page.html.include?("Smooth scroll for anchor links") == true` on `/blog/:slug`]

**Why it happens:** the inline `<script>` lives in the body and registers its `DOMContentLoaded` callback *during parsing*. `application.js` is an ES module (esbuild `--format=esm`), so it is deferred and executes after parsing — Stimulus's binding therefore lands **after** the legacy handler's. On a shared target element, listeners fire in registration order, so the legacy handler is always first.

**Measured behaviour on a real first page load:**
```
hash after clicking a TOC entry: ""      ← legacy preventDefault() ran
activeElement after click:       BODY    ← no focus moved (A11Y-02 unmet)
```
And after a Turbo Drive navigation to a second post:
```
hash after clicking a TOC entry: "#toc-section-3"   ← legacy handler NOT bound; native jump
```
So the behaviour is *also inconsistent between a cold load and a Turbo-navigated load* — exactly as D-14 predicted.

**Verified fix.** Five strategies were measured against a faithful replica of the legacy handler plus a stand-in for Turbo's document-level listener. Order of the log shows who ran:

| Strategy | Result |
|---|---|
| Stimulus action on the `<a>` (target phase) | `["LEGACY", "STIMULUS"]` ❌ double scroll |
| Delegated on ancestor, bubble phase | `["LEGACY", "STIMULUS"]` ❌ double scroll |
| Delegated on ancestor, **capture** + `preventDefault()` only | `["STIMULUS", "LEGACY"]` ❌ legacy ignores `defaultPrevented` |
| **Delegated on ancestor, capture + `stopPropagation()` + `preventDefault()`** | **`["STIMULUS"]`** ✅ |
| `stopImmediatePropagation()` on the `<a>` | `["LEGACY", "STIMULUS"]` ❌ too late |

`stopPropagation()` during the **capture** phase at an ancestor prevents the event from ever reaching the target's own listeners. This is the only option that needs no edit to `_navigation.html.erb`.

**It also correctly suppresses Turbo.** Turbo's `LinkClickObserver.clickBubbled` is a document-level bubble listener guarded by `clickEventIsSignificant`, which returns false when `event.defaultPrevented`. [VERIFIED: turbo.es2017-esm.js source] Capture-phase `stopPropagation()` means it never even receives the event.

**How to avoid:** `data-action="click->toc#navigate:capture"` on the `data-controller="toc"` wrapper, with `event.stopPropagation()` as the first statement after the link is resolved. Guard with `event.target.closest('a[href^="#"]')` so non-link clicks inside the wrapper pass through untouched.

**Warning signs:** clicking a TOC entry visibly scrolls twice, or scrolls smoothly even with reduced-motion enabled, or the URL hash stops updating.

**Optional cleanup (recommend proposing, not silently doing):** the legacy handler is broken independently of this phase — it never rebinds after Turbo navigation, so the Phase 2 `.toc-permalink` links inside headings also stop working on Turbo-navigated posts. A one-line selector change (`a[href*="#"]:not([data-toc-link])`) or a move to `turbo:load` would fix that class of bug, but it is out of this phase's requirement set. Flag it rather than expanding scope.

### Pitfall 2: `rootMargin` percentages — spec says width, browsers use height

**What goes wrong:** the Intersection Observer spec states *"Percentages are resolved relative to the width of the undilated rectangle."* Taken literally, `-75%` on the bottom edge of a 1600×257 viewport would subtract 1200px and produce a negative-height root box.

**Why it happens:** it is a known spec/implementation divergence — [w3c/IntersectionObserver#391]. Browsers resolve top/bottom against **height**.

**How to avoid:** trust the measured behaviour (height), and write a system spec that asserts the active entry at known scroll offsets rather than asserting a `rootMargin` string. Measured: `"0px 0px -50% 0px"` on a 257px-tall viewport produced `rootBounds.height === 129`.

**Related, fully verified constraint:** `rootMargin` accepts **only `px` and `%`**. All of `em`, `rem`, `vh`, and bare unitless `0` throw `SyntaxError` at construction time. The spec's parse algorithm agrees: *"If token is an absolute length dimension token... If token is a `<percentage>` token... Otherwise, return failure."* Do not write `rootMargin: "-10px 0"`.

### Pitfall 3: Stale asset build makes the test environment lie about CSS

**What goes wrong:** in this working tree, before rebuilding, a system spec against `/blog/:slug` reported:
```
h2 computed scrollMarginTop:  0px      (expected 32px)
sidebar computed position:    static   (expected sticky)
sidebar computed overflowY:   visible  (expected auto)
sidebar maxHeight:            none     (expected calc(100vh-4rem))
```
After `npm run build:css`, all four were correct (`32px` / `sticky` / `auto` / `1193px`).

**Why it happens:** `app/assets/builds/*` is gitignored (`.gitignore:36`). Propshaft serves whatever is on disk. Phase 2 was manually QA'd against `bin/dev`, which runs a Tailwind watcher — so nobody noticed the committed-state build was behind.

**How to avoid:** treat `npm run build && npm run build:css` as a precondition of running system specs locally, and say so in the spec file header or a `bin/` helper. CI is already correct (`Build assets` step precedes `bundle exec rspec`).

**Warning signs:** a system spec asserting the mobile disclosure is hidden at desktop widths, or that a heading lands 32px from the top, fails locally but passes in CI (or vice-versa).

### Pitfall 4: Capybara's built-in `:selenium_chrome_headless` has no deterministic window size

**What goes wrong:** scroll-spy assertions depend on viewport height (the trigger line is a percentage of it). Capybara 3.40's built-in `:selenium_chrome_headless` registration adds only `--headless=new` and `--disable-site-isolation-trials` — no `--window-size` — so you inherit headless Chrome's 800×600 default. [VERIFIED: capybara/lib/capybara/registrations/drivers.rb]

Rails' `ActionDispatch::SystemTesting::Driver#registerable?` only covers `[:selenium, :cuprite, :rack_test, :playwright]`, so passing `driven_by :selenium_chrome_headless` falls through to Capybara's registration and the `screen_size:` option is silently ignored.

**How to avoid:** use `driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1000]`. That path goes through `register_selenium`, which calls `driver.browser.manage.window.size = ...`.

**Measured caveat:** `screen_size` is the **window** size, not the viewport. At `screen_size: [1400, 1400]` the measured viewport was `1400 × 1257` (≈143px of browser chrome). Assert against `window.innerHeight` read at runtime, never against the `screen_size` literal.

### Pitfall 5: `focus()` scrolls, cancelling your smooth scroll

**What goes wrong:** calling `heading.focus()` triggers the browser's "scroll an element into view" algorithm instantly, so the smooth animation you started is immediately overridden by a jump.

**How to avoid:** `heading.focus({ preventScroll: true })` **before** `scrollIntoView`. Verified: after `scrollTo(0,0)` then `focus({preventScroll:true})`, `window.scrollY` remained `0`.

**Also:** a bare `<h2>` cannot receive focus at all. Verified: `focus()` with no `tabindex` left `document.activeElement` unchanged; with `tabindex="-1"` it became the `H2`.

### Pitfall 6: `toggle` does not bubble

**What goes wrong:** `data-action="toggle->toc#disclosureToggled"` placed on a wrapper `<div>` silently never fires.

**Why:** measured `event.bubbles === false` on the `<details>` `toggle` event; a listener on `document.body` never fired.

**How to avoid:** put the `data-action` on the `<details>` element itself. Bonus: Stimulus's `defaultEventNames` maps `details → toggle`, so `data-action="toc#disclosureToggled"` (no event prefix) works on a `<details>`.

### Pitfall 7: `aria-current` churn on every scroll frame

**What goes wrong:** naively calling `markActive()` from both the IO callback and a `scroll` listener rewrites attributes on every frame. `aria-current` is not a live region so nothing is announced, but the DOM writes and the `keepEntryVisible()` call are wasted work.

**How to avoid:** early-return in `markActive()` when the heading is unchanged (shown in Pattern 2). Use a `passive: true` scroll listener.

**Token choice:** use `aria-current="location"` — *"Represents the current location within an environment or context."* `page` is defined as *"the current page within a set of pages"*, which is wrong for same-page anchors. MDN is explicit that only one element in a set should carry `aria-current`. [CITED: MDN aria-current]

### Pitfall 8: `spec/system/*_spec.rb` will not be typed automatically

**What goes wrong:** the spec runs as a plain example group with no Capybara DSL, failing on `visit` with `NoMethodError`.

**Why:** rspec-rails binds via `config.include RSpec::Rails::SystemExampleGroup, type: :system`, and this project has `config.infer_spec_type_from_file_location!` **commented out** in `spec/rails_helper.rb`. Every existing spec declares its type explicitly (`RSpec.describe "...", type: :request`).

**How to avoid:** `RSpec.describe "...", type: :system do`. Match the existing convention; do **not** enable `infer_spec_type_from_file_location!` as a side-effect of this phase — it would retroactively change the type of every existing spec and is a separate decision.

### Pitfall 9: CI uploads failure screenshots from the wrong directory

**What goes wrong:** `.github/workflows/ci.yml` uploads `${{ github.workspace }}/tmp/screenshots` on failure, but the observed failure screenshot path in this repo is `tmp/capybara/failures_....png`.

**How to avoid:** either change the CI artifact path to `tmp/capybara`, or set `Capybara.save_path = Rails.root.join("tmp/screenshots")`. Low-cost, high-value once system specs exist — a failing system spec in CI is otherwise undebuggable. (`if-no-files-found: ignore` means it currently fails silently.)

## Code Examples

### System spec skeleton (verified working end-to-end in this repo)

```ruby
# spec/system/blogs/toc_navigation_spec.rb
require "rails_helper"

RSpec.describe "Blog TOC navigation", type: :system do   # explicit type — Pitfall 8
  before { driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1000] }

  let(:body) do
    (1..6).map { |i| "<h2>Heading #{i}</h2>" + ("<p>filler #{i}</p>" * 35) }.join
  end
  let(:blog) { create(:blog, title: "Algo Post", slug: "algo-post", body: body, toc_enabled: true) }

  it "smooth-scrolls, offsets under the header, and moves focus" do
    visit "/blog/#{blog.slug}"

    find('nav[aria-label="Table of contents"] a', text: "Heading 4").click

    expect(page).to have_css('nav[aria-label="Table of contents"] a[aria-current="location"]',
                             text: "Heading 4")
    expect(
      page.evaluate_script("Math.round(document.getElementById('toc-heading-4').getBoundingClientRect().top)")
    ).to eq(32)                                     # scroll-mt-8 honored
    expect(page.evaluate_script("document.activeElement.id")).to eq("toc-heading-4")
  end

  it "never enables page-level smooth scrolling" do  # success criterion #5
    visit "/blog/#{blog.slug}"
    expect(
      page.evaluate_script("getComputedStyle(document.documentElement).scrollBehavior")
    ).to eq("auto")
  end
end
```

**Verified facts behind this skeleton:**
- `create(:blog, ...)` data **is** visible to the browser under the existing `use_transactional_fixtures = true` + DatabaseCleaner `:transaction` config. A probe spec asserting `have_content("Probe Post")` passed. **No DatabaseCleaner change is required** — this resolves the largest unknown in D-12/D-13.
- The browser booted with zero additional configuration; Selenium Manager resolved chromedriver silently.
- `IntersectionObserver` is available (`'IntersectionObserver' in window === true`).
- Blog anchors render as `toc-heading-1`, `toc-heading-2`, ... via Phase 1's `parameterize`.

### Emulating `prefers-reduced-motion` in a system spec (verified)

```ruby
it "jumps instantly when the reader prefers reduced motion" do
  visit "/blog/#{blog.slug}"

  page.driver.browser.execute_cdp(
    "Emulation.setEmulatedMedia",
    features: [{ name: "prefers-reduced-motion", value: "reduce" }]
  )
  expect(page.evaluate_script("matchMedia('(prefers-reduced-motion: reduce)').matches")).to be(true)

  # ... assert the jump completes within a single frame ...
end
```

`execute_cdp` is provided by `Selenium::WebDriver::DriverExtensions::HasCDP` and is reachable as `page.driver.browser.execute_cdp`. [VERIFIED: selenium-webdriver 4.36.0 source + live execution through Capybara]. The emulation **persists across `visit` calls** within the same session — set it before navigating, or reset it explicitly.

### Mobile-width testing

```ruby
before do
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1000]
end

it "shows the Contents disclosure at mobile widths" do
  page.driver.browser.manage.window.resize_to(390, 844)
  visit "/blog/#{blog.slug}"

  expect(page).to have_css("details summary", text: "Contents")
  expect(page).to have_no_css('div.hidden.lg\\:block nav[aria-label="Table of contents"]', visible: true)
end
```

Because `lg:hidden` / `hidden lg:block` are pure CSS, this test is one of the ones that will silently fail on a stale asset build (Pitfall 3).

### Registering the controller

```bash
bin/rails stimulus:manifest:update   # regenerates app/javascript/controllers/index.js
npm run build                        # esbuild — required, index.js is bundled
```

`stimulus:manifest:update` is available (stimulus-rails is in the Gemfile). `index.js` is auto-generated; do not hand-edit it.

### Tailwind v4 variants (all compile-verified against tailwindcss 4.1.14)

| Class | Generated selector |
|---|---|
| `aria-[current=location]:text-pink-600` | `&[aria-current="location"]` |
| `aria-[current]:font-semibold` | `&[aria-current]` |
| `open:rotate-180` | `&:is([open], :popover-open, :open)` |
| `group-open:rotate-180` | `:is(:where(.group):is([open], …) *)` |
| `motion-reduce:transition-none` | `@media (prefers-reduced-motion: reduce)` |

Compiled with the project's own CLI and grepped from the output. Use `aria-[current]:` (attribute-presence) rather than `aria-[current=location]:` unless you want the styling coupled to the exact token.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `webdrivers` gem to download/pin chromedriver | Selenium Manager, bundled in selenium-webdriver | Selenium 4.6+ (2022); `webdrivers` deprecated | Nothing to add to the Gemfile; verified resolving Chrome 151 automatically |
| `--headless` (old headless Chrome) | `--headless=new` | Chrome 109+; Capybara 3.40 already emits it | Real rendering/layout in headless, so IntersectionObserver behaves like headed Chrome |
| rspec-rails system specs defaulting to `:selenium` (headed Chrome) | `DEFAULT_DRIVER = :selenium_chrome_headless` when Rails ≥ 7.2 | rspec-rails 6.1+/7.x | On this Rails 8 app, forgetting `driven_by` still yields a headless browser (but with a non-deterministic window size — see Pitfall 4) |
| `rootMargin` only | `rootMargin` **and** `scrollMargin` | IntersectionObserver v2 addition, Chrome 128+ | `scrollMargin` handles clipping by intermediate scroll containers. Not needed here (the intersection root is the viewport), but relevant if the sidebar ever becomes the root |
| Thin-band `rootMargin: "-25% 0 -75% 0"` scroll-spy | Extended-above root + "last intersecting wins" | Community consensus; the thin band produces a ~1px root box | Measured: the thin band leaves the TOC unhighlighted between frames on fast scrolls |

**Deprecated/outdated:**
- `webdrivers` gem — do not add.
- `document.body.scrollTop` for page scroll — use `window.scrollY` / `document.documentElement.scrollTop`.
- `element.scrollIntoViewIfNeeded()` — non-standard WebKit API; `scrollIntoView({block:'nearest'})` is the standard equivalent and is what Pattern 6 measured.

## Project Constraints (from CLAUDE.md)

| Directive | How this phase complies |
|-----------|-------------------------|
| **Rails/Stimulus/esbuild only — no React/Vue for TOC/scroll-spy behavior** | One vanilla Stimulus controller; zero new runtime dependencies |
| **TOC strictly opt-in; existing posts render identically until enabled** | All new markup and `data-*` wiring sits inside the existing `if article.toc?` branch in `show.html.erb`. TOC-off posts get no `data-controller`, no disclosure, no behavior change |
| **No new editor storage format; TOC reads existing sanitized `body`** | The controller reads anchor IDs from the rendered DOM. No schema change, no new server-side data |
| **Scope discipline — gem extraction and multi-page posts are parked** | Not touched. The legacy-handler cleanup is *flagged*, not expanded into |
| **GSD workflow enforcement — no direct repo edits outside a GSD command** | This research made no tracked-file edits. `git status` is clean. Only gitignored build artifacts were regenerated (see Runtime State Inventory) |
| **Stimulus naming: kebab-case `data-controller`, one file per controller in `app/javascript/controllers/`** | `data-controller="toc"` → `app/javascript/controllers/toc_controller.js` |
| **No global JS state on `window` for Stimulus controllers** | All state lives on the controller instance (`this.observer`, `this.passed`, `this.activeHeading`) |
| **Private-ish helper methods below public actions (per `cookie_consent_controller.js`)** | Pattern: `connect`/`disconnect`/`navigate`/`closeDisclosure*` first, then `recomputeActive`/`markActive`/`atBottom`/`focusHeading`/`keepEntryVisible` |
| **`teardown()` convention consumed by `turbo:before-cache` in `application.js`** | Implement `teardown()`, call it from `disconnect()`, keep it idempotent |
| **Rubocop rails-omakase; Brakeman in CI** | Ruby changes are ERB + specs only; no new Brakeman surface |

## Security Domain

This phase adds no authentication, no persistence, no new user input, and no new server-side rendering of user data. ASVS categories are mostly N/A; the two that apply are recorded honestly.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | No auth surface touched |
| V3 Session Management | no | No session interaction |
| V4 Access Control | no | Public blog page; no authorization decision |
| V5 Input Validation / Output Encoding | **yes** | Heading text and TOC labels are already sanitized server-side (`Blog::TableOfContents::LABEL_TAGS`, view-level `sanitize`). This phase must not introduce a client-side `innerHTML` path |
| V6 Cryptography | no | None |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| DOM XSS via `innerHTML` when rendering TOC labels client-side | Tampering | **Do not render TOC entries in JS at all.** Entries are server-rendered by Phase 2; the controller only toggles attributes (`aria-current`) and calls scroll/focus APIs. No `innerHTML`, no `insertAdjacentHTML` |
| CSS selector injection / `SyntaxError` from `querySelector("#" + id)` | Tampering / DoS | Use `document.getElementById(decodeURIComponent(link.hash.slice(1)))`. Never interpolate an id into a selector string. If a selector is unavoidable, `CSS.escape(id)` |
| Open-redirect-style abuse of `history.replaceState` | Tampering | Only ever write a fragment derived from an anchor already present in the server-rendered TOC — never from raw `location.hash` |
| Widening the sanitizer allowlist to make the disclosure work | Tampering | Not required. The `<details>` markup is app-authored ERB, entirely outside the sanitized `body` string. `Blog::ALLOWED_TAGS` / `ALLOWED_ATTRIBUTES` must stay untouched (project-wide rule from Phase 1) |
| CDP `execute_cdp` reachable outside tests | Elevation of Privilege | Confined to `spec/system/`; no production code path. Do not add a CDP helper to `app/` |

Brakeman coverage is unaffected — no new Ruby beyond ERB view markup and specs.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Google Chrome (local) | System specs | ✓ | 151.0.7922.108 | — |
| chromedriver | Selenium session | ✓ (auto) | 151.0.7922.77, resolved+cached by Selenium Manager | — |
| `capybara` gem | System-spec DSL | ✓ | 3.40.0 | — |
| `selenium-webdriver` gem | Browser driver | ✓ | 4.36.0 | — |
| `rspec-rails` `type: :system` | Example group | ✓ | 7.1.1 | — |
| PostgreSQL test DB | All specs | ✓ | verified via `bundle exec rspec spec/models/blog_spec.rb` (39 examples, 0 failures) | — |
| Chrome in CI | CI system specs | ✓ | `browser-actions/setup-chrome@v1`, `chrome-version: stable` — already in `.github/workflows/ci.yml` | — |
| Asset build in CI | CSS-dependent specs | ✓ | `npm run build && npm run build:css` already runs before `rspec` | — |
| `stimulus:manifest:update` rake task | Controller registration | ✓ | stimulus-rails present; task listed by `rails -T` | Hand-edit `index.js` (discouraged) |
| Local asset build | CSS-dependent specs locally | ⚠️ manual | `app/assets/builds/*` is gitignored and was stale | Run `npm run build && npm run build:css` (already done this session) |

**Missing dependencies with no fallback:** none.

**Missing dependencies with fallback:** none.

**Environment note for the planner:** CI already has everything system specs need. The only environmental gap is the *local* stale-build hazard (Pitfall 3), which is a documentation/workflow task, not an install.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `TRIGGER_PCT = 25` gives the feel D-01 describes. Only the *mechanism* was verified; the *feel* is a subjective judgement that CONTEXT.md itself marks tunable | Pattern 1 | Low — one constant, tunable in-browser; success criteria specify correctness at top/bottom/deep-link, not a specific percentage |
| A2 | Removing `tabindex` immediately after `focus()` (Turbo's pattern) keeps focus on the heading in all target browsers. Verified in Chrome only; adopted because Turbo 8 ships it | Pattern 3 | Low — if a browser blurs, switch to a permanent server-rendered `tabindex="-1"` |
| A3 | `scrollIntoView({block:'nearest'})` will not move the page in *all* sidebar states. Verified only with the sidebar sticky and in-viewport | Pattern 6 | Low — explicit `scrollTop` arithmetic is documented as a drop-in fallback with measured-identical output |
| A4 | Real `Escape` does not close `<details>` in Firefox/Safari either. Verified in Chrome 151 only; the JS assist is needed regardless, so this only affects whether the assist is redundant somewhere | Pattern 4 | Very low — the assist is required by D-06 in any case |
| A5 | `aria-current="location"` is the best token for in-page section links. MDN does not name a token for this case; `location` matches its definition better than `page` | Pitfall 7 | Very low — any token satisfies A11Y-01's "marked `aria-current`" |
| A6 | Reading `page.driver.browser.execute_cdp` will keep working in CI's Linux Chrome as it did locally on macOS | Code Examples | Low — CDP emulation is driver-level, not OS-level; if it fails, gate the reduced-motion spec behind a capability check |
| A7 | Turbo's `LinkClickObserver` being suppressed by capture-phase `stopPropagation()` also holds for prefetch/`turbo:before-fetch` paths. Only the click path was measured | Pitfall 1 | Very low — hash-only links are not prefetched |

Everything else in this document is either `[VERIFIED]` by direct measurement/source-read in this session, or `[CITED]` to MDN / the W3C spec / scottohara.me.

## Open Questions

1. **Should the legacy `_navigation.html.erb` smooth-scroll handler be fixed in this phase?**
   - What we know: it is broken (never rebinds after Turbo navigation), it breaks Phase 2's `.toc-permalink` links on Turbo-navigated posts, and the capture-phase fix means Phase 3 does **not** need it fixed to meet its own success criteria.
   - What's unclear: whether the user wants the adjacent bug fixed now or tracked separately.
   - Recommendation: **do not fix it in this phase.** Add a one-line note to `.planning/todos/pending/` or STATE.md Blockers. Scope discipline is an explicit project constraint.

2. **Should `Capybara.save_path` be corrected so CI failure screenshots upload?**
   - What we know: CI uploads `tmp/screenshots`; observed failures write to `tmp/capybara`. The step has `if-no-files-found: ignore`, so it fails silently.
   - What's unclear: nothing technical — it's a one-line change in either `spec/support/system.rb` or `ci.yml`.
   - Recommendation: include it. It costs one line and makes the phase's own new specs debuggable in CI, which is squarely within D-12's intent.

3. **How many headings should the INTX-03 fixture have?**
   - What we know: the requirement says ">10 headings"; measured at viewport 1400×900, **24 headings** produced a genuinely overflowing sidebar (`scrollHeight 796` vs `clientHeight 693`). A 12-heading post at that viewport may not overflow, making the test vacuous.
   - Recommendation: build the INTX-03 fixture with ~24 headings and **assert the container actually overflows** before asserting containment behavior, so the test cannot silently pass by never exercising the code.

4. **Is `prose-headings:scroll-mt-8` (32px) the right offset now that the header is confirmed non-sticky?**
   - What we know: Phase 2 D-07 established the header is `position: relative`, `h-16`, not sticky, so no header-height compensation is needed. Measured landing position is exactly 32px from the viewport top, for both `scrollIntoView` and native fragment navigation.
   - What's unclear: only whether 32px reads as enough breathing room visually.
   - Recommendation: leave as-is; it is Phase 2's decision and it demonstrably works. Note it in the manual QA pass rather than changing it.

## Sources

### Primary (HIGH confidence — direct measurement or source read in this session)
- **Live browser measurement**, Chrome 151.0.7922.108 headless via chromedriver 151.0.7922.77 (W3C WebDriver + CDP): `rootMargin` percentage axis resolution and unit validation; the extended-above scroll-spy algorithm at 8 scroll positions; bottom-of-page special-case necessity; `scroll-margin-top` honoring by `scrollIntoView` and native fragment navigation; `focus()` / `tabindex` / `preventScroll` behavior; `<details>` accessibility tree (`Accessibility.getPartialAXTree`) closed vs open; real Escape and Enter key behavior on `<summary>`; Tab traversal past a closed `<details>`; `toggle` event non-bubbling; five-way listener-ordering experiment against a replica of the legacy handler.
- **Live system specs run against this repo** (`bundle exec rspec`, `type: :system`): browser boot with zero extra config; FactoryBot data visibility under existing DatabaseCleaner config; viewport geometry from `screen_size`; `execute_cdp` reduced-motion emulation through Capybara; presence of the legacy handler on `/blog/:slug`; the full scroll-spy algorithm end-to-end including deep link; sidebar overflow + containment measurements; stale-vs-fresh asset build comparison.
- **Gem/package source read on disk**: `rspec-rails` 7.1.1 `system_example_group.rb` (`DEFAULT_DRIVER`, `type: :system` binding) and `configuration.rb`; `actionpack` 8.0.3 `system_test_case.rb` + `system_testing/driver.rb` (`registerable?`, `register_selenium`); `activerecord` 8.0.3 `test_fixtures.rb` (`setup_shared_connection_pool`, `pin_connection!`); `capybara` 3.40.0 `registrations/drivers.rb`; `selenium-webdriver` 4.36.0 `has_cdp.rb` + bundled `selenium-manager`; `@hotwired/turbo` 8.0.18 `View#focusElement`, `LinkClickObserver.clickBubbled`, `locationWithActionIsSamePage`; `@hotwired/stimulus` 3.2.2 action-descriptor parsing, `defaultActionDescriptorFilters`, `defaultEventNames`, `keyMappings`.
- **Tailwind v4.1.14 compilation** of candidate variant classes via the project's own `@tailwindcss/cli`.
- W3C Intersection Observer spec — https://w3c.github.io/IntersectionObserver/ (margin parsing algorithm, percentage resolution text, root intersection rectangle).
- MDN — `IntersectionObserver.rootMargin`, `IntersectionObserverEntry`, `<details>`, `aria-current`.

### Secondary (MEDIUM confidence)
- Scott O'Hara, *"Use the details element…"* — https://www.scottohara.me/blog/2022/09/12/details-summary.html (screen-reader variance, don't add `role=button`, marker-removal caveat). Cross-checked against the measured Chrome accessibility tree.
- Chris Kirknielsen, *"'Simple' Table of Contents Highlighter"* — https://chriskirknielsen.com/blog/simple-table-of-contents-highlighter/ (source of the extended-above `rootMargin` + last-visible-heading pattern; independently re-measured here before adoption).
- Stimulus lifecycle reference — https://stimulus.hotwired.dev/reference/lifecycle-callbacks. Cross-checked against the installed 3.2.2 bundle.
- w3c/IntersectionObserver issue #391, *"Percentage rootMargin resolution is unclear"* (spec-vs-browser divergence). Independently confirmed by measurement.

### Tertiary (LOW confidence — not relied upon for any recommendation)
- Maxime Heckel, *"Scrollspy demystified"* — uses a px-offset-only `rootMargin` and "first intersecting wins", which measured worse than the adopted pattern. Recorded for completeness only.
- Turbo Drive handbook — https://turbo.hotwired.dev/handbook/drive. The page does not document `turbo:before-cache` or same-page anchor interception; those claims were resolved from Turbo source instead.

## Metadata

**Confidence breakdown:**
- Standard stack: **HIGH** — zero new packages; every version read from this repo's lockfiles and, for the gems, from the installed source on disk.
- Architecture / scroll-spy algorithm: **HIGH** — the complete algorithm was executed against a real rendered blog post and produced correct results for all four cases in success criterion #2.
- `<details>` accessibility (D-06): **HIGH** — Chrome accessibility tree dumped directly, showing `expanded` tracking `open` with no literal `aria-expanded`.
- D-14 legacy-handler conflict: **HIGH** — reproduced on the real page, and the fix selected from a five-way controlled comparison.
- System-spec infrastructure (D-12/D-13): **HIGH** — working system specs ran in this repo, including the DatabaseCleaner compatibility question.
- Pitfalls: **HIGH** for 1–6 and 8–9 (all measured or read from source); **MEDIUM** for 7 (aria-current token choice is a judgement call — logged as A5).
- Cross-browser behavior (Firefox/Safari): **LOW** — everything was measured in Chrome. Acceptable, because the phase's automated verification target is headless Chrome and the patterns chosen (`<details>`, `scroll-margin-top`, `IntersectionObserver`, `preventScroll`) are all Baseline-widely-available.

**Research date:** 2026-08-08
**Valid until:** 2026-09-07 (30 days — the stack is stable; no fast-moving dependency involved)
