# Phase 3: Reading Navigation Behavior - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-08
**Phase:** 3-reading-navigation-behavior
**Areas discussed:** Scroll-spy active-section feel, Mobile Contents disclosure, Focus destination on mobile select, Verifying dynamic JS behavior

---

## Scroll-spy active-section feel

| Option | Description | Selected |
|--------|-------------|----------|
| Near top band | Heading active once it crosses top 20-25% of viewport (GitBook/Docusaurus-style) | ✓ |
| Viewport center | Section active when centered in viewport | |
| You decide | Claude picks rootMargin | |

**User's choice:** Near top band
**Notes:** Resolves STATE.md's LOW-confidence `rootMargin` blocker; exact values remain tunable in-browser (D-01).

| Option | Description | Selected |
|--------|-------------|----------|
| First entry active | Highlight first TOC entry by default at page top | ✓ |
| No entry active | Nothing highlighted until scrolled past first heading | |

**User's choice:** First entry active (D-02)

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, activate at page bottom | Explicit bottom-of-page special case for last section | ✓ |
| You decide | Claude implements per success criteria | |

**User's choice:** Yes, activate at page bottom (D-03)

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, active on load | Compute active entry from URL hash synchronously on connect | ✓ |
| You decide | Claude implements per success criteria | |

**User's choice:** Yes, active on load (D-04)

---

## Mobile Contents disclosure

| Option | Description | Selected |
|--------|-------------|----------|
| `<details>/<summary>` | Native disclosure, free keyboard toggle, needs JS assist for Escape | ✓ |
| Button + panel with aria-expanded | Full manual control, more code | |
| You decide | Claude picks simplest path | |

**User's choice:** `<details>/<summary>` (D-05)

**Follow-up:** Flagged that ROADMAP success criterion #4 literally says "reports state with `aria-expanded`" — `<details>` uses the native `open` attribute instead, not literal `aria-expanded`.

| Option | Description | Selected |
|--------|-------------|----------|
| Keep `<details>`, treat `open` attr as satisfying intent | Functionally equivalent a11y contract | ✓ |
| Switch to button+aria-expanded to match roadmap literally | Build custom disclosure instead | |

**User's choice:** Keep `<details>`, treat `open` attr as satisfying intent (D-06)

| Option | Description | Selected |
|--------|-------------|----------|
| "Contents" | Roadmap's own wording, shorter mobile tap target | ✓ |
| "Table of Contents" | Matches desktop sidebar heading | |
| You decide | Claude picks label | |

**User's choice:** "Contents" (D-07)

| Option | Description | Selected |
|--------|-------------|----------|
| Static "Contents" label | No coupling between scroll-spy and trigger text | ✓ |
| Dynamic label showing active section | Trigger updates as reader scrolls | |

**User's choice:** Static "Contents" label (D-08)

---

## Focus destination on mobile select

| Option | Description | Selected |
|--------|-------------|----------|
| Target heading | Same as desktop A11Y-02, one shared code path | ✓ |
| Trigger button first, then heading | Two-step return-focus-then-navigate pattern | |

**User's choice:** Target heading (D-10)

| Option | Description | Selected |
|--------|-------------|----------|
| Back to the trigger button | Standard disclosure/dialog Escape-as-cancel convention | ✓ |
| You decide | Claude implements standard convention | |

**User's choice:** Back to the trigger button (D-11)

---

## Verifying dynamic JS behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Stand up spec/system with a JS driver | Capybara + selenium-webdriver already in Gemfile, unused | ✓ |
| Manual QA checklist (matches Phase 2) | No new infra, zero regression protection | |
| Both — checklist now, system specs as follow-up | Ship unblocked, note fast-follow | |

**User's choice:** Stand up spec/system with a JS driver
**Notes:** Resolves STATE.md's "no spec/system infrastructure" blocker — this phase's dynamic behavior (scroll-spy, focus, keyboard/Escape) is judged too regression-prone for manual-only verification, unlike Phase 2's static layout (D-12).

| Option | Description | Selected |
|--------|-------------|----------|
| Selenium + headless Chrome | Already in Gemfile test group, no new gem | ✓ |
| You decide | Claude picks simplest available driver | |

**User's choice:** Selenium + headless Chrome (D-13)

---

## Claude's Discretion

- Exact `rootMargin`/`threshold` values for the near-top-band scroll-spy trigger
- Stimulus controller file structure (one controller vs. two for scroll-spy + disclosure)
- IntersectionObserver vs. scroll-listener implementation for INTX-03's "keep active entry in view"
- `prefers-reduced-motion` check implementation details
- System spec file organization under `spec/system/`

## Deferred Ideas

None — discussion stayed within Phase 3 scope.

## Landmine Flagged (not a discussion question, informational)

`app/views/shared/_navigation.html.erb`'s existing global `DOMContentLoaded`-scoped smooth-scroll handler doesn't respect `prefers-reduced-motion`, doesn't manage focus, and doesn't rebind after Turbo navigations. Phase 3's new Stimulus controller must own TOC link clicks directly rather than relying on or conflicting with it (D-14).
