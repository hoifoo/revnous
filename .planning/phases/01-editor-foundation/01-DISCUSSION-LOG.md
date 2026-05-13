# Phase 1: Editor Foundation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-13
**Phase:** 1-Editor Foundation
**Areas discussed:** Content migration approach, ActionText removal scope, Phase 1 toolbar scope, WYSIWYG heading styles

---

## Content Migration Approach

| Option | Description | Selected |
|--------|-------------|----------|
| Rake task | Schema migration adds column; separate rake task backfills. Re-runnable. | ✓ |
| Data script in migration | Backfill inline in migration. Atomic but blocks if any post fails. | |
| Background job on first boot | Posts show blank editor until job runs. Complex. | |

**User's choice:** Rake task

---

| Option | Description | Selected |
|--------|-------------|----------|
| Strip silently | Nokogiri removes `<action-text-attachment>` nodes; text preserved. | ✓ |
| Replace with placeholder | Swap attachment with `[image removed]` marker. | |
| Abort if any found | Halt migration if any post has attachment nodes. | |

**User's choice:** Strip silently

---

| Option | Description | Selected |
|--------|-------------|----------|
| Clean cutover | Remove `has_rich_text :content`; old rows stay in DB but unreferenced. | (Claude's decision) |
| Dual-read period | Keep ActionText readable alongside `blogs.body` temporarily. | |

**User's choice:** You decide → **Claude chose:** Clean cutover — avoids dual-read complexity; old `action_text_rich_texts` rows are a safe rollback artifact.

---

## ActionText Removal Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Blog model only | Remove `has_rich_text` + JS imports; keep gems. | (Claude's decision) |
| Full removal | Remove has_rich_text + gems + JS imports entirely. | |

**User's choice:** You decide → **Claude chose:** Remove `has_rich_text` from Blog model + remove `trix` npm + remove ActionText/Trix JS imports from `application.js`. Keep `actiontext` Rails gem (bundled inside Rails 8, not independently removable).

---

## Phase 1 Toolbar Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal Phase 1 only | H1–H6, bold, italic, lists, link only. Phase 2 adds table/image later. | |
| Full toolbar with Phase 2 stubs | Include table + image buttons now as disabled stubs. Avoids rework. | ✓ |

**User's choice:** Full toolbar with Phase 2 stubs

---

| Option | Description | Selected |
|--------|-------------|----------|
| Greyed out, no tooltip | Opacity-50, cursor-not-allowed. No hover text. | |
| Greyed out with "Coming soon" tooltip | Shows tooltip on hover. | ✓ |
| Hidden until Phase 2 | Don't render stubs; structure JS for easy slot-in. | |

**User's choice:** Greyed out with "Coming soon" tooltip

---

## WYSIWYG Heading Styles

| Option | Description | Selected |
|--------|-------------|----------|
| Apply prose classes to editor div | `prose prose-lg` on `.ProseMirror` div. Zero custom CSS. | (Claude's decision) |
| Custom scoped CSS block | Write `.tiptap-editor h1 {}` block mirroring Typography values. | |

**User's choice:** You decide → **Claude chose:** Apply `prose prose-lg` directly to `.ProseMirror` div. Researcher to verify Tailwind CSS 4 Typography scoping behavior.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Sticky at top of editor container | `position: sticky` with top offset matching admin navbar. | ✓ |
| Fixed to top of viewport | `position: fixed`. Could overlap admin navbar. | |

**User's choice:** Sticky at top of editor container

---

## Claude's Discretion

- **Migration cutover strategy:** Clean cutover chosen — no dual-read period.
- **ActionText gem:** Rails gem not removable; trix npm removed from package.json.
- **WYSIWYG styling:** `prose prose-lg` on `.ProseMirror`; fallback scoping if needed.

## Deferred Ideas

None — discussion stayed within Phase 1 scope.
