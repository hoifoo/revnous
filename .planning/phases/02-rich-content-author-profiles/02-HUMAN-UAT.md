---
status: partial
phase: 02-rich-content-author-profiles
source: [02-VERIFICATION.md]
started: 2026-05-22T00:00:00Z
updated: 2026-05-22T00:00:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Tiptap BubbleMenu appears when cursor is inside a table cell
expected: Click "Insert Table" in the admin blog editor toolbar → a 3×3 table with header row appears at the cursor. Click inside any table cell → a floating BubbleMenu appears above the cell with 7 controls: "Add row above", "Add row below", "Remove row", "Add column left", "Add column right", "Remove column", "Delete table". Each button performs the expected table operation.
result: [pending]

### 2. Image upload via click and drag-and-drop works end-to-end
expected: Click the image toolbar button → OS file picker opens filtered to images. Select an image → "Uploading image…" placeholder appears → alt text prompt appears → image inserts inline with `src` pointing to `/rails/active_storage/blobs/redirect/...`. Also: drag an image file onto the editor body → same flow. Dragging a non-image file shows an inline error. Saving the post preserves the `<img>` tag with `src`, `alt`, and `width` attributes on the published page.
result: [pending]

### 3. Image resize handles appear and drag correctly
expected: Click an inserted image in the editor → pink ring outline appears around the image + 4 corner handles appear. Drag a corner handle → image resizes live, minimum 64px width. Handles disappear when clicking outside the image.
result: [pending]

### 4. Author card renders correctly on the published page
expected: Edit a blog post in admin, select an admin user from the "Author Profile" dropdown, save. Visit `/blog/:slug` → author card renders below the post content with: avatar (or initials placeholder), full name, job title, bio, conditional LinkedIn/Twitter links. When author_id is null but legacy "Author" text is set → plain-text byline in meta row, no card. JSON-LD source contains `"@type":"Person"` with correct name/url/sameAs.
result: [pending]

## Summary

total: 4
passed: 0
issues: 0
pending: 4
skipped: 0
blocked: 0

## Gaps
