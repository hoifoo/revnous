# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-01)

**Core value:** A reader on a long blog post can see the article's structure at a glance and jump straight to any section — without the marketing team touching code or affecting how any existing post looks.
**Current focus:** Phase 1 — TOC Domain Core & Regression Baseline

## Current Position

Phase: 1 of 4 (TOC Domain Core & Regression Baseline)
Plan: 0 of TBD in current phase
Status: Ready to plan
Last activity: 2026-08-01 — Roadmap created, 18/18 v1 requirements mapped

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**
- Total plans completed: 0
- Average duration: —
- Total execution time: 0.0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| - | - | - | - |

**Recent Trend:**
- Last 5 plans: —
- Trend: —

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Roadmap]: Anchor ids are injected at render time, downstream of the last sanitizer — `Blog::ALLOWED_ATTRIBUTES` stays untouched, no `body` backfill
- [Roadmap]: Heading scope is H2/H3 only; 100% of current dev-DB posts have zero H2/H3, so legacy posts produce no TOC until rewritten (acceptable — feature is opt-in)
- [Roadmap]: Typography/spacing pass is scoped to the TOC-on two-column layout only, resolving the PROJECT.md contradiction with the zero-regression constraint
- [Roadmap]: Overrides stored as `jsonb` keyed by anchor (follows the `keywords` column precedent, not the `faq_schema` text-holding-JSON pattern)
- [Roadmap]: Layout (Phase 2) and client behavior (Phase 3) split deliberately — different failure modes, different verification methods

### Pending Todos

[From .planning/todos/pending/ — ideas captured during sessions]

None yet.

### Blockers/Concerns

[Issues that affect future work]

- No `spec/system` infrastructure exists in this repo — Phase 3 planning must decide between standing up a smoke test or committing a written manual QA checklist
- `rootMargin` reading band for scroll-spy is LOW confidence — tune in-browser during Phase 3
- Tiptap StarterKit Heading dropping unknown `id` attributes on round-trip is unverified (MEDIUM confidence) — quick manual check during Phase 1
- views4you.com reference UX returned HTTP 403 to automated fetch — verify visually during Phase 2/3 if precise interaction details matter

## Deferred Items

Items acknowledged and carried forward from previous milestone close:

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| Prior milestone | Blog CMS & SEO Overhaul phase 3 left at 13/19 requirements | Archived at `.planning/_archive/v1-blog-cms-seo-overhaul/` | 2026-08-01 |

## Session Continuity

Last session: 2026-08-01
Stopped at: ROADMAP.md and STATE.md created; REQUIREMENTS.md traceability updated
Resume file: None
