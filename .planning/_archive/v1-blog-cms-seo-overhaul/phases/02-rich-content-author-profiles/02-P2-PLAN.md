---
phase: 02-rich-content-author-profiles
plan: P2
type: execute
wave: 2
depends_on: [P1]
files_modified:
  - package.json
  - package-lock.json
  - app/javascript/controllers/tiptap_editor_controller.js
  - app/views/admin/blogs/_form.html.erb
  - app/models/blog.rb
  - app/assets/stylesheets/application.tailwind.css
  - spec/models/blog_spec.rb
autonomous: true
requirements: [RICH-01]
tags: [tiptap, tables, stimulus, sanitization, bubble-menu]

must_haves:
  truths:
    - "Admin clicks the (now-active) Insert Table toolbar button and a 3×3 table with a header row appears at the cursor position in the editor [D-21]"
    - "While the cursor is inside any table cell, a floating BubbleMenu shows seven controls: add row above, add row below, remove row, add column left, add column right, remove column, delete table [D-20]"
    - "Each BubbleMenu button invokes the corresponding Tiptap table chain command and the table reflows immediately [D-20]"
    - "Saving a blog post with a table preserves the `<table><thead><tbody><tr><th><td>` markup through the SafeListSanitizer (no tags stripped on save) [D-07]"
    - "Visiting /blog/:slug for a saved post with a table renders the table as a real `<table>` inside `.prose prose-lg` and Tailwind Typography styles apply"
    - "An attempted save containing `<table onclick=alert(1)>` strips the `onclick` attribute but keeps the `<table>` tag [D-07]"
    - "The blog model spec asserts the sanitizer round-trips the seven new table tags and the new colspan/rowspan/scope attributes [D-07]"
  artifacts:
    - path: "package.json"
      provides: "Four new Tiptap table extension dependencies and the bubble-menu extension"
      contains: "@tiptap/extension-table"
    - path: "app/javascript/controllers/tiptap_editor_controller.js"
      provides: "Stimulus controller extended with Table/TableRow/TableCell/TableHeader extensions, BubbleMenu plugin, insertTable action, and seven table-edit actions"
      contains: "insertTable"
    - path: "app/views/admin/blogs/_form.html.erb"
      provides: "Activated Insert Table toolbar button (disabled attribute removed) + visible BubbleMenu container template inside the editor wrapper"
      contains: "click->tiptap-editor#insertTable"
    - path: "app/models/blog.rb"
      provides: "ALLOWED_TAGS extended with table/thead/tbody/tfoot/tr/th/td/colgroup/col and ALLOWED_ATTRIBUTES extended with colspan/rowspan/scope"
      contains: "table thead tbody"
    - path: "spec/models/blog_spec.rb"
      provides: "Blog model spec covering the sanitizer round-trip for table markup and removal of unsafe attributes"
      contains: "describe \"#sanitize_body\""
  key_links:
    - from: "app/views/admin/blogs/_form.html.erb"
      to: "app/javascript/controllers/tiptap_editor_controller.js#insertTable"
      via: "data-action=\"click->tiptap-editor#insertTable\" on the activated table button"
      pattern: "click->tiptap-editor#insertTable"
    - from: "app/javascript/controllers/tiptap_editor_controller.js"
      to: "@tiptap/extension-table + extension-table-row + extension-table-cell + extension-table-header"
      via: "extensions array entries Table.configure({resizable: false}), TableRow, TableCell, TableHeader"
      pattern: "TableRow"
    - from: "app/javascript/controllers/tiptap_editor_controller.js"
      to: "@tiptap/extension-bubble-menu"
      via: "BubbleMenu extension configured with a shouldShow callback returning editor.isActive('table')"
      pattern: "editor\\.isActive\\(['\"]table['\"]\\)"
    - from: "app/views/admin/blogs/_form.html.erb (Tiptap editor container)"
      to: "BubbleMenu DOM element"
      via: "Hidden inline div with data-tiptap-editor-target=\"tableMenu\" registered as the BubbleMenu element"
      pattern: "tableMenu"
    - from: "app/models/blog.rb#sanitize_body"
      to: "blogs.body column"
      via: "SafeListSanitizer tags+attributes lists now include table tags + colspan/rowspan/scope"
      pattern: "ALLOWED_TAGS"
---

<objective>
## Phase Goal

**As an** admin editor, **I want to** insert a table from the editor toolbar and edit its rows and columns via floating controls without leaving the post, **so that** I can publish structured comparison data and pricing matrices without switching tools.

This is the **second vertical slice** of Phase 2. The slice spans npm dependencies → Stimulus controller → toolbar button → BubbleMenu wiring → server-side sanitizer → published-page render. By the end of this plan, table editing is fully end-to-end.

**Purpose:** Activate the Phase 1 disabled table toolbar stub with a complete table-editing surface (RICH-01).
**Output:** Four `@tiptap/extension-table-*` packages and `@tiptap/extension-bubble-menu` installed; Tiptap Stimulus controller registers table extensions and BubbleMenu; toolbar table button is activated and inserts a 3×3 with-header table; BubbleMenu controls appear when cursor is inside a cell; Blog sanitizer accepts table markup; new model spec proves the sanitizer round-trip.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/REQUIREMENTS.md
@.planning/phases/02-rich-content-author-profiles/02-CONTEXT.md
@.planning/phases/02-rich-content-author-profiles/02-UI-SPEC.md
@.planning/phases/02-rich-content-author-profiles/02-P1-PLAN.md
@CLAUDE.md

@app/javascript/controllers/tiptap_editor_controller.js
@app/views/admin/blogs/_form.html.erb
@app/models/blog.rb
@app/assets/stylesheets/application.tailwind.css
@package.json

<interfaces>
<!-- Existing Tiptap controller (from Phase 1) — extension imports already use this shape: -->
<!--   import { Editor } from "@tiptap/core" -->
<!--   import StarterKit from "@tiptap/starter-kit" -->
<!--   import Underline from "@tiptap/extension-underline" -->
<!--   import Link from "@tiptap/extension-link" -->
<!--   static targets = ["editor", "input"] -->
<!--   updateToolbarState(editor) scans [data-tiptap-state] -->

<!-- Tiptap 3.x table API (Context7 /ueberdosis/tiptap-docs): -->
<!--   import Table from "@tiptap/extension-table" -->
<!--   import TableRow from "@tiptap/extension-table-row" -->
<!--   import TableCell from "@tiptap/extension-table-cell" -->
<!--   import TableHeader from "@tiptap/extension-table-header" -->
<!--   import BubbleMenu from "@tiptap/extension-bubble-menu" -->
<!--   Table.configure({ resizable: false }) -->
<!--   editor.chain().focus().insertTable({ rows: 3, cols: 3, withHeaderRow: true }).run() -->
<!--   editor.chain().focus().addRowBefore() / addRowAfter() / deleteRow() -->
<!--   editor.chain().focus().addColumnBefore() / addColumnAfter() / deleteColumn() -->
<!--   editor.chain().focus().deleteTable() -->
<!--   editor.isActive('table') — true when cursor is inside any table cell -->

<!-- Existing Blog sanitizer constants (from app/models/blog.rb): -->
<!--   ALLOWED_TAGS = %w[p br h1 h2 h3 h4 h5 h6 ul ol li strong em a blockquote code pre img figure figcaption] -->
<!--   ALLOWED_ATTRIBUTES = %w[href target rel src alt width height] -->
<!--   before_save :sanitize_body uses Rails::Html::SafeListSanitizer.new.sanitize -->

<!-- Existing disabled toolbar stub (in _form.html.erb around line 260) — looks like: -->
<!--   <button type="button" disabled aria-disabled="true" title="Coming soon" class="… opacity-50 cursor-not-allowed"> -->
<!--     <svg …><rect x="3" y="3" …/><path d="M3 9h18"/>…</svg>  ← table grid icon -->
<!--   </button> -->
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Install table + BubbleMenu npm packages, register the extensions in the Stimulus controller, and add insertTable + seven table-edit actions</name>
  <files>package.json, package-lock.json, app/javascript/controllers/tiptap_editor_controller.js</files>
  <read_first>
    - package.json (current Tiptap 3.x version is `^3.23.2`; pin new packages to the same major to avoid mismatched extension instances)
    - app/javascript/controllers/tiptap_editor_controller.js (current import block lines 1–7; the `extensions:` array inside `new Editor({...})` lines 14–25; the connect/disconnect lifecycle; the existing `updateToolbarState` engine)
    - .planning/phases/02-rich-content-author-profiles/02-CONTEXT.md (D-20 BubbleMenu visibility rule, D-21 default 3×3 with header row, Claude's Discretion on Table extension package set)
    - .planning/phases/02-rich-content-author-profiles/02-UI-SPEC.md (§2 Table BubbleMenu — list of seven buttons with their labels/titles and the `shouldShow` callback returning `editor.isActive('table')`; §10 Interaction Contracts — Table Insert)
  </read_first>
  <action>
Install five npm packages, all pinned to the existing Tiptap major version (`^3.23.2` matching `@tiptap/core`):
- `@tiptap/extension-table`
- `@tiptap/extension-table-row`
- `@tiptap/extension-table-cell`
- `@tiptap/extension-table-header`
- `@tiptap/extension-bubble-menu`

Run `npm install @tiptap/extension-table@^3 @tiptap/extension-table-row@^3 @tiptap/extension-table-cell@^3 @tiptap/extension-table-header@^3 @tiptap/extension-bubble-menu@^3 --save`. Confirm all five appear in `package.json` under `dependencies` and that `package-lock.json` resolves them at versions `>= 3.x`.

Edit `app/javascript/controllers/tiptap_editor_controller.js`. Do NOT rewrite the file — surgically extend it:

1. Add new imports at the top of the file (after the existing imports, before the class):
   - `Table` from `@tiptap/extension-table`
   - `TableRow` from `@tiptap/extension-table-row`
   - `TableCell` from `@tiptap/extension-table-cell`
   - `TableHeader` from `@tiptap/extension-table-header`
   - `BubbleMenu` from `@tiptap/extension-bubble-menu`

2. Add `"tableMenu"` to the `static targets = […]` array.

3. Inside `connect()`, extend the `extensions:` array passed to `new Editor({...})`. Add (in this order, after `Link.configure(...)`):
   - `Table.configure({ resizable: false })`
   - `TableRow`
   - `TableCell`
   - `TableHeader`
   - `BubbleMenu.configure({ element: this.tableMenuTarget, shouldShow: ({ editor }) => editor.isActive('table'), tippyOptions: { placement: 'top' } })`

4. Add nine new instance methods to the controller class. Each is a single-line Tiptap chain call wrapped in the same `this.editor.chain().focus().<command>().run()` shape used by existing methods like `toggleBold`:
   - `insertTable()` → `this.editor.chain().focus().insertTable({ rows: 3, cols: 3, withHeaderRow: true }).run()`
   - `addRowBefore()` → `this.editor.chain().focus().addRowBefore().run()`
   - `addRowAfter()` → `this.editor.chain().focus().addRowAfter().run()`
   - `deleteRow()` → `this.editor.chain().focus().deleteRow().run()`
   - `addColumnBefore()` → `this.editor.chain().focus().addColumnBefore().run()`
   - `addColumnAfter()` → `this.editor.chain().focus().addColumnAfter().run()`
   - `deleteColumn()` → `this.editor.chain().focus().deleteColumn().run()`
   - `deleteTable()` → `this.editor.chain().focus().deleteTable().run()`

5. In `updateToolbarState(editor)`, the existing descriptor loop already handles single-name and `name:value` descriptors — when a future `data-tiptap-state="table"` descriptor is added (in Task 2), the existing engine treats `table` as a plain name and calls `editor.isActive('table')`. Do NOT add a special branch — keep the function generic.

Do NOT change `disconnect()`, `teardown()`, or any existing method body. Do NOT remove the existing target list entries.
  </action>
  <verify>
    <automated>node -e "const p=require('./package.json').dependencies; ['@tiptap/extension-table','@tiptap/extension-table-row','@tiptap/extension-table-cell','@tiptap/extension-table-header','@tiptap/extension-bubble-menu'].forEach(n=>{if(!p[n]){console.error('Missing dep:',n);process.exit(1)}})"</automated>
    <automated>node -e "const c=require('fs').readFileSync('app/javascript/controllers/tiptap_editor_controller.js','utf8'); const need=['from \"@tiptap/extension-table\"','from \"@tiptap/extension-table-row\"','from \"@tiptap/extension-table-cell\"','from \"@tiptap/extension-table-header\"','from \"@tiptap/extension-bubble-menu\"','tableMenuTarget','insertTable({ rows: 3, cols: 3, withHeaderRow: true })','addRowBefore','addRowAfter','deleteRow','addColumnBefore','addColumnAfter','deleteColumn','deleteTable','editor.isActive(\\'table\\')']; const miss=need.filter(s=>!c.includes(s)); if(miss.length){console.error('Missing:',miss);process.exit(1)}"</automated>
    <automated>npm run build</automated>
  </verify>
  <acceptance_criteria>
    - `package.json` `dependencies` contains all five new keys (`@tiptap/extension-table`, `@tiptap/extension-table-row`, `@tiptap/extension-table-cell`, `@tiptap/extension-table-header`, `@tiptap/extension-bubble-menu`), each pinned with a `^3` major
    - `package-lock.json` resolves each new package to a 3.x version
    - Stimulus controller imports the five new extensions
    - Stimulus controller declares `static targets = [..., "tableMenu"]`
    - Stimulus controller passes `Table.configure({ resizable: false })`, `TableRow`, `TableCell`, `TableHeader`, and a configured `BubbleMenu` into the `extensions:` array
    - `BubbleMenu.configure({...})` call literally contains `element: this.tableMenuTarget`, `shouldShow:`, and `editor.isActive('table')`
    - Stimulus controller exports the nine new methods (`insertTable`, `addRowBefore`, `addRowAfter`, `deleteRow`, `addColumnBefore`, `addColumnAfter`, `deleteColumn`, `deleteTable`)
    - `insertTable` call uses literal `{ rows: 3, cols: 3, withHeaderRow: true }`
    - `npm run build` exits 0 (esbuild bundle compiles)
  </acceptance_criteria>
  <done>Table extensions + BubbleMenu are wired through Tiptap, the Stimulus controller exposes all the action methods the toolbar / BubbleMenu will call in Task 2, and the bundle builds cleanly.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Activate the table toolbar button, render the BubbleMenu container in the form, extend the Blog sanitizer for table markup, and prove the round-trip in a model spec</name>
  <files>app/views/admin/blogs/_form.html.erb, app/models/blog.rb, app/assets/stylesheets/application.tailwind.css, spec/models/blog_spec.rb</files>
  <read_first>
    - app/views/admin/blogs/_form.html.erb (the disabled stub block near the end of the toolbar — `<button type="button" disabled aria-disabled="true" title="Coming soon" class="… opacity-50 cursor-not-allowed">` with the grid-icon SVG; the editor wrapper containing `data-tiptap-editor-target="editor"`; the existing pattern for active-state classes on toolbar buttons — `text-gray-700 hover:bg-gray-100`)
    - app/models/blog.rb (full file — extend the two frozen constants on lines 5–6; do not change the rest of the class)
    - .planning/phases/02-rich-content-author-profiles/02-UI-SPEC.md (§1 Toolbar Table Button — required data-action, title, aria-label, class string; §2 Table BubbleMenu — the complete HTML structure for the seven buttons with their data-action, title, aria-label, class strings, and the `role="toolbar"` container; Security Contract §Sanitizer ALLOWED_TAGS additions and ALLOWED_ATTRIBUTES additions)
    - app/assets/stylesheets/application.tailwind.css (existing `.tiptap-editor .ProseMirror` rules — add table cell styling below them so prose styling is consistent)
    - spec/models/blog_spec.rb (this file does not exist yet — create it; copy auth/setup convention from spec/requests/admin/blogs_spec.rb if needed but model specs do not require sign-in)
  </read_first>
  <behavior>
    - The Insert Table toolbar button has `data-action="click->tiptap-editor#insertTable"`, `title="Insert table"`, `aria-label="Insert table"`, and the standard toolbar class string `inline-flex items-center justify-center h-9 w-9 rounded text-gray-700 hover:bg-gray-100 transition-colors`. The `disabled` and `aria-disabled` attributes are removed.
    - The Insert Table toolbar button additionally carries `data-tiptap-state="table"` so the active-state engine applies `bg-pink-50 text-pink-700` when the cursor is inside a table.
    - A hidden BubbleMenu container exists inside the `.tiptap-editor` wrapper with `data-tiptap-editor-target="tableMenu"`, role `toolbar`, aria-label `Table controls`, and contains seven action buttons in the order: add row above → add row below → remove row → add column left → add column right → remove column → delete table. Two visual separators sit between the row group and column group, and between the column group and delete-table button.
    - Each BubbleMenu button has `data-action="click->tiptap-editor#<methodName>"` matching the Task 1 method names; each has `title` and `aria-label` set to the same value from the UI-SPEC Copywriting table.
    - The Blog model sanitizes a body containing `<table><thead><tr><th>x</th></tr></thead><tbody><tr><td colspan="2" scope="col">y</td></tr></tbody></table>` and leaves all tags + the `colspan` and `scope` attributes intact.
    - The Blog model sanitizes a body containing `<table onclick="alert(1)"><tr><td>x</td></tr></table>` and strips the `onclick` attribute but keeps the `<table>` and `<td>` tags.
    - The compiled CSS includes table-cell styling so cells inside `.tiptap-editor .ProseMirror` have visible borders (`border-gray-300`) and minimum padding (`p-2`).
  </behavior>
  <action>
**Form (`app/views/admin/blogs/_form.html.erb`):**

1. Locate the stub group at the bottom of the toolbar — the two disabled buttons with `title="Coming soon"` and the grid-icon SVG (table icon) / picture-icon SVG (image icon). Modify the first (table) stub button only — leave the image stub alone for plan P3:
   - Remove `disabled` and `aria-disabled="true"`.
   - Remove the classes `text-gray-400 opacity-50 cursor-not-allowed`.
   - Add classes `text-gray-700 hover:bg-gray-100 transition-colors`.
   - Add attribute `data-action="click->tiptap-editor#insertTable"`.
   - Add attribute `data-tiptap-state="table"`.
   - Change `title="Coming soon"` to `title="Insert table"`.
   - Add `aria-label="Insert table"`.
   - Keep the existing grid SVG icon.

2. Inside the `<div class="tiptap-editor" data-controller="tiptap-editor">` wrapper (between the toolbar div and the editor target div), add the BubbleMenu container exactly as specified in UI-SPEC §2. Top-level container classes: `tiptap-bubble-menu bg-white border border-gray-200 rounded-md shadow-lg px-2 py-1 flex items-center gap-1`. Add `data-tiptap-editor-target="tableMenu"`, `role="toolbar"`, `aria-label="Table controls"`, and a `hidden` attribute (so the element is invisible before Tiptap promotes it). Tiptap's BubbleMenu plugin will toggle visibility based on the `shouldShow` callback.

   The seven buttons inside the BubbleMenu, in order, each using class `inline-flex items-center justify-center h-8 w-8 rounded text-gray-700 hover:bg-gray-100 transition-colors` (the destructive ones additionally have `hover:bg-red-50 hover:text-red-600`):
   1. `data-action="click->tiptap-editor#addRowBefore"` — title/aria-label "Add row above"
   2. `data-action="click->tiptap-editor#addRowAfter"` — title/aria-label "Add row below"
   3. `data-action="click->tiptap-editor#deleteRow"` — title/aria-label "Remove row" (destructive classes)
   4. (visual `<div class="w-px h-5 bg-gray-200 mx-0.5" role="separator" aria-hidden="true">`)
   5. `data-action="click->tiptap-editor#addColumnBefore"` — title/aria-label "Add column left"
   6. `data-action="click->tiptap-editor#addColumnAfter"` — title/aria-label "Add column right"
   7. `data-action="click->tiptap-editor#deleteColumn"` — title/aria-label "Remove column" (destructive classes)
   8. (visual `<div class="w-px h-5 bg-gray-200 mx-0.5" role="separator" aria-hidden="true">`)
   9. `data-action="click->tiptap-editor#deleteTable"` — title/aria-label "Delete table" (class `text-red-600 hover:bg-red-50 transition-colors` plus `inline-flex items-center justify-center h-8 w-8 rounded`)

   Each button uses any reasonable inline SVG icon at 16×16 — the icon visuals are NOT load-bearing for this plan as long as a `<svg aria-hidden="true" width="16" height="16" …>` is present.

**Blog model (`app/models/blog.rb`):**

3. Extend `ALLOWED_TAGS` (currently `%w[p br h1 h2 h3 h4 h5 h6 ul ol li strong em a blockquote code pre img figure figcaption]`) by appending the table tags **in this order**: `table`, `thead`, `tbody`, `tfoot`, `tr`, `th`, `td`, `colgroup`, `col`. Preserve the trailing `.freeze`.

4. Extend `ALLOWED_ATTRIBUTES` (currently `%w[href target rel src alt width height]`) by appending `colspan`, `rowspan`, `scope`. Preserve `.freeze`.

Do NOT change the `before_save :sanitize_body` callback, the validations, the associations, or the scopes.

**CSS (`app/assets/stylesheets/application.tailwind.css`):**

5. Append rules below the existing `.tiptap-editor .ProseMirror` blocks so table cells render visibly in the editor. Add (using plain CSS, no `@apply`):
   - `.tiptap-editor .ProseMirror table { width: 100%; border-collapse: collapse; margin: 1em 0; }`
   - `.tiptap-editor .ProseMirror th, .tiptap-editor .ProseMirror td { border: 1px solid #d1d5db; padding: 0.5em 0.75em; vertical-align: top; }`
   - `.tiptap-editor .ProseMirror th { background-color: #f9fafb; font-weight: 600; text-align: left; }`

   The published show page does NOT need extra CSS — Tailwind Typography handles table styling inside `.prose`.

**Model spec (`spec/models/blog_spec.rb`) — NEW file:**

6. Create the file with `require 'rails_helper'` and `RSpec.describe Blog, type: :model do … end`. Inside the describe, add a `describe "#sanitize_body" do … end` group with two examples:

   - Example 1 "preserves table markup and table-specific attributes":
     - `body = '<table><thead><tr><th>H</th></tr></thead><tbody><tr><td colspan="2" scope="col">x</td></tr></tbody></table>'`
     - `blog = build(:blog, body: body)`
     - `blog.save!`
     - `expect(blog.body).to include('<table>')`
     - `expect(blog.body).to include('<thead>')`, `'<tbody>'`, `'<th>'`, `'<td'`
     - `expect(blog.body).to include('colspan="2"')`
     - `expect(blog.body).to include('scope="col"')`

   - Example 2 "strips disallowed attributes on table tags":
     - `body = '<table onclick="alert(1)"><tr><td>x</td></tr></table>'`
     - `blog = build(:blog, body: body)`
     - `blog.save!`
     - `expect(blog.body).not_to include('onclick')`
     - `expect(blog.body).to include('<table>')`
     - `expect(blog.body).to include('<td>x</td>')`
  </action>
  <verify>
    <automated>grep -q 'click->tiptap-editor#insertTable' app/views/admin/blogs/_form.html.erb</automated>
    <automated>grep -q 'data-tiptap-editor-target="tableMenu"' app/views/admin/blogs/_form.html.erb</automated>
    <automated>node -e "const c=require('fs').readFileSync('app/views/admin/blogs/_form.html.erb','utf8'); const need=['click->tiptap-editor#addRowBefore','click->tiptap-editor#addRowAfter','click->tiptap-editor#deleteRow','click->tiptap-editor#addColumnBefore','click->tiptap-editor#addColumnAfter','click->tiptap-editor#deleteColumn','click->tiptap-editor#deleteTable','aria-label=\"Table controls\"']; const miss=need.filter(s=>!c.includes(s)); if(miss.length){console.error('Missing:',miss);process.exit(1)}"</automated>
    <automated>grep -E 'ALLOWED_TAGS.*table.*thead.*tbody' app/models/blog.rb</automated>
    <automated>grep -E 'ALLOWED_ATTRIBUTES.*colspan.*rowspan.*scope' app/models/blog.rb</automated>
    <automated>bundle exec rspec spec/models/blog_spec.rb</automated>
    <automated>npm run build:css</automated>
  </verify>
  <acceptance_criteria>
    - The activated table toolbar button in `_form.html.erb` carries the literal substrings `click->tiptap-editor#insertTable`, `title="Insert table"`, `aria-label="Insert table"`, and `data-tiptap-state="table"`; the `disabled` and `aria-disabled` attributes are removed from that specific button
    - The BubbleMenu container exists inside the `.tiptap-editor` wrapper with `data-tiptap-editor-target="tableMenu"`, `role="toolbar"`, `aria-label="Table controls"`, and a `hidden` attribute
    - All seven BubbleMenu button `data-action` strings are present in the form file (matching the eight method names from Task 1 except `insertTable`)
    - `Blog::ALLOWED_TAGS` includes all nine new tags: `table`, `thead`, `tbody`, `tfoot`, `tr`, `th`, `td`, `colgroup`, `col`
    - `Blog::ALLOWED_ATTRIBUTES` includes `colspan`, `rowspan`, `scope`
    - `bundle exec rspec spec/models/blog_spec.rb` exits 0 with two passing examples
    - Round-trip test verifies sanitized body contains `<table>`, `<thead>`, `<tbody>`, `<th>`, `<td`, `colspan="2"`, `scope="col"`
    - Strip test verifies sanitized body does NOT contain `onclick` but DOES contain `<table>` and `<td>x</td>`
    - `npm run build:css` exits 0 and the compiled stylesheet contains the table-cell rule
  </acceptance_criteria>
  <done>Toolbar table button is live, BubbleMenu DOM is rendered inside the editor wrapper, sanitizer accepts table markup and required attributes, model spec proves both the round-trip and the unsafe-attribute strip, and the editor CSS renders cells with visible borders.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Tiptap editor (browser) → blogs.body (Rails) | Admin-authored HTML crosses the sanitizer on every save |
| blogs.body (DB) → show page render | Stored HTML re-sanitized at render with `sanitize @blog.body, tags: ALLOWED_TAGS, attributes: ALLOWED_ATTRIBUTES` |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-02-P2-01 | Tampering (XSS via table attributes) | Blog#sanitize_body | mitigate | ALLOWED_ATTRIBUTES additions are strictly `colspan`, `rowspan`, `scope` — no `style`, `onclick`, or other event handlers added; spec asserts `onclick` is stripped |
| T-02-P2-02 | Tampering (XSS via table-related new tags) | SafeListSanitizer | mitigate | Only HTML5 structural table tags whitelisted; no `<script>`, `<iframe>`, `<form>`, or interactive elements added; spec asserts a structural-only body round-trips intact |
| T-02-P2-03 | Information Disclosure (CSRF on form post) | admin/blogs#update | accept | Rails CSRF protection already covers admin/blogs form posts via the existing `authenticate_user!` + admin layout; no new endpoints introduced |
| T-02-P2-04 | Denial of Service (huge inserted tables) | Tiptap editor | accept | Default insert is 3×3; admin can grow tables manually but admin is trusted (`ensure_admin!` gate). Not a public input surface. |
</threat_model>

<verification>
- npm install succeeds and lockfile resolves all five new Tiptap packages
- esbuild bundle compiles with the new imports
- Admin form renders the activated table button and the hidden BubbleMenu DOM
- Model spec passes both examples (round-trip + strip)
- CSS compiles with the new table-cell styling rule
</verification>

<success_criteria>
- Phase Success Criterion #1 satisfied: "Admin can insert a table from the toolbar and add or remove rows and columns without leaving the editor"
- Requirement RICH-01 covered end-to-end (npm → controller → DOM → sanitizer → render)
- Sanitizer extension does NOT introduce any XSS vector — spec asserts `onclick` stripping
</success_criteria>

<output>
After completion, create `.planning/phases/02-rich-content-author-profiles/02-P2-SUMMARY.md` summarizing: package versions installed, controller extension surface, BubbleMenu DOM placement, sanitizer extension list, model spec proofs, CSS additions.
</output>
</output>
