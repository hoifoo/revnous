---
phase: 01-editor-foundation
plan: "02"
subsystem: editor
tags: [tiptap, toolbar, sticky, json-ld, security, underline, link, blockquote, code]
dependency_graph:
  requires: [01-01]
  provides: [full Phase 1 toolbar, SEC-02 fix]
  affects:
    - app/javascript/controllers/tiptap_editor_controller.js
    - app/views/admin/blogs/_form.html.erb
    - app/helpers/application_helper.rb
tech_stack:
  added: ["@tiptap/extension-underline", "@tiptap/extension-link"]
  patterns: [Stimulus toolbar active-state engine, json_escape for JSON-LD safety]
key_files:
  created: []
  modified:
    - app/javascript/controllers/tiptap_editor_controller.js
    - app/views/admin/blogs/_form.html.erb
    - app/helpers/application_helper.rb
decisions:
  - "Expanded scope: all available Tiptap tools included (Underline, Code, CodeBlock, Blockquote, HR) per user approval"
  - "Prose scoping rule already present from post-01-01 fix — no change needed to application.tailwind.css"
  - "Toolbar group order: Undo/Redo | H1-H6 | Bold/Italic/Underline/Strike | Code/CodeBlock | Blockquote/HR | BulletList/OrderedList | Link | Table(stub)/Image(stub)"
  - "HR and Undo/Redo buttons have no data-tiptap-state (momentary/insert — no active state concept)"
metrics:
  duration: "~23 minutes"
  completed: "2026-05-13"
  tasks_completed: 3
  tasks_total: 4
  files_created: 0
  files_modified: 3
---

# Phase 1 Plan 02: Full Toolbar + SEC-02 Fix Summary

**One-liner:** Full Phase 1 Tiptap toolbar with 21 buttons across 8 groups (including Underline, Code, Blockquote, HR from user-approved scope expansion) and JSON-LD `</script>`-injection vulnerability closed via `json_escape`.

## What Was Implemented

### Task 1 — Extend Tiptap Stimulus controller (commit b7fab58)

Added imports:
- `import Underline from "@tiptap/extension-underline"`
- `import Link from "@tiptap/extension-link"`

Added to `extensions` array in `connect()`:
- `Underline`
- `Link.configure({ openOnClick: false })`

Added action methods (all following the `chain().focus().run()` pattern):
- `toggleItalic()`, `toggleStrike()`, `toggleUnderline()`
- `toggleCode()`, `toggleCodeBlock()`, `toggleBlockquote()`
- `setHorizontalRule()` — insert action, no active state
- `setLink(event)` — `window.prompt` for URL, handles cancel (null), empty string (unsetLink), valid URL (extendMarkRange + setLink)
- `undo()`, `redo()`

`updateToolbarState` updated to use `el` variable name (matching plan spec); already handled all descriptor vocabulary including `heading:N`, `bold`, `italic`, `strike`, `bulletList`, `orderedList`, `link` — now also handles `underline`, `code`, `codeBlock`, `blockquote` (the engine is descriptor-driven, so new values work automatically).

### Task 2 — Full toolbar markup (commit 5e64052)

Replaced the minimal 5-button toolbar with a complete 21-button toolbar organized into 8 groups separated by `w-px h-6 bg-gray-200 mx-1` dividers:

| Group | Buttons | data-tiptap-state |
|-------|---------|-------------------|
| History | Undo, Redo | none (momentary) |
| Heading | H1, H2, H3, H4, H5, H6 | `heading:1` through `heading:6` |
| Inline | Bold, Italic, Underline, Strike | `bold`, `italic`, `underline`, `strike` |
| Code | Inline Code, Code Block | `code`, `codeBlock` |
| Block | Blockquote, HR | `blockquote` / none (insert) |
| List | Bullet List, Ordered List | `bulletList`, `orderedList` |
| Link | Link | `link` |
| Stub | Table (disabled), Image (disabled) | none |

All stateful buttons carry `aria-pressed="false"` initially; `updateToolbarState` toggles `bg-pink-50 text-pink-700` and `aria-pressed` on selection/transaction events.

Heading buttons rendered via ERB loop `[1, 2, 3, 4, 5, 6].each do |level|` — generates 6 `data-tiptap-state="heading:<level>"` buttons at render time.

Disabled stubs: `disabled`, `aria-disabled="true"`, `title="Coming soon"`, `cursor-not-allowed opacity-50 text-gray-400` — no `data-action`, no `data-tiptap-state`.

**Prose scoping CSS decision:** The `.tiptap-editor .ProseMirror { @apply prose max-w-none ... }` rule was already added to `application.tailwind.css` as a post-Plan-01 fix (commit 9ced457). No change needed.

### Task 3 — SEC-02 JSON-LD injection fix (commit be1d2ee)

Made exactly 4 substitutions in `app/helpers/application_helper.rb`:

Before: `content_tag :script, schema.to_json.html_safe, type: "application/ld+json"`
After: `content_tag :script, json_escape(schema.to_json), type: "application/ld+json"`

Applied to:
1. `render_organization_schema` (line 61)
2. `render_article_schema` (line 87)
3. `render_product_schema` (line 111)
4. `render_breadcrumbs_schema` (line 130)

`json_escape` is from `ERB::Util` (auto-included in `ActionView::Helpers`) — no require needed. It escapes `<`, `>`, `&`, U+2028, U+2029 as Unicode sequences (`<` etc.) which are valid JSON string escapes and prevent `</script>` in admin-supplied fields from terminating the script tag early.

### Task 4 — Checkpoint (awaiting manual verification)

Manual verification required before plan completion. See checkpoint details below.

## Deviations from Plan

### Scope Expansion (User-Approved)

**Deviation: Additional Tiptap tools added per user-approved expanded scope**
- **Authorized by:** User approval in `<expanded_scope>` directive
- **Added beyond plan spec:** `Underline` extension, `Link` extension, `toggleUnderline`, `toggleCode`, `toggleCodeBlock`, `toggleBlockquote`, `setHorizontalRule` methods
- **Additional toolbar groups:** Code group (inline code + code block), Block group (blockquote + HR)
- **Additional imports:** `@tiptap/extension-underline`, `@tiptap/extension-link`
- **Files modified:** `tiptap_editor_controller.js`, `_form.html.erb`

### CSS Decision

**Prose scoping rule already present from post-01-01 fix — no change needed.**

The rule `.tiptap-editor .ProseMirror { @apply prose max-w-none min-h-[400px] px-4 py-3 outline-none; }` was committed in 9ced457 after Plan 01's operator approval checkpoint. No CSS changes required in this plan.

## Known Stubs

The Table and Image toolbar buttons are intentionally disabled stubs with `title="Coming soon"`. These will be implemented in a future phase (image upload via ActiveStorage, table extension). They are visible in the toolbar at 50% opacity with a `not-allowed` cursor — this is the designed behavior for Phase 1.

## Threat Flags

No new threat surface beyond what is in the plan's threat model.

- T-01-07: `json_escape(schema.to_json)` applied to all four helpers (FIXED)
- T-01-08: `setLink` defers to Tiptap's Link extension URL filter; `javascript:` rejected client-side; server-side `sanitize_body` strips on save (defense in depth)
- T-01-09: SVGs are static template markup — no user input (ACCEPT)
- T-01-10: `window.prompt` is browser-native, undo history bounded by StarterKit defaults (ACCEPT)

## Self-Check: PASSED

| Item | Status |
|------|--------|
| app/javascript/controllers/tiptap_editor_controller.js | FOUND |
| app/views/admin/blogs/_form.html.erb | FOUND |
| app/helpers/application_helper.rb | FOUND |
| commit b7fab58 (Task 1 — controller) | FOUND |
| commit 5e64052 (Task 2 — toolbar markup) | FOUND |
| commit be1d2ee (Task 3 — SEC-02 fix) | FOUND |
| json_escape count = 4 | VERIFIED |
| No .to_json.html_safe remaining | VERIFIED |
| npm run build — exit 0 | VERIFIED |
| npm run build:css — exit 0 | VERIFIED |
| All data-tiptap-state values present in form | VERIFIED |
| 2 disabled stubs with title="Coming soon" | VERIFIED |
| 7 group dividers | VERIFIED |
