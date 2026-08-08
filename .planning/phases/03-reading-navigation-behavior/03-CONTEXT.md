# Phase 3: Reading Navigation Behavior - Context

**Gathered:** 2026-08-08
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase delivers the client-side dynamic behavior layer on top of Phase 2's static two-column TOC layout — no more markup/layout changes beyond what's strictly needed to support behavior. Concretely:

- Scroll-spy: an IntersectionObserver-driven Stimulus controller that highlights the currently-read section in the desktop sidebar (`aria-current`), correct at page top, on the last section, and on initial load from a `#anchor` deep link.
- Click-to-jump: clicking a TOC entry smooth-scrolls to the target heading (instant jump when `prefers-reduced-motion` is set), lands clear of the sticky header (offset already partly in place via Phase 2's `prose-headings:scroll-mt-8`), and moves keyboard focus to the heading (A11Y-02).
- Mobile "Contents" disclosure: new markup (Phase 2 explicitly rendered nothing below `lg`) using `<details>/<summary>`, keyboard/Escape-operable, auto-closes after selection, focus-managed.
- Sidebar internal scroll behavior: keep the active entry visible in the sidebar's existing `overflow-y-auto` container without moving the page (INTX-03) — CSS scroll container already exists from Phase 2, this phase adds the "keep active entry in view" JS behavior.
- Teardown discipline: all observers/listeners must be torn down on Turbo navigation (`disconnect()`), and page-level `scroll-behavior: smooth` must never be set root-wide (success criterion #5).
- New system spec infrastructure (Capybara + Selenium headless Chrome) to give this phase's dynamic behavior real regression coverage — first phase in the project to need it.

Explicitly NOT this phase: any layout/CSS restructuring beyond disclosure markup, the admin override UI (Phase 4), anything to do with `toc_overrides` writing.

</domain>

<decisions>
## Implementation Decisions

### Scroll-spy active-section feel (discussed)
- **D-01:** The "active" trigger line sits in a near-top band — a heading becomes active once it crosses roughly the top 20-25% of the viewport (IntersectionObserver `rootMargin` tuned to that band). Matches common docs-site TOC patterns (GitBook/Docusaurus-style); feels responsive as new sections come into view near the top rather than lagging until they reach center.
- **D-02:** The first TOC entry is active by default at the very top of the page (before the reader has scrolled past the first heading) — the TOC is never in a state where nothing is highlighted.
- **D-03:** The last section's entry becomes active once the reader reaches the bottom of the page, even if that section is too short to naturally cross the top-band trigger — implemented as an explicit bottom-of-page special case (e.g. `scrollTop + clientHeight >= scrollHeight` check), not left to the IntersectionObserver alone. Required by success criterion #2's "correct... on the final section."
- **D-04:** On initial load via a `#anchor` deep link, the matching entry is computed and marked active synchronously on `connect()` from `window.location.hash`, before any scroll/observer event fires — avoids a flash of "first entry active" before the real position is known.

### Mobile Contents disclosure (discussed)
- **D-05:** Built as a native `<details>/<summary>` element, not a custom button+panel. Free keyboard toggle (Enter/Space), degrades with zero JS, no manual ARIA wiring for open/closed state. Escape-to-close is not native in all browsers and needs a small JS assist (D-06).
- **D-06:** Success criterion #4's "reports state with `aria-expanded`" is satisfied by the native `<details>` `open` attribute, not a literal `aria-expanded` attribute — screen readers already key off `open` for disclosure state, and it's the accessibility-equivalent contract. This is a deliberate reinterpretation of the roadmap's literal wording, made because the wording predates the implementation-pattern decision (D-05).
- **D-07:** The trigger (`<summary>`) label is the static string **"Contents"** — matches the roadmap's own phrasing ("tappable Contents disclosure"), and Phase 2 D-05 already established that the mobile trigger's label is independent of the desktop sidebar's "Table of Contents" heading.
- **D-08:** The trigger label stays static regardless of scroll position — it does NOT show the currently active section name. Keeps scroll-spy state and the (possibly collapsed) trigger decoupled; roadmap only requires open/close/auto-close/keyboard behavior, not a live label.
- **D-09 (follows from D-05, not separately asked):** `<details>` auto-closes after an entry is selected by setting `open = false` in the click handler (native `<details>` doesn't auto-close on internal link click).

### Focus management (discussed)
- **D-10:** Clicking a TOC entry — on desktop OR inside the mobile disclosure — moves keyboard focus to the target heading. Same code path for both; no separate "mobile returns to trigger first" step. Satisfies A11Y-02 uniformly.
- **D-11:** When the mobile disclosure is closed via Escape (not by selecting an entry), focus returns to the `<summary>` trigger button — standard disclosure/dialog convention: Escape is a pure cancel, so focus goes back to what opened it. Only entry-selection sends focus to a heading (D-10); Escape never does.

### Verifying dynamic JS behavior (discussed)
- **D-12:** This phase stands up `spec/system` with Capybara + `selenium_chrome_headless` (Selenium + headless Chrome). `selenium-webdriver` is already in the Gemfile's test group, unused — this phase is the first that needs a real JS driver, since scroll-spy/focus/keyboard behavior can't be meaningfully verified by request specs or a manual checklist alone (unlike Phase 2's static layout, which was manual-QA'd). System specs should cover at minimum: scroll-spy activates the correct entry as the page scrolls, clicking an entry moves focus to the heading, the mobile disclosure opens/closes via keyboard and Escape with focus returning to the trigger, and disclosure auto-closes on entry selection.
- **D-13:** No new gem required — `capybara` + `selenium-webdriver` are already present; the work is registering the `:selenium_chrome_headless` Capybara driver and adding `spec/system/` with `rails_helper` JS-driver config.

### Known landmine (Claude's call, not asked — flagged for planning)
- **D-14:** `app/views/shared/_navigation.html.erb` (lines 261-278) already has a global inline smooth-scroll handler (`document.querySelectorAll('a[href*="#"]')` inside a `DOMContentLoaded` listener) that intercepts ALL anchor-hash links site-wide, including future TOC links. It does not respect `prefers-reduced-motion`, does not move focus, and — because it's `DOMContentLoaded`-scoped rather than `turbo:load`-scoped — does not rebind after a Turbo Drive navigation swaps in a new page's TOC links. Phase 3's new Stimulus controller must own TOC link clicks itself (`event.preventDefault()` + `stopPropagation()` or an equivalent exclusion) rather than relying on or fighting this existing handler, to avoid double-scroll or the global handler silently winning on same-session Turbo-navigated posts. This is an implementation detail, not something requiring a user decision — flagged here so the planner treats it as a required task, not a surprise.

### Claude's Discretion
- Exact `rootMargin`/`threshold` values implementing D-01's near-top band (tunable in-browser).
- Stimulus controller name/file structure (e.g. `toc_controller.js`), whether scroll-spy and mobile-disclosure logic live in one controller or two.
- Exact IntersectionObserver vs scroll-listener implementation for keeping the active sidebar entry in view (INTX-03) — CSS container (`overflow-y-auto`) already exists from Phase 2.
- `prefers-reduced-motion` check implementation (`matchMedia` query, checked at click time).
- Exact system spec file organization and naming under `spec/system/`.
- Whether disclosure logic needs its own Stimulus controller or is folded into the same TOC controller as scroll-spy.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project scope & decisions
- `.planning/PROJECT.md` — full project scope, constraints, Key Decisions table
- `.planning/REQUIREMENTS.md` — this phase covers LAYOUT-02, INTX-01, INTX-02, INTX-03, A11Y-02, A11Y-03
- `.planning/ROADMAP.md` — Phase 3 goal and success criteria (verbatim contract for this phase, including the exact `aria-expanded`/`open` wording D-06 reinterprets)
- `.planning/STATE.md` — accumulated decisions and open Blockers/Concerns; specifically the `rootMargin` LOW-confidence note (now resolved by D-01, still tunable) and the "no spec/system infrastructure" blocker (resolved by D-12)
- `.planning/phases/01-toc-domain-core-regression-baseline/01-CONTEXT.md` — Phase 1 decisions (anchor derivation, `toc-` prefix, D-03 render-time injection)
- `.planning/phases/02-public-rendering-two-column-layout/02-CONTEXT.md` — Phase 2 decisions this phase builds directly on: D-02/D-03 (breakpoint + "nothing renders below `lg`" — this phase owns all mobile markup new), D-07 (sticky sidebar `top-8` offset), the existing `lg:overflow-y-auto lg:max-h-[calc(100vh-4rem)]` sidebar scroll container this phase's INTX-03 behavior must use

### Existing code this phase touches or must respect
- `app/views/blogs/_toc_sidebar.html.erb` — the desktop sidebar partial from Phase 2; renders `<nav aria-label="Table of contents">` with plain anchor links, no `aria-current` yet (this phase adds it), already has the internal-scroll container class
- `app/views/blogs/show.html.erb` (lines 76-85) — the two-column grid wrapper and `prose-headings:scroll-mt-8` offset class from Phase 2; this phase adds the mobile `<details>` disclosure markup, likely rendered adjacent to or above this block for widths below `lg`
- `app/helpers/blogs_helper.rb` — `blog_article(blog)` returns `ArticleContent#toc_entries` (visible entries with `anchor`, `level`, `label_html`, `text`) already computed server-side; this phase's Stimulus controller reads anchor IDs from the rendered DOM, no new server-side data needed
- `app/views/shared/_navigation.html.erb` (lines 201, 261-278) — global `DOMContentLoaded`-scoped smooth-scroll handler; see D-14 landmine above. Also the header itself confirmed `position: relative`, `h-16`, not sticky (Phase 2 D-07 already established this — no header-height offset needed beyond `scroll-mt-8`)
- `app/javascript/controllers/` — existing Stimulus controllers to match conventions against: `cookie_consent_controller.js` (import from `@hotwired/stimulus`, `data-controller="cookie-consent"` kebab-case, `connect()`/lifecycle methods, private-ish helper methods below public actions), `faq_builder_controller.js`
- `app/javascript/application.js` — Stimulus controller registration entry point
- `Gemfile` (test group, lines ~91-93) — `capybara` and `selenium-webdriver` already present, currently unused (no `spec/system/` directory exists yet)
- `spec/rails_helper.rb` — needs Capybara JS-driver configuration added for D-12/D-13

No external specs/ADRs beyond the project's own `.planning/` docs.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `app/views/blogs/_toc_sidebar.html.erb`'s existing sticky/scroll-container classes (`lg:sticky lg:top-8 lg:max-h-[calc(100vh-4rem)] lg:overflow-y-auto`) — INTX-03's "keep active entry visible" behavior scrolls within this existing container, no new CSS container needed.
- `app/javascript/controllers/cookie_consent_controller.js` — closest existing example of a non-trivial Stimulus controller with DOM-derived config (`this.element.dataset.*`), lifecycle-aware setup, and clear public/private method separation. Good structural template for the new TOC controller.
- Every heading already gets a stable `toc-` prefixed `id` (Phase 1) and every visible sidebar link already points to `#anchor` (Phase 2) — this phase's JS reads existing DOM, doesn't need to compute anchors itself.

### Established Patterns
- Stimulus controllers registered via `data-controller="kebab-case-name"` on a wrapping element, imported from `@hotwired/stimulus`, one file per controller in `app/javascript/controllers/`.
- Controllers handle Turbo Drive transitions via `disconnect()` — this phase's teardown requirement (success criterion #5) follows the same pattern already established for other controllers, not a new convention.
- No global JS state stored on `window` for Stimulus controllers (existing convention, per architecture notes) — contrasts with the legacy `_navigation.html.erb` inline script's approach, which this phase should not imitate.

### Integration Points
- `app/views/blogs/show.html.erb` and `_toc_sidebar.html.erb` need `data-controller`, `data-action`, and `data-*-target` attributes added to wire the new Stimulus controller to the existing sidebar nav, entry links, and (new) mobile `<details>` element.
- `app/javascript/application.js` needs the new controller registered/imported.
- `spec/rails_helper.rb` needs a JS-capable Capybara driver registered for the new `spec/system/` specs (D-12).

</code_context>

<specifics>
## Specific Ideas

- Reference UX pattern (carried from Phase 1/2 context): https://views4you.com/blog/move-tiktok-audience-to-instagram/ — scroll-spy active-section highlight, smooth scroll on click. Site blocks automated fetch (HTTP 403); behavior confirmed via user description only — verify visually in-browser if precise timing/feel details matter once the near-top-band scroll-spy (D-01) is implemented.
- "Contents" as the exact mobile trigger label (D-07) — user's explicit wording choice, matching roadmap phrasing rather than the desktop sidebar's more formal "Table of Contents".

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within Phase 3 scope. Multi-page posts, gem extraction, and broader nav/discovery UX remain deferred at the project level per PROJECT.md Out of Scope — not raised again here.

</deferred>

---

*Phase: 3-reading-navigation-behavior*
*Context gathered: 2026-08-08*
