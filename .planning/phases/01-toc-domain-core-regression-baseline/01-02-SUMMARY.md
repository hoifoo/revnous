---
phase: 01-toc-domain-core-regression-baseline
plan: 02
subsystem: content-processing
tags: [nokogiri, html5-parsing, rails, table-of-contents, slug-generation, poro]

# Dependency graph
requires:
  - phase: 01-toc-domain-core-regression-baseline (plan 01)
    provides: toc_enabled/toc_overrides columns, Blog::ALLOWED_TAGS/ALLOWED_ATTRIBUTES unchanged
provides:
  - "Blog::TableOfContents PORO — Blog::TableOfContents.call(sanitized_html) returns #entries and #to_html from a single Nokogiri::HTML5 parse/mutation pass"
  - "Anchor contract: toc- prefixed, unique via used-set probe, positional toc-section-N fallback for empty-slug headings, MAX_SLUG_LENGTH=80 truncation with trailing-hyphen strip"
  - "Entry struct (level, anchor, label_html, text) with D-08 inline-markup-preserving labels narrowed to LABEL_TAGS"
  - "nokogiri promoted to a declared Gemfile dependency, pinned at already-locked 1.18.10"
affects: [01-03, 01-04, phase-02-toc-sidebar, phase-03-scroll-spy, phase-04-admin-overrides]

# Tech tracking
tech-stack:
  added: ["nokogiri (declared, was already transitive via rails-html-sanitizer)"]
  patterns:
    - "Parse once, mutate in place, serialize once — never re-parse to extract entries after injecting ids"
    - "Used-set probe for anchor uniqueness (not a per-base occurrence counter) — Hash.new(0) counters produce verified duplicate anchors"
    - "Nokogiri::HTML5.fragment required (not HTML4) to byte-round-trip the HTML5-vendor view sanitizer's output"

key-files:
  created:
    - app/models/blog/table_of_contents.rb
    - spec/models/blog/table_of_contents_spec.rb
  modified:
    - Gemfile
    - Gemfile.lock

key-decisions:
  - "PITFALL 2 case B collision fixture uses heading order [x, 🚀, Section 2] so the emoji's positional fallback (toc-section-2) is issued before the real heading Section 2 tries to claim the same base slug — proves the used-set probe, not just simple duplicate-text dedup"
  - "Verified once (then reverted) that swapping Nokogiri::HTML5.fragment for Nokogiri::HTML4::DocumentFragment.parse makes the byte-fidelity spec fail, confirming the spec is a real regression guard and not a tautology"

patterns-established:
  - "Model-adjacent PORO under app/models/blog/ resolved by Zeitwerk as Blog::TableOfContents — no base class, no mixin, frozen SCREAMING_SNAKE constants at top, private helpers grouped at bottom"

requirements-completed: [TOC-02, TOC-03]

# Metrics
duration: 6min
completed: 2026-08-02
---

# Phase 01 Plan 02: TOC Domain Core (Blog::TableOfContents PORO) Summary

**Blog::TableOfContents PORO derives ordered H2/H3 entries with unique toc- anchors from already-sanitized HTML via a single Nokogiri::HTML5 parse, using a used-set probe for dedup and positional fallbacks for non-Latin/empty-slug headings.**

## Performance

- **Duration:** 6 min (14:58:37 → 14:04:04 local)
- **Started:** 2026-08-02T11:58:37Z
- **Completed:** 2026-08-02T12:04:04Z
- **Tasks:** 2
- **Files modified:** 4 (2 created, 2 modified)

## Accomplishments
- `Blog::TableOfContents.call(sanitized_html)` implemented exactly per RESEARCH.md Pattern 1: single `Nokogiri::HTML5.fragment` parse, in-place mutation, `#entries` and `#to_html` from the same pass
- Anchor uniqueness via a used-set probe (not `Hash.new(0)`), verified against both documented collision cases (duplicate real headings, and a real heading colliding with a positional fallback)
- `nokogiri` promoted from transitive to declared Gemfile dependency with zero lockfile churn beyond the `DEPENDENCIES` line, still pinned at 1.18.10
- Pure DB-free unit spec with 15 examples covering D-01/D-10 heading scope, D-02 anchor contract (including all four verified empty-slug script classes: emoji, CJK, Cyrillic, punctuation), D-08 label markup preservation, and PITFALL 1 byte-fidelity

## Task Commits

Each task was committed atomically:

1. **Task 1: Declare nokogiri and implement the Blog::TableOfContents PORO** - `bf139fe` (feat)
2. **Task 2: Pure unit spec pinning the anchor contract, the fallback path, and byte fidelity** - `d2b622d` (test)

**Plan metadata:** (this commit, docs: complete plan)

## Files Created/Modified
- `app/models/blog/table_of_contents.rb` - `Blog::TableOfContents` PORO: `.call`, `#entries`, `#to_html`, anchor allocation, D-08 label sanitization
- `spec/models/blog/table_of_contents_spec.rb` - 15-example pure unit spec covering the anchor contract, fallback path, label formatting, and byte fidelity
- `Gemfile` - added `gem "nokogiri"` in the top-level (runtime) group
- `Gemfile.lock` - single `nokogiri` line added under `DEPENDENCIES`; resolved version unchanged at 1.18.10

## Decisions Made
- Anchor collision fixture for PITFALL 2 case B uses order `[x, 🚀, Section 2]` specifically so the positional fallback is issued before the colliding real heading is processed — this is the exact scenario a naive per-base counter passes by accident and a used-set probe catches correctly.
- No new sanitizer configuration was added anywhere; the PORO only sets `id` attributes on nodes already permitted by the two existing, unchanged sanitizer passes.

## Deviations from Plan

None - plan executed exactly as written. The temporary `Nokogiri::HTML4::DocumentFragment.parse` swap performed to satisfy the acceptance criterion "deliberately swapping the parser makes the byte-fidelity spec fail" was reverted immediately after confirmation (`git diff` on the file showed no residual change).

## Issues Encountered
None. All automated verification (inline `bin/rails runner` script, `bundle exec rspec spec/models/blog/table_of_contents_spec.rb`, `bundle exec rspec spec/models`, `bundle exec rubocop`) passed on the first attempt with no auto-fixes required.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- `Blog::TableOfContents` is ready for plan 01-04's `BlogsHelper#blog_body_with_toc_anchors` to wrap the existing `sanitize` call in `show.html.erb`, per D-03/Pattern 3.
- The `Entry` struct's `label_html`/`text`/`anchor`/`level` fields are the stable interface Phase 2 (sidebar), Phase 3 (scroll-spy), and Phase 4 (admin overrides) will all consume — no changes anticipated to this shape based on this plan's scope.
- No blockers. Sibling plan 01-01 (migrations, controller strong params, `blog_spec.rb` id-strip invariant) touches disjoint files and was executed in parallel.

---
*Phase: 01-toc-domain-core-regression-baseline*
*Completed: 2026-08-02*
