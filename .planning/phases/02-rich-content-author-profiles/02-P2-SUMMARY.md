---
phase: 02-rich-content-author-profiles
plan: P2
subsystem: blog-cms
tags: [tiptap, tables, stimulus, sanitization, bubble-menu, tdd]
dependency_graph:
  requires: [P1]
  provides: [table-editing, BubbleMenu, table-sanitizer-allowlist]
  affects:
    - app/javascript/controllers/tiptap_editor_controller.js
    - app/views/admin/blogs/_form.html.erb
    - app/models/blog.rb
    - app/assets/stylesheets/application.tailwind.css
    - spec/models/blog_spec.rb
    - package.json
    - package-lock.json
tech_stack:
  added:
    - "@tiptap/extension-table@^3.23.5"
    - "@tiptap/extension-table-row@^3.23.5"
    - "@tiptap/extension-table-cell@^3.23.5"
    - "@tiptap/extension-table-header@^3.23.5"
    - "@tiptap/extension-bubble-menu@^3.23.5"
  patterns:
    - Tiptap named-import pattern for extension-table (no default export)
    - BubbleMenu shouldShow callback using editor.isActive('table')
    - SafeListSanitizer allowlist extension for structural HTML tags
key_files:
  created:
    - spec/models/blog_spec.rb
  modified:
    - package.json
    - package-lock.json
    - app/javascript/controllers/tiptap_editor_controller.js
    - app/views/admin/blogs/_form.html.erb
    - app/models/blog.rb
    - app/assets/stylesheets/application.tailwind.css
decisions:
  - "@tiptap/extension-table uses named export { Table } not default — all four table packages upgraded to 3.23.5 to resolve peer dependency conflict with @tiptap/extension-bubble-menu"
  - "All existing Tiptap packages upgraded from 3.23.2 to 3.23.5 to stay on consistent minor version"
  - "BubbleMenu container placed between toolbar and editor target div inside .tiptap-editor wrapper"
metrics:
  duration_minutes: 20
  completed_at: "2026-05-19T21:00:00Z"
  tasks_completed: 2
  files_changed: 7
---

# Phase 02 Plan P2: Tiptap Table Editing — Summary

**One-liner:** Full table-editing slice via five Tiptap npm packages, eight Stimulus action methods, an activated toolbar button, a hidden BubbleMenu with seven row/column/delete controls, a SafeListSanitizer allowlist extension for nine table tags and three attributes, and two model specs proving the sanitizer round-trip.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Install table + BubbleMenu packages, wire Stimulus controller | 32bb0b1 | package.json, package-lock.json, tiptap_editor_controller.js |
| 2 (RED) | Failing spec for table sanitizer round-trip and attribute stripping | fb8657f | spec/models/blog_spec.rb |
| 2 (GREEN) | Activate toolbar button, BubbleMenu DOM, sanitizer extension, table CSS | de4e013 | _form.html.erb, blog.rb, application.tailwind.css |

## What Was Built

### npm Packages

Five Tiptap packages installed at `^3.23.5`:
- `@tiptap/extension-table` — provides `Table`, `TableRow`, `TableCell`, `TableHeader`, `TableView` as named exports
- `@tiptap/extension-table-row` — default export `TableRow`
- `@tiptap/extension-table-cell` — default export `TableCell`
- `@tiptap/extension-table-header` — default export `TableHeader`
- `@tiptap/extension-bubble-menu` — named export `BubbleMenu`

Existing Tiptap packages upgraded from `3.23.2` → `3.23.5` to resolve peer dependency conflict introduced by `@tiptap/extension-bubble-menu@3.23.5`.

### Stimulus Controller Extension

`app/javascript/controllers/tiptap_editor_controller.js` extended:
- Added five imports: `{ Table }` from `@tiptap/extension-table`, `TableRow`, `TableCell`, `TableHeader` (default imports), `{ BubbleMenu }` from `@tiptap/extension-bubble-menu`
- `static targets` extended with `"tableMenu"`
- `extensions:` array extended with `Table.configure({ resizable: false })`, `TableRow`, `TableCell`, `TableHeader`, and `BubbleMenu.configure({ element: this.tableMenuTarget, shouldShow: ({ editor }) => editor.isActive('table'), tippyOptions: { placement: 'top' } })`
- Eight new action methods added: `insertTable` (3×3 with header row), `addRowBefore`, `addRowAfter`, `deleteRow`, `addColumnBefore`, `addColumnAfter`, `deleteColumn`, `deleteTable`
- No existing methods modified; `updateToolbarState` generic engine handles `data-tiptap-state="table"` without changes

### Admin Blog Form

`app/views/admin/blogs/_form.html.erb` changes:
- Disabled table stub button activated: `disabled` and `aria-disabled="true"` removed; `text-gray-400 opacity-50 cursor-not-allowed` removed; `data-action="click->tiptap-editor#insertTable"`, `data-tiptap-state="table"`, `title="Insert table"`, `aria-label="Insert table"`, `text-gray-700 hover:bg-gray-100 transition-colors` added
- BubbleMenu container added between toolbar and editor target div with `data-tiptap-editor-target="tableMenu"`, `role="toolbar"`, `aria-label="Table controls"`, `hidden` attribute; contains seven action buttons with data-action, title, aria-label; two visual separators between row group / column group and column group / delete button; destructive buttons (deleteRow, deleteColumn, deleteTable) use red hover classes

### Blog Model Sanitizer

`app/models/blog.rb` `ALLOWED_TAGS` extended:
- Added: `table`, `thead`, `tbody`, `tfoot`, `tr`, `th`, `td`, `colgroup`, `col`

`ALLOWED_ATTRIBUTES` extended:
- Added: `colspan`, `rowspan`, `scope`

No other model changes. `sanitize_body` callback, validations, associations, and scopes unchanged.

### CSS

`app/assets/stylesheets/application.tailwind.css` three rules appended:
- `.tiptap-editor .ProseMirror table { width: 100%; border-collapse: collapse; margin: 1em 0; }`
- `.tiptap-editor .ProseMirror th, .tiptap-editor .ProseMirror td { border: 1px solid #d1d5db; padding: 0.5em 0.75em; vertical-align: top; }`
- `.tiptap-editor .ProseMirror th { background-color: #f9fafb; font-weight: 600; text-align: left; }`

### Model Spec

`spec/models/blog_spec.rb` created (new file). Two examples in `describe "#sanitize_body"`:
1. Round-trip: verifies `<table>`, `<thead>`, `<tbody>`, `<th>`, `<td`, `colspan="2"`, `scope="col"` all survive sanitization
2. Strip: verifies `onclick` removed but `<table>` and `<td>x</td>` preserved

Both examples pass.

## TDD Gate Compliance

- RED commit: `fb8657f` — `test(02-P2): add failing spec for table sanitizer round-trip and attribute stripping`
- GREEN commit: `de4e013` — `feat(02-P2): activate table toolbar button, add BubbleMenu DOM, extend sanitizer, add table CSS`

RED gate confirmed: both specs failed before sanitizer changes (sanitizer stripped all table tags, body reduced to text content only).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Resolved peer dependency conflict for @tiptap/extension-table import**
- **Found during:** Task 1
- **Issue:** `@tiptap/extension-table@^3.23.5` has no default export (`dist/index.js` is pure named ESM). esbuild rejected `import Table from "@tiptap/extension-table"` with "No matching export" error.
- **Fix:** Changed to named import `import { Table } from "@tiptap/extension-table"`. Likewise `BubbleMenu` from `@tiptap/extension-bubble-menu` uses `{ BubbleMenu }` named import. `TableRow`, `TableCell`, `TableHeader` from their individual packages retain default imports (those packages do have defaults).
- **Files modified:** `app/javascript/controllers/tiptap_editor_controller.js`
- **Commit:** 32bb0b1

**2. [Rule 3 - Blocking] Upgraded all Tiptap packages from 3.23.2 to 3.23.5**
- **Found during:** Task 1 npm install
- **Issue:** `@tiptap/extension-bubble-menu@^3` resolved to 3.23.5 which requires `@tiptap/core@3.23.5`, conflicting with installed `3.23.2`. npm refused to install.
- **Fix:** Upgraded all existing Tiptap packages (`@tiptap/core`, `@tiptap/starter-kit`, `@tiptap/extension-link`, `@tiptap/extension-underline`, `@tiptap/extensions`) to `^3.23.5` in the same install command. All remain within the `^3` semver range — no breaking change.
- **Files modified:** `package.json`, `package-lock.json`
- **Commit:** 32bb0b1

## Threat Surface Scan

T-02-P2-01 mitigated: `ALLOWED_ATTRIBUTES` additions are strictly `colspan`, `rowspan`, `scope` — no event handlers or `style` added. Model spec asserts `onclick` is stripped.

T-02-P2-02 mitigated: Only structural table tags whitelisted; no `<script>`, `<iframe>`, `<form>`, or interactive elements. Model spec asserts round-trip integrity.

No new network endpoints or auth paths introduced. All changes are admin-only (Tiptap editor in admin form; Blog model already behind `ensure_admin!`).

## Self-Check: PASSED

Files verified present:
- `spec/models/blog_spec.rb` — FOUND
- `app/javascript/controllers/tiptap_editor_controller.js` — FOUND (modified)
- `app/views/admin/blogs/_form.html.erb` — FOUND (modified)
- `app/models/blog.rb` — FOUND (modified)
- `app/assets/stylesheets/application.tailwind.css` — FOUND (modified)
- `package.json` — FOUND (modified)

Commits verified in git log: 32bb0b1, fb8657f, de4e013 — all present.
