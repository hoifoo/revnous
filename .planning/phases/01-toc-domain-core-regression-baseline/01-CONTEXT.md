# Phase 1: TOC Domain Core & Regression Baseline - Context

**Gathered:** 2026-08-02
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase delivers the derivation logic and data model for a Table of Contents — no rendering, no layout, no client behavior. Concretely:

- A `Blog::TableOfContents`-style PORO (or equivalent) that parses a post's already-sanitized `body` HTML and derives ordered H2/H3 entries, each with a stable, unique `toc-` prefixed anchor id.
- Anchor `id` attributes injected into the rendered `/blog/:slug` response HTML, downstream of the existing sanitizer pass — never persisted to `body`, never added to `Blog::ALLOWED_ATTRIBUTES`.
- Two new columns: `toc_enabled` (boolean, default false, no backfill) and `toc_overrides` (jsonb, no backfill).
- A golden-master request spec that freezes today's TOC-off rendering so any future layout change (Phase 2+) that regresses an existing post fails CI.

Explicitly NOT this phase: sidebar UI, two-column layout, typography pass, scroll-spy, smooth scroll, mobile dropdown, admin override UI (those are Phases 2–4).

</domain>

<decisions>
## Implementation Decisions

### TOC Scope & Anchor Contract (locked in PROJECT.md / ROADMAP.md — carried forward, not re-discussed)
- **D-01:** Only H2/H3 headings become TOC entries; H1 and H4–H6 are excluded (TOC-02). Legacy posts with only H1 content produce an empty TOC until rewritten — accepted, feature is opt-in.
- **D-02:** Every entry's anchor is `toc-` prefixed, unique within the post; duplicate headings dedupe with a counter suffix; headings that slugify to empty (emoji-only, CJK-only, punctuation-only) fall back to a positional `toc-section-N` anchor (TOC-03).
- **D-03:** Anchor `id`s are injected at render time, downstream of the last sanitizer pass (`app/views/blogs/show.html.erb`'s `sanitize @blog.body, tags: Blog::ALLOWED_TAGS, attributes: Blog::ALLOWED_ATTRIBUTES`). `Blog::ALLOWED_ATTRIBUTES` stays unchanged — `id` is never added to the sanitizer allowlist. This avoids a `body` backfill migration and avoids opening a DOM-clobbering surface via stored `id` attributes.
- **D-04:** Anchors are derived, not persisted/stable — if a heading's text changes later, its anchor changes too. Persisted rename-stable anchor mapping is explicitly deferred to v2 (TOCV2-03).
- **D-05:** `toc_enabled` defaults to `false`; `toc_overrides` is a `jsonb` column keyed by anchor (follows the `keywords` column jsonb precedent, not the `faq_schema` text-holding-JSON pattern). No backfill migration — existing rows must be byte-for-byte unchanged (`body`, `updated_at`, `seo_description`, `.md` export, `api/v1/blogs/show.json`).
- **D-06:** `Article < Blog` (STI) is in scope automatically — no special-casing needed.
- **D-07:** The golden-master spec is a request spec (not a system/visual test), capturing HTML of a TOC-off `/blog/:slug` response (LAYOUT-04).

### TOC Label Formatting (discussed)
- **D-08:** TOC sidebar entry labels preserve inline formatting from the heading (e.g., a heading `Getting <code>Started</code> Fast` produces a label that keeps the `<code>` styling), not plain-text-only extraction. The PORO's entry label field must carry sanitized inline markup (a safe subset — e.g. `code`, `em`, `strong` — consistent with `Blog::ALLOWED_TAGS`), not a plain string. Downstream (Phase 2) renders this label; Phase 1 just needs the data shape to support it.

### Golden-Master Baseline Scope (discussed)
- **D-09:** The golden-master spec uses a curated fixture set of 3–5 posts, not a single fixture and not a live sample of real published posts. Fixtures must cover: images, tables, an FAQ section, code blocks, and a minimal/near-empty body. Goal: catch regressions across the real markup surface (`Blog::ALLOWED_TAGS`) without coupling the spec to mutable seed/dev-DB data.

### Orphaned H3 Handling (discussed)
- **D-10:** An H3 that appears before any H2 in the body (no parent section) is still included in the TOC, flat — every H2/H3 in document order gets an entry regardless of nesting validity. No silent dropping of headings the author wrote. (This matches TOC-02's plain "H2/H3 headings" scope — no hierarchy-validity filter.)

### Claude's Discretion
- PORO class name/location, internal API shape (return value: array of value objects/structs vs hashes).
- HTML parsing library choice (Nokogiri is already available transitively via `Rails::Html::SafeListSanitizer`).
- Exact slugification algorithm (parameterize-based vs custom) and collision-suffix format (e.g. `toc-heading-2` vs `toc-heading--2`), as long as it satisfies D-02's uniqueness/dedup/fallback contract.
- Where in the render pipeline anchor injection happens (helper vs view concern) — must land after the existing sanitizer call per D-03.
- `toc_overrides` jsonb default value and whether an index on `toc_enabled` is warranted.
- Migration structure/order (single migration vs two).
- How to verify the noted blocker: "Tiptap StarterKit Heading dropping unknown `id` attributes on round-trip is unverified (MEDIUM confidence)" — quick manual/spec check during this phase, per STATE.md Blockers/Concerns.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project scope & decisions
- `.planning/PROJECT.md` — full project scope, constraints, and Key Decisions table (anchor injection strategy, jsonb override pattern, H2/H3 scope, typography scoping)
- `.planning/REQUIREMENTS.md` — v1/v2 requirement definitions and traceability; this phase covers TOC-01, TOC-02, TOC-03, LAYOUT-04
- `.planning/ROADMAP.md` — Phase 1 goal and success criteria (verbatim contract for this phase)
- `.planning/STATE.md` — accumulated decisions and open Blockers/Concerns (Tiptap round-trip `id` stripping, `rootMargin` low-confidence note for later phases)

### Existing code this phase touches or must respect
- `app/models/blog.rb` — `ALLOWED_TAGS`, `ALLOWED_ATTRIBUTES`, `sanitize_body` (before_save), existing jsonb pattern (`keywords` column) and text-jsonb pattern (`faq_schema`) to follow/avoid respectively
- `app/views/blogs/show.html.erb` (line ~76) — the render-time `sanitize @blog.body, tags:, attributes:` call that D-03's anchor injection must sit downstream of
- `db/schema.rb` `blogs` table — current columns, no `id`-bearing attribute anywhere; `type` column already present for STI (`Article`)

No external specs/ADRs beyond the project's own `.planning/` docs — requirements fully captured in decisions above.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Rails::Html::SafeListSanitizer` (already used in `Blog#sanitize_body` and in `show.html.erb`) — the sanitization primitive; anchor injection must be a separate downstream step, not a new sanitizer configuration.
- `keywords` jsonb column pattern on `Blog` (`t.jsonb "keywords", default: [], null: false` + `normalize_keywords` before_save) — the precedent to follow for `toc_overrides`, per PROJECT.md D-05.

### Established Patterns
- STI via `type` column (`Article < Blog`) already exists in schema — new columns on `blogs` table automatically apply to `Article`.
- Blog model private methods pattern: `before_save` callbacks for body/data normalization (`sanitize_body`, `normalize_keywords`, `parse_faq_schema`) — a similar callback-free or callback-based approach may fit `toc_overrides` normalization, at Claude's discretion.

### Integration Points
- `app/views/blogs/show.html.erb` line 76 is the single point where sanitized `body` becomes response HTML — this is where/downstream-of-where anchor `id` injection must occur.
- `api/v1/blogs/show.json` (Jbuilder) must remain byte-for-byte unchanged per D-05 — anchor injection is HTML-response-only, not part of the model attribute or JSON serialization.

</code_context>

<specifics>
## Specific Ideas

- TOC label formatting should preserve inline formatting (code/em/strong) rather than flattening to plain text — user's explicit choice, see D-08.
- Golden-master fixtures should deliberately include an FAQ section post and a code-block-heavy post, since those exercise the least common tags in `Blog::ALLOWED_TAGS`.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within Phase 1 scope. (Multi-page posts, gem extraction, and broader nav/discovery UX remain deferred at the project level per PROJECT.md Out of Scope — not raised again here.)

</deferred>

---

*Phase: 1-toc-domain-core-regression-baseline*
*Context gathered: 2026-08-02*
