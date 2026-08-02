# Phase 2: Public Rendering & Two-Column Layout - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-02
**Phase:** 2-public-rendering-two-column-layout
**Areas discussed:** Two-column layout & mobile fallback, Sidebar visual design, toc_overrides data shape, Typography pass & permalink affordance

---

## Two-Column Layout & Mobile Fallback

| Option | Description | Selected |
|--------|-------------|----------|
| Right side | Matches views4you.com reference; article reads left-to-right with TOC as companion on the right | ✓ |
| Left side | TOC acts like a book/doc-site table of contents; less common for blog reading UX | |

**User's choice:** Right side

| Option | Description | Selected |
|--------|-------------|----------|
| lg (1024px+) only | Tablet portrait stays single-column, sidebar gets more room | ✓ |
| md (768px+) | Matches ROADMAP wording "desktop/tablet" more literally, but sidebar cramped on portrait tablets | |

**User's choice:** lg (1024px+) only

| Option | Description | Selected |
|--------|-------------|----------|
| Nothing | Single-column article only below breakpoint; Phase 3 builds mobile disclosure as new markup | ✓ |
| Static plain-link list | Non-interactive list above article now, Phase 3 wraps in disclosure later | |

**User's choice:** Nothing

| Option | Description | Selected |
|--------|-------------|----------|
| Fixed width column | Predictable, stable article reading measure regardless of TOC entry length | ✓ |
| Proportional (fraction) | Scales with viewport but reading measure shifts on wide screens | |

**User's choice:** Fixed width column

**Notes:** None of the four answers deviated from the recommended option.

---

## Sidebar Visual Design

| Option | Description | Selected |
|--------|-------------|----------|
| "Contents" | Short, matches planned Phase 3 mobile disclosure trigger text | |
| "On this page" | Common docs-site phrasing | |
| "Table of Contents" | More formal/explicit; longer label | ✓ |

**User's choice:** "Table of Contents" — deviated from the recommended "Contents". Noted in CONTEXT.md that Phase 3's mobile disclosure trigger label is a separate decision and doesn't need to match.

| Option | Description | Selected |
|--------|-------------|----------|
| Indent + smaller/lighter text | H3 gets left padding + lighter/smaller text vs H2 | ✓ |
| Indent only, same text style | Simpler, just left padding differentiates | |

**User's choice:** Indent + smaller/lighter text

| Option | Description | Selected |
|--------|-------------|----------|
| top-8 (32px) | Header is not sticky/fixed, so minimal top gap suffices | ✓ |
| top-24 (96px) | More generous gap, aligned with article title | |

**User's choice:** top-8 (32px)

| Option | Description | Selected |
|--------|-------------|----------|
| Gray text, pink-600 on hover | Matches existing brand link/CTA color usage | ✓ |
| Underline on hover only | More minimal, no color change | |

**User's choice:** Gray text, pink-600 on hover

---

## toc_overrides Data Shape

**Note:** Two sub-questions in this area had only one valid option each and were resolved as Claude's-call decisions rather than asked:
- Hiding an entry only removes it from the TOC list, never affects the heading/anchor in the article body itself (deep links keep working).
- The "fewer than 3" threshold is inclusive: exactly 3 visible entries still shows the sidebar, 2 or fewer suppresses it.

| Option | Description | Selected |
|--------|-------------|----------|
| Hide only | Phase 2 reads toc_overrides only to filter hidden anchors; relabel/reorder rendering deferred to Phase 4 alongside its UI | ✓ |
| Hide + relabel + reorder now | Phase 2 fully respects the eventual override shape now, more speculative code | |

**User's choice:** Hide only

| Option | Description | Selected |
|--------|-------------|----------|
| Hash keyed by anchor | e.g. `{"toc-intro": {"hidden": true}}` — matches `keywords`-column jsonb precedent | ✓ |
| Array of override objects | e.g. `[{"anchor": "toc-intro", "hidden": true}]` — natural order field, requires linear scan | |

**User's choice:** Hash keyed by anchor

---

## Typography Pass & Permalink Affordance

| Option | Description | Selected |
|--------|-------------|----------|
| Constrain to prose-lg default max-width | Caps line length even as article shares grid space with sidebar | ✓ |
| Fill remaining grid column width | No cap, could produce very long lines on wide viewports | |

**User's choice:** Constrain to prose-lg default max-width

| Option | Description | Selected |
|--------|-------------|----------|
| Increase heading top margin | Purely additive CSS to reinforce section breaks | ✓ |
| Keep prose defaults as-is | No spacing changes | |

**User's choice:** Increase heading top margin

| Option | Description | Selected |
|--------|-------------|----------|
| Hover-reveal # icon | Fades in on hover/focus, after heading text — common docs pattern | ✓ |
| Always-visible # icon | Always shown, more discoverable but more visual clutter | |

**User's choice:** Hover-reveal # icon

---

## Claude's Discretion

- Exact Tailwind grid classes/structure for the two-column layout.
- Restructuring `blog_body_with_toc_anchors` to expose both anchor-injected HTML and entries list from a single parse pass.
- Where the "3+ visible entries after hiding" filter logic lives.
- Exact permalink icon markup/SVG and hover transition styling.
- Precise Tailwind spacing scale values for the heading margin increase.
- Whether `toc_overrides` needs a DB index.

## Deferred Ideas

None — discussion stayed within Phase 2 scope.
