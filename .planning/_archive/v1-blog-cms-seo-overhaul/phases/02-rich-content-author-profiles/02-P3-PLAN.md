---
phase: 02-rich-content-author-profiles
plan: P3
type: execute
wave: 3
depends_on: [P2]
files_modified:
  - package.json
  - package-lock.json
  - app/javascript/controllers/tiptap_editor_controller.js
  - app/views/admin/blogs/_form.html.erb
  - app/models/blog.rb
  - app/assets/stylesheets/application.tailwind.css
  - spec/models/blog_spec.rb
autonomous: true
requirements: [RICH-02]
tags: [tiptap, image-upload, active-storage, direct-upload, stimulus, resize]

must_haves:
  truths:
    - "Admin clicks the (now-active) Insert Image toolbar button and the OS native file picker opens, filtered to images [D-01]"
    - "Admin can drag-and-drop an image file onto the editor body and the upload proceeds without using the toolbar button [D-01]"
    - "During upload, an in-editor placeholder (spinner + 'Uploading image...' text) shows at the cursor; on success it is replaced with `<img src=... alt=... width=...>`; on cancel/error it is removed [D-02]"
    - "Before injecting `<img>`, a window.prompt asks for alt text; cancelling aborts injection; an empty string injects `alt=\"\"` [D-04]"
    - "Uploaded image is stored via ActiveStorage direct upload to /rails/active_storage/direct_uploads and the injected src is the resulting `rails_blob_path(blob)` (relative URL) [D-03, D-06]"
    - "Saving the post preserves the injected `<img>` markup with its `src`, `alt`, and `width` attributes through the SafeListSanitizer [D-05, D-07]"
    - "Dragging non-image files over the drop zone shows an inline error message and does NOT initiate upload [D-01]"
    - "Drop zone gains pink dashed border state during dragover and reverts on dragleave or successful drop [D-01]"
    - "Model spec asserts the sanitizer keeps `<img src alt width>` and strips disallowed attributes such as `onerror` [D-07]"
  artifacts:
    - path: "package.json"
      provides: "@tiptap/extension-image and @rails/activestorage installed"
      contains: "@tiptap/extension-image"
    - path: "app/javascript/controllers/tiptap_editor_controller.js"
      provides: "Image extension registered, triggerImageUpload action, imageFileInput change handler, dragover/dragleave/drop event listeners on editor container, DirectUpload integration, placeholder insert/replace/remove logic, alt-text prompt, and resize-handle mouse listeners on selected <img>"
      contains: "triggerImageUpload"
    - path: "app/views/admin/blogs/_form.html.erb"
      provides: "Activated image toolbar button + hidden file input + drag-and-drop visual class hooks on editor wrapper"
      contains: "click->tiptap-editor#triggerImageUpload"
    - path: "app/models/blog.rb"
      provides: "ALLOWED_ATTRIBUTES on img sanitizer already includes width (from P2 carry-over verification — no change required here unless missing)"
      contains: "width"
    - path: "spec/models/blog_spec.rb"
      provides: "New examples covering <img> round-trip and onerror attribute strip"
      contains: "<img src"
  key_links:
    - from: "app/views/admin/blogs/_form.html.erb (toolbar image button)"
      to: "app/javascript/controllers/tiptap_editor_controller.js#triggerImageUpload"
      via: "data-action=\"click->tiptap-editor#triggerImageUpload\" on the activated button"
      pattern: "click->tiptap-editor#triggerImageUpload"
    - from: "Hidden file input"
      to: "tiptap_editor_controller#handleImageFileSelected"
      via: "data-action=\"change->tiptap-editor#handleImageFileSelected\" on the hidden <input type=\"file\">"
      pattern: "handleImageFileSelected"
    - from: "tiptap_editor_controller drop handler"
      to: "ActiveStorage DirectUpload"
      via: "new DirectUpload(file, '/rails/active_storage/direct_uploads').create((error, blob) => …)"
      pattern: "DirectUpload"
    - from: "ActiveStorage blob"
      to: "Inserted <img> node"
      via: "editor.chain().focus().setImage({ src: relativeBlobUrl, alt, width }).run()"
      pattern: "setImage"
    - from: "app/models/blog.rb#sanitize_body"
      to: "blogs.body column"
      via: "SafeListSanitizer attributes list still includes 'width' on img"
      pattern: "ALLOWED_ATTRIBUTES"
---

<objective>
## Phase Goal

**As an** admin editor, **I want to** upload an image inline (via click or drag-and-drop), set its alt text, and resize it with corner handles, **so that** I can publish posts with proper imagery without leaving the editor or hand-writing `<img>` tags.

This is the **third vertical slice** of Phase 2. The slice spans npm dependencies → Stimulus controller → ActiveStorage direct upload → editor placeholder/inject/error states → resize handles → sanitizer coverage → published render. By the end, image insertion is fully end-to-end.

**Purpose:** Activate the Phase 1 disabled image toolbar stub with full upload, alt-text, resize, and sanitizer support (RICH-02).
**Output:** `@tiptap/extension-image` and `@rails/activestorage` installed; Stimulus controller drives click-to-upload, drag-and-drop, placeholder node, DirectUpload, alt-text prompt, and corner-handle resize; toolbar image button is activated and wired; sanitizer permits `<img>` with `src/alt/width`; new model spec proves the round-trip and `onerror` strip.
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
@.planning/phases/02-rich-content-author-profiles/02-P2-PLAN.md
@CLAUDE.md

@app/javascript/controllers/tiptap_editor_controller.js
@app/views/admin/blogs/_form.html.erb
@app/models/blog.rb
@app/assets/stylesheets/application.tailwind.css
@spec/models/blog_spec.rb
@config/storage.yml

<interfaces>
<!-- Tiptap 3.x Image API: -->
<!--   import Image from "@tiptap/extension-image" -->
<!--   Image.configure({ inline: true, allowBase64: false, HTMLAttributes: { class: "tiptap-inline-image" } }) -->
<!--   editor.chain().focus().setImage({ src, alt, width }).run() -->
<!--   editor.isActive('image') — true when image is selected -->
<!--   editor.commands.updateAttributes('image', { width }) — for live resize -->

<!-- ActiveStorage DirectUpload API: -->
<!--   import { DirectUpload } from "@rails/activestorage" -->
<!--   const upload = new DirectUpload(file, "/rails/active_storage/direct_uploads") -->
<!--   upload.create((error, blob) => { -->
<!--     if (error) { /* handle */ } -->
<!--     else { /* blob.signed_id, blob.filename — construct src */ } -->
<!--   }) -->

<!-- Rails generates the relative blob URL with rails_blob_path; in JS we can construct it as: -->
<!--   `/rails/active_storage/blobs/redirect/${blob.signed_id}/${encodeURIComponent(blob.filename)}` -->

<!-- Existing Blog sanitizer state (after Plan P2): -->
<!--   ALLOWED_TAGS = %w[p br h1 h2 h3 h4 h5 h6 ul ol li strong em a blockquote code pre img figure figcaption table thead tbody tfoot tr th td colgroup col] -->
<!--   ALLOWED_ATTRIBUTES = %w[href target rel src alt width height colspan rowspan scope] -->
<!--   ⇒ <img src alt width> already passes the sanitizer; no model change required unless verification fails -->

<!-- Existing Phase-1 disabled image stub button (in _form.html.erb): -->
<!--   <button type="button" disabled aria-disabled="true" title="Coming soon" class="… opacity-50 cursor-not-allowed"> -->
<!--     <svg …><rect x="3" y="3" …/><circle cx="8.5" cy="8.5" r="1.5"/><polyline points="21 15 16 10 5 21"/></svg> ← picture icon -->
<!--   </button> -->
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Install @tiptap/extension-image and @rails/activestorage, register the Image extension, and add upload + drag-and-drop + alt-text + resize logic to the Stimulus controller</name>
  <files>package.json, package-lock.json, app/javascript/controllers/tiptap_editor_controller.js</files>
  <read_first>
    - package.json (current Tiptap version `^3.23.2` — pin the new image extension to the same major)
    - app/javascript/controllers/tiptap_editor_controller.js (after Plan P2 — confirm tableMenu target is already declared, BubbleMenu is configured, and import block placement convention)
    - .planning/phases/02-rich-content-author-profiles/02-CONTEXT.md (D-01 click + drag-and-drop, D-02 placeholder spinner, D-03 rails_blob_path src, D-04 alt-text prompt required, D-05 width via attribute not style, D-06 direct upload endpoint, D-07 sanitizer width attribute)
    - .planning/phases/02-rich-content-author-profiles/02-UI-SPEC.md (§3 toolbar image button, §4 placeholder spinner template, §5 alt-text prompt copy, §6 inline image resize handles spec, §Interaction Contracts — Image Upload flow steps 1–5, drag/drop dragover classes, initial width capped at 720)
    - config/storage.yml (confirm Active Storage is configured; if `service: local` is set in development the direct upload endpoint accepts uploads without S3 creds)
  </read_first>
  <action>
**npm install:**

Run `npm install @tiptap/extension-image@^3 @rails/activestorage@^8 --save`. The version range `^8` matches the Rails 8.0 backend (`@rails/activestorage` major-version-tracks Rails). Confirm both keys land in `package.json` `dependencies` and `package-lock.json` resolves them.

**Stimulus controller (`app/javascript/controllers/tiptap_editor_controller.js`) — surgical extension only, do NOT rewrite:**

1. Add imports below the Phase-2 imports:
   - `Image` from `@tiptap/extension-image`
   - `{ DirectUpload }` from `@rails/activestorage`

2. Add to `static targets = […]`: `"imageFileInput"`.

3. Inside the `extensions:` array (after the table extensions added in Plan P2), append `Image.configure({ inline: false, allowBase64: false, HTMLAttributes: { class: "tiptap-inline-image" } })`.

4. Add a `static values = { directUploadUrl: { type: String, default: "/rails/active_storage/direct_uploads" } }` declaration on the class (above the `connect()` method). The value will be read inside upload handlers so the endpoint is configurable later.

5. Add new instance methods (paste-able names — implementations described below in plain prose, NOT inline code blocks):

   **`triggerImageUpload()`** — Calls `this.imageFileInputTarget.click()` so the OS file picker opens.

   **`handleImageFileSelected(event)`** — Reads `event.target.files[0]`; if no file, return. Calls `this.uploadImage(file)`. Resets `event.target.value = ""` so selecting the same file twice still fires `change`.

   **`uploadImage(file)`** (private helper, not a Stimulus action) — Validates `file.type` starts with `"image/"`; on mismatch, calls `this.showInlineError("Only image files can be dropped here.")` and returns. Otherwise:
   - Inserts a placeholder node into the editor at the current selection using `this.editor.chain().focus().insertContent({ type: 'paragraph', content: [{ type: 'text', text: 'Uploading image…' }] }).run()` — see step 5b below for the alternative approach.
   - Actually, since `@tiptap/extension-image` has no built-in placeholder type, use a simpler approach: insert a temporary HTML node by calling `this.editor.commands.insertContent('<p class="tiptap-image-placeholder" data-uploading="true">Uploading image…</p>')` and store the resulting position. Track the placeholder via a unique `data-upload-id` attribute (use `Math.random().toString(36).slice(2)`).
   - Create a `new DirectUpload(file, this.directUploadUrlValue)`; call `.create((error, blob) => {…})`.
   - In the callback: locate the placeholder by scanning `this.editor.view.dom.querySelectorAll('[data-upload-id="<uploadId>"]')`. If `error`, replace the placeholder text with an error span (class `text-sm text-red-600` containing "Image upload failed. Please try again.") then auto-remove after 4 seconds via `setTimeout`. If success, prompt for alt text using `window.prompt('Enter alt text for this image (required):')`. If the prompt returns `null` (cancelled), delete the placeholder DOM node and return. Otherwise: compute `const blobUrl = \`/rails/active_storage/blobs/redirect/\${blob.signed_id}/\${encodeURIComponent(blob.filename)}\``; remove the placeholder; call `this.editor.chain().focus().setImage({ src: blobUrl, alt: altText, width: Math.min(blob.byte_size ? 720 : 720, 720) }).run()` — practically, just pass `width: 720` initially as the cap (the natural-width cap from UI-SPEC; we cannot get image natural dimensions inside the DirectUpload callback without loading the image; using the 720 cap satisfies the contract).

   **`showInlineError(message)`** (private helper) — Inserts a transient `<p class="text-sm text-red-600">` node into the editor at the current position via `this.editor.commands.insertContent`. Schedules removal with `setTimeout` after 4 seconds.

   **Drag-and-drop wiring** — In `connect()`, after the editor is constructed, attach three listeners to `this.editorTarget`:
   - `dragover`: `event.preventDefault()` (allow drop); add classes `border-pink-400` and `bg-pink-50` to `this.editorTarget`.
   - `dragleave`: remove the same classes.
   - `drop`: `event.preventDefault()`; remove the dragover classes; if `event.dataTransfer.files.length > 0`, call `this.uploadImage(event.dataTransfer.files[0])` for the first file only (single-image MVP); otherwise no-op.

   Persist these listener references on `this` (e.g. `this._onDragOver`, `this._onDragLeave`, `this._onDrop`) and in `disconnect()` call `this.editorTarget.removeEventListener(...)` for each to avoid leaks across Turbo navigations.

   **Resize handles** — On the editor's `selectionUpdate` (which already calls `updateToolbarState`), additionally call `this.updateImageSelectionHandles(editor)`. Implement `updateImageSelectionHandles(editor)`:
   - Remove any existing handle DOM elements (class `tiptap-resize-handle`) from `this.editorTarget`.
   - If `editor.isActive('image')` is `false`, return.
   - Find the currently selected `<img>` inside `this.editorTarget` (the one with class `tiptap-inline-image` whose bounding rect contains the selection's anchor coordinates) — practically, since Tiptap NodeView selection adds `ProseMirror-selectednode` class, query `this.editorTarget.querySelector('img.ProseMirror-selectednode, img.tiptap-inline-image.ProseMirror-selectednode')`.
   - Add `ring-2 ring-pink-500` classes to the selected `<img>`.
   - Create four absolutely-positioned `<div class="tiptap-resize-handle">` elements appended to `this.editorTarget`, positioned at the four corners of the image using `getBoundingClientRect()` minus the editor's offset. Each handle has `data-corner="nw|ne|sw|se"`.
   - Attach `mousedown` to each handle that starts a drag: track `startX = event.clientX`, `startWidth = parseInt(selectedImg.getAttribute('width'), 10) || selectedImg.naturalWidth`, then on `mousemove` (registered on `window`) compute new width and call `this.editor.commands.updateAttributes('image', { width: Math.max(64, startWidth + (event.clientX - startX)) })`. On `mouseup`, detach the `mousemove`/`mouseup` listeners. Cap min width at 64 px, max at the editor's content width.

6. In `disconnect()` (after existing `this.editor.destroy()` block), remove the three drag listeners attached in `connect()` and clear any pending `setTimeout` ids stored on `this`.

Do NOT change `toggleBold`, `setLink`, the table-edit methods from Plan P2, or the `updateToolbarState` engine.
  </action>
  <verify>
    <automated>node -e "const p=require('./package.json').dependencies; ['@tiptap/extension-image','@rails/activestorage'].forEach(n=>{if(!p[n]){console.error('Missing dep:',n);process.exit(1)}})"</automated>
    <automated>node -e "const c=require('fs').readFileSync('app/javascript/controllers/tiptap_editor_controller.js','utf8'); const need=['from \"@tiptap/extension-image\"','from \"@rails/activestorage\"','DirectUpload','imageFileInputTarget','triggerImageUpload','handleImageFileSelected','uploadImage','Image.configure','tiptap-inline-image','dragover','dragleave','drop','tiptap-resize-handle','setImage','editor.isActive(\\'image\\')','updateAttributes(\\'image\\'','/rails/active_storage/direct_uploads']; const miss=need.filter(s=>!c.includes(s)); if(miss.length){console.error('Missing:',miss);process.exit(1)}"</automated>
    <automated>npm run build</automated>
  </verify>
  <acceptance_criteria>
    - `package.json` `dependencies` contains `@tiptap/extension-image` (pinned `^3`) and `@rails/activestorage` (pinned `^8`)
    - Stimulus controller imports both packages
    - `static targets` includes `"imageFileInput"`
    - `static values = { directUploadUrl: { type: String, default: "/rails/active_storage/direct_uploads" } }` is declared
    - `extensions:` array includes `Image.configure({ inline: false, allowBase64: false, ... })`
    - Controller defines `triggerImageUpload`, `handleImageFileSelected`, `uploadImage`, `showInlineError`, and `updateImageSelectionHandles` methods (names matching the action declarations in Task 2)
    - `DirectUpload` is instantiated with the `/rails/active_storage/direct_uploads` endpoint (or the `directUploadUrlValue`)
    - `dragover`, `dragleave`, and `drop` listeners are attached to `this.editorTarget` in `connect()` and removed in `disconnect()`
    - On `dragover` the classes `border-pink-400` and `bg-pink-50` are added; on `dragleave`/`drop` they are removed
    - Resize logic calls `editor.commands.updateAttributes('image', { width: … })`
    - `npm run build` exits 0
  </acceptance_criteria>
  <done>Image extension + DirectUpload wired in the Stimulus controller; all action methods exist; drag-and-drop listeners are registered and torn down; resize handles use `width` attribute (not inline style); esbuild bundle compiles.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Activate the image toolbar button, render hidden file input, scope image styles, and prove the sanitizer round-trip + onerror strip in the model spec</name>
  <files>app/views/admin/blogs/_form.html.erb, app/models/blog.rb, app/assets/stylesheets/application.tailwind.css, spec/models/blog_spec.rb</files>
  <read_first>
    - app/views/admin/blogs/_form.html.erb (the second disabled stub button — the one with the picture-icon SVG; the `.tiptap-editor` wrapper now also containing the BubbleMenu from P2)
    - app/models/blog.rb (post-P2 state — confirm `ALLOWED_ATTRIBUTES` already includes `width`; if not, add it)
    - .planning/phases/02-rich-content-author-profiles/02-UI-SPEC.md (§3 button class/attrs, §3 hidden file input markup, §4 placeholder CSS, §6 resize handle visual spec — 8×8 pink-600 with white border)
    - app/assets/stylesheets/application.tailwind.css (existing tiptap-editor scope — append, do not override)
    - spec/models/blog_spec.rb (post-P2 file with `describe "#sanitize_body"` block — append new examples inside it, do NOT create a duplicate describe)
  </read_first>
  <behavior>
    - The Insert Image toolbar button has `data-action="click->tiptap-editor#triggerImageUpload"`, `title="Upload image"`, `aria-label="Upload image"`, standard toolbar class string `inline-flex items-center justify-center h-9 w-9 rounded text-gray-700 hover:bg-gray-100 transition-colors`. The `disabled` and `aria-disabled` attributes are removed.
    - A hidden `<input type="file" accept="image/*" data-tiptap-editor-target="imageFileInput" data-action="change->tiptap-editor#handleImageFileSelected" class="hidden">` exists inside the `.tiptap-editor` wrapper.
    - The Blog model sanitizes a body containing `<img src="/rails/active_storage/blobs/redirect/xyz/photo.jpg" alt="A photo" width="480">` and preserves all three attributes.
    - The Blog model sanitizes a body containing `<img src="x" onerror="alert(1)" alt="x">` and strips `onerror` but keeps the `<img>` tag with `src` and `alt`.
    - The compiled CSS contains rules for `.tiptap-resize-handle` (8×8 pink-600 with white border, rounded), `img.tiptap-inline-image` (max-width 100%), and `.tiptap-image-placeholder` (visible spinner/text styling).
  </behavior>
  <action>
**Form (`app/views/admin/blogs/_form.html.erb`):**

1. Locate the second disabled stub button (the picture-icon one, the only remaining `disabled` button in the toolbar after P2 activated the table button). Modify it:
   - Remove `disabled` and `aria-disabled="true"`.
   - Remove classes `text-gray-400 opacity-50 cursor-not-allowed`.
   - Add classes `text-gray-700 hover:bg-gray-100 transition-colors`.
   - Add `data-action="click->tiptap-editor#triggerImageUpload"`.
   - Add `title="Upload image"` and `aria-label="Upload image"`.
   - Keep the picture-icon SVG unchanged.

2. Inside the `<div class="tiptap-editor" data-controller="tiptap-editor">` wrapper, immediately after the BubbleMenu from P2, add a hidden file input:
   - `<input type="file" accept="image/*" data-tiptap-editor-target="imageFileInput" data-action="change->tiptap-editor#handleImageFileSelected" class="hidden">`

**Blog model (`app/models/blog.rb`):**

3. Verify `ALLOWED_ATTRIBUTES` already includes `width` (it should, post-Phase 1 + P2). If it does NOT include `width`, add it (append, preserve `.freeze`). Otherwise leave the model untouched. Do NOT add `style` or any event-handler attribute.

**CSS (`app/assets/stylesheets/application.tailwind.css`):**

4. Append rules below the P2 table-cell rules:
   - `.tiptap-editor .ProseMirror img.tiptap-inline-image { max-width: 100%; height: auto; display: inline-block; }`
   - `.tiptap-editor .ProseMirror img.ProseMirror-selectednode { outline: 2px solid #ec4899; outline-offset: 2px; }` (matches `ring-pink-500` tone)
   - `.tiptap-editor .tiptap-resize-handle { position: absolute; width: 8px; height: 8px; background-color: #db2777; border: 1px solid #ffffff; border-radius: 2px; z-index: 20; }`
   - `.tiptap-editor .tiptap-resize-handle[data-corner="nw"], .tiptap-editor .tiptap-resize-handle[data-corner="se"] { cursor: nwse-resize; }`
   - `.tiptap-editor .tiptap-resize-handle[data-corner="ne"], .tiptap-editor .tiptap-resize-handle[data-corner="sw"] { cursor: nesw-resize; }`
   - `.tiptap-editor .ProseMirror .tiptap-image-placeholder { display: inline-block; padding: 0.5rem 0.75rem; background-color: #f3f4f6; color: #6b7280; border-radius: 0.375rem; font-size: 0.875rem; margin: 0.5rem 0; }`
   - Ensure the `.tiptap-editor` wrapper acquires `position: relative` so absolutely positioned handles align correctly: `.tiptap-editor { position: relative; }`
   - Dragover state classes `border-pink-400` and `bg-pink-50` are Tailwind utilities and need no custom CSS.

**Model spec (`spec/models/blog_spec.rb`):**

5. Append two new examples inside the existing `describe "#sanitize_body"` block (do NOT create a second describe):

   - Example 3 "preserves img tags with src, alt, and width attributes":
     - `body = '<p><img src="/rails/active_storage/blobs/redirect/xyz/photo.jpg" alt="A photo" width="480"></p>'`
     - `blog = build(:blog, body: body)`
     - `blog.save!`
     - `expect(blog.body).to include('<img')`
     - `expect(blog.body).to include('src="/rails/active_storage/blobs/redirect/xyz/photo.jpg"')`
     - `expect(blog.body).to include('alt="A photo"')`
     - `expect(blog.body).to include('width="480"')`

   - Example 4 "strips onerror and other event-handler attributes on img tags":
     - `body = '<img src="x" onerror="alert(1)" alt="x">'`
     - `blog = build(:blog, body: body)`
     - `blog.save!`
     - `expect(blog.body).not_to include('onerror')`
     - `expect(blog.body).to include('<img')`
     - `expect(blog.body).to include('src="x"')`
     - `expect(blog.body).to include('alt="x"')`
  </action>
  <verify>
    <automated>grep -q 'click->tiptap-editor#triggerImageUpload' app/views/admin/blogs/_form.html.erb</automated>
    <automated>grep -q 'data-tiptap-editor-target="imageFileInput"' app/views/admin/blogs/_form.html.erb</automated>
    <automated>grep -E 'ALLOWED_ATTRIBUTES.*width' app/models/blog.rb</automated>
    <automated>grep -q 'tiptap-resize-handle' app/assets/stylesheets/application.tailwind.css</automated>
    <automated>grep -q 'tiptap-inline-image' app/assets/stylesheets/application.tailwind.css</automated>
    <automated>bundle exec rspec spec/models/blog_spec.rb</automated>
    <automated>npm run build:css</automated>
  </verify>
  <acceptance_criteria>
    - The activated image toolbar button in `_form.html.erb` contains literal substrings `click->tiptap-editor#triggerImageUpload`, `title="Upload image"`, `aria-label="Upload image"`; the `disabled` and `aria-disabled` attributes are removed from that specific button
    - Hidden `<input type="file">` exists with the three required attributes: `accept="image/*"`, `data-tiptap-editor-target="imageFileInput"`, `data-action="change->tiptap-editor#handleImageFileSelected"`
    - `Blog::ALLOWED_ATTRIBUTES` still includes `width` after P3
    - `.tiptap-editor .tiptap-resize-handle` CSS rule is present and sets `position: absolute`, `width: 8px`, `height: 8px`, and `background-color: #db2777`
    - `.tiptap-editor img.tiptap-inline-image` rule sets `max-width: 100%`
    - `.tiptap-editor` wrapper has `position: relative`
    - `bundle exec rspec spec/models/blog_spec.rb` exits 0 with at least four passing examples (two from P2 + two from P3)
    - `npm run build:css` exits 0
    - After Plan P2 + P3, exactly zero `disabled` buttons remain in the toolbar of `_form.html.erb`
  </acceptance_criteria>
  <done>Image toolbar button live, hidden file input present, sanitizer permits `<img src alt width>` and strips event handlers, resize handles styled, and model spec proves the sanitizer round-trip and the `onerror` strip.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Admin browser → /rails/active_storage/direct_uploads | Admin posts file blob to Rails — Devise + admin role gate already protects this; ActiveStorage validates signature on use |
| Tiptap editor (browser) → blogs.body | Admin-authored HTML with `<img>` tags crosses the sanitizer on save |
| blogs.body (DB) → public show page | Stored HTML re-sanitized at render; `<img>` `src` must point to internal ActiveStorage path, not arbitrary external URL |
| Drag-and-drop input → upload pipeline | Untrusted file metadata (MIME, name) — must check `file.type.startsWith('image/')` before initiating upload |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-02-P3-01 | Tampering (XSS via img event handlers) | Blog#sanitize_body | mitigate | ALLOWED_ATTRIBUTES list explicitly does NOT include `onerror`, `onclick`, `onload`, `onmouseover`, etc.; spec asserts `onerror` is stripped |
| T-02-P3-02 | Tampering (XSS via javascript: URLs in src) | Blog#sanitize_body | mitigate | Rails `SafeListSanitizer` strips `javascript:` and `data:` URI schemes from `src` by default (per Rails-html-sanitizer); add an explicit example in the spec only if Plan checker requests it (skipped here — relying on Rails built-in URL scrubbing) |
| T-02-P3-03 | Spoofing (non-image file uploaded as image) | uploadImage MIME check | mitigate | Client-side check `file.type.startsWith('image/')` prevents the upload from initiating; ActiveStorage server-side content-type sniffing is the fallback. Note: admin-only surface, low risk. |
| T-02-P3-04 | Denial of Service (huge file upload) | DirectUpload | accept | Admin is trusted; no upload size limit imposed at the Rails level. Acceptable for v1 — can be added in a future plan if abused. |
| T-02-P3-05 | Information Disclosure (CSRF on direct upload) | /rails/active_storage/direct_uploads | accept | Rails routes for ActiveStorage are CSRF-protected by default; admin-only form contexts already pass the token |
| T-02-P3-06 | Tampering (XSS via crafted `width` attribute) | Blog#sanitize_body | mitigate | `width` is whitelisted but sanitizer scrubs non-numeric values; even with malformed input, the worst case is broken layout, not script execution |
</threat_model>

<verification>
- npm install succeeds and lockfile resolves `@tiptap/extension-image` + `@rails/activestorage`
- esbuild bundle compiles with new imports
- Admin form renders activated image button and hidden file input
- Model spec passes (≥ 4 examples — two new + two from P2)
- CSS compiles with resize-handle and inline-image rules
</verification>

<success_criteria>
- Phase Success Criterion #2 satisfied: "Admin can upload an image inline within the editor body; the image is stored in ActiveStorage and appears as a standard `<img>` tag in the published post"
- Requirement RICH-02 covered end-to-end (npm → controller → drag/drop + click → DirectUpload → alt prompt → sanitizer → render)
- No XSS vector introduced — `onerror` strip is spec-enforced
</success_criteria>

<output>
After completion, create `.planning/phases/02-rich-content-author-profiles/02-P3-SUMMARY.md` summarizing: packages installed, controller action surface, drag/drop wiring, DirectUpload integration, resize implementation, sanitizer state (no change required if `width` already present), CSS additions, spec coverage.
</output>
</output>
