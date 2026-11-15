---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: executing
stopped_at: Phase 03 UI-SPEC approved
last_updated: "2026-08-08T08:49:16.768Z"
last_activity: 2026-08-08 -- Phase 03 execution started
progress:
  total_phases: 4
  completed_phases: 2
  total_plans: 13
  completed_plans: 7
  percent: 50
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-01)

**Core value:** A reader on a long blog post can see the article's structure at a glance and jump straight to any section — without the marketing team touching code or affecting how any existing post looks.
**Current focus:** Phase 03 — reading-navigation-behavior

## Current Position

Phase: 03 (reading-navigation-behavior) — EXECUTING
Plan: 1 of 6
Status: Executing Phase 03
Last activity: 2026-11-15 - Completed quick task 261115-hig: Upgrade Rails 8.0.3 to 8.1.4.1 to clear brakeman EOL CI failure

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**

- Total plans completed: 7
- Average duration: —
- Total execution time: 0.0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01 | 4 | - | - |
| 02 | 3 | - | - |

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

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 261113-qxp | Replace demo social-proof claims with real Revnous stats and reviews | 2026-11-13 | fbf9baa | [261113-qxp-replace-demo-social-proof-claims-with-re](./quick/261113-qxp-replace-demo-social-proof-claims-with-re/) |
| 261113-r80 | Replace demo case studies with real feature playbooks via data migration | 2026-11-13 | 08784ed | [261113-r80-replace-demo-case-studies-with-real-feat](./quick/261113-r80-replace-demo-case-studies-with-real-feat/) |
| 261115-hig | Upgrade Rails 8.0.3 to 8.1.4.1 to clear brakeman EOLRails CI failure | 2026-11-15 | 55b69b5 | [261115-hig-upgrade-rails-8-0-3-to-8-1-to-clear-brak](./quick/261115-hig-upgrade-rails-8-0-3-to-8-1-to-clear-brak/) |

## Deferred Items

Items acknowledged and carried forward from previous milestone close:

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| Prior milestone | Blog CMS & SEO Overhaul phase 3 left at 13/19 requirements | Archived at `.planning/_archive/v1-blog-cms-seo-overhaul/` | 2026-08-01 |

## Session Continuity

Last session: 2026-08-08T08:14:36.154Z
Stopped at: Phase 03 UI-SPEC approved
Resume file: .planning/phases/03-reading-navigation-behavior/03-UI-SPEC.md
