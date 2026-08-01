---
phase: quick
plan: 260522-9sh
subsystem: tiptap-editor
tags: [tiptap, image-upload, ux, overlay, css]
dependency_graph:
  requires: []
  provides: [tiptap-upload-overlay, tiptap-error-banner]
  affects: [app/javascript/controllers/tiptap_editor_controller.js, app/assets/stylesheets/application.tailwind.css]
tech_stack:
  added: []
  patterns: [DOM overlay pattern (absolute-positioned non-editable div appended to Stimulus root)]
key_files:
  created: []
  modified:
    - app/javascript/controllers/tiptap_editor_controller.js
    - app/assets/stylesheets/application.tailwind.css
decisions:
  - Upload feedback moved out of ProseMirror document nodes into DOM overlays on .tiptap-editor wrapper
  - textContent (not innerHTML) used for all overlay text to prevent HTML injection
  - _errorBannerTimeout cleared in disconnect() to prevent stale callbacks after Stimulus teardown
metrics:
  duration: "~5 minutes"
  completed: "2026-05-22"
  tasks: 2
  files: 2
---

# Phase quick Plan 260522-9sh: Fix Image Upload Placeholder to Overlay Summary

**One-liner:** Replaced in-ProseMirror insertContent feedback with absolute-positioned DOM overlays on the `.tiptap-editor` Stimulus root element, keeping editor state clean.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Replace insertContent calls with DOM overlay helpers | 8113e48 | tiptap_editor_controller.js |
| 2 | Update CSS — remove inline placeholder rule, add overlay rules | 7851ac3 | application.tailwind.css |

## What Changed

### Task 1 — JS controller (`tiptap_editor_controller.js`)

- **Removed** `uploadId` / `Math.random()` / `placeholderHtml` / `insertContent` from `uploadImage()`.
- **Added** `_showUploadOverlay()`: creates a `div.tiptap-upload-overlay` with `contenteditable="false"`, an SVG spinner, and a `<span>` with `textContent = 'Uploading image…'`. Appended to `this.element`. Idempotent (returns early if overlay already exists).
- **Added** `_removeUploadOverlay()`: removes the overlay div and nulls the reference.
- **Rewrote** `showInlineError(message)`: creates a `div.tiptap-error-banner` with `contenteditable="false"` and `textContent = message`, appended to `this.element`. Auto-removes after 4 s via `setTimeout`; timeout ID stored as `this._errorBannerTimeout`.
- **Updated** `disconnect()`: calls `_removeUploadOverlay()` and clears `_errorBannerTimeout` to prevent stale callbacks after Stimulus teardown.

### Task 2 — CSS (`application.tailwind.css`)

- **Removed** `.tiptap-editor .ProseMirror .tiptap-image-placeholder` rule block (inline content styling, no longer used).
- **Added** `.tiptap-upload-overlay`: `position: absolute; inset: 0; display: flex; align-items: center; justify-content: center; gap: 0.5rem; background-color: rgba(255,255,255,0.85); color: #6b7280; font-size: 0.875rem; border-radius: inherit; z-index: 30; pointer-events: none;`
- **Added** `.tiptap-error-banner`: `position: absolute; top: 0; left: 0; right: 0; padding: 0.5rem 0.75rem; background-color: #fee2e2; color: #991b1b; font-size: 0.875rem; border-radius: 0.375rem 0.375rem 0 0; z-index: 31; pointer-events: none;`

Both overlays use `pointer-events: none` so they never block editor interaction. `.tiptap-editor` already has `position: relative` from Phase 2, so absolute positioning works correctly.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

None — no new network endpoints or auth paths introduced. Threat model items T-9sh-01 and T-9sh-02 are both mitigated: `textContent` used throughout (no innerHTML), error message strings are call-site literals.

## Build Verification

`npm run build` completed successfully — 670.5 kb bundle output in 108 ms. No esbuild errors.

## Self-Check: PASSED

- [x] `app/javascript/controllers/tiptap_editor_controller.js` exists and modified
- [x] `app/assets/stylesheets/application.tailwind.css` exists and modified
- [x] Commit 8113e48 exists
- [x] Commit 7851ac3 exists
- [x] `insertContent` absent from JS file
- [x] `_showUploadOverlay`, `_removeUploadOverlay`, `tiptap-upload-overlay`, `tiptap-error-banner` all present
- [x] `.tiptap-image-placeholder` rule removed from CSS
- [x] Bundle compiles without errors
