# Phase 1: TOC Domain Core & Regression Baseline - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-08-02
**Phase:** 1-toc-domain-core-regression-baseline
**Areas discussed:** TOC label formatting, Golden-master baseline scope, Orphaned H3 handling

---

## TOC label formatting

| Option | Description | Selected |
|--------|-------------|----------|
| Plain text only | Strip all inline tags — label is just the text content. Simplest, matches typical TOC sidebars, avoids nested-markup edge cases in a small sidebar font. | |
| Preserve inline formatting | Keep code/em/strong markup in the label. More faithful to the heading but adds parsing/sanitization surface. | ✓ |

**User's choice:** Preserve inline formatting
**Notes:** PORO's entry label field must carry sanitized inline markup, not a plain string.

---

## Golden-master baseline scope

| Option | Description | Selected |
|--------|-------------|----------|
| Curated fixture set | 3-5 fixture posts covering images, tables, FAQ section, code blocks, minimal/empty-ish body. | ✓ |
| Single representative post | One fixture post with a typical mix of content. Fastest but narrower coverage. | |
| Sample real published posts | Snapshot actual posts from seeds/dev DB. Closer to real content but fragile against seed changes. | |

**User's choice:** Curated fixture set
**Notes:** Fixtures should deliberately include an FAQ-section post and a code-block-heavy post.

---

## Orphaned H3 handling

| Option | Description | Selected |
|--------|-------------|----------|
| Include it flat | List it in the TOC at the same level as H2 entries — every H2/H3 gets an entry regardless of nesting validity. | ✓ |
| Drop it | Skip H3s with no preceding H2. Keeps hierarchy strictly valid but silently omits an authored heading. | |

**User's choice:** Include it flat

---

## Claude's Discretion

- PORO class name/location, internal return-value shape
- HTML parsing library choice (Nokogiri, already available transitively)
- Exact slugification algorithm and collision-suffix format
- Where in the render pipeline anchor injection happens (must be downstream of the existing sanitizer call)
- `toc_overrides` jsonb default value and whether an index on `toc_enabled` is warranted
- Migration structure (single vs multiple)
- How to verify the Tiptap StarterKit Heading `id`-stripping blocker noted in STATE.md

## Deferred Ideas

None — discussion stayed within Phase 1 scope.
