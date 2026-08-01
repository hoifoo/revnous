---
phase: 02-rich-content-author-profiles
verified: 2026-05-22T00:00:00Z
status: passed
score: 10/10 must-haves verified
overrides_applied: 0
re_verification: false
---

# Phase 02: Rich Content & Author Profiles — Verification Report

**Phase Goal:** Rich Content & Author Profiles — Tiptap table editing, image upload via ActiveStorage, per-post paragraph spacing, admin user CRUD with author profile fields, and blog→author association with public author card and Person JSON-LD schema.

**Verified:** 2026-05-22
**Status:** PASSED
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Admin can select Normal or Relaxed paragraph spacing per post; change is visible on the published page | VERIFIED | `form.select :spacing` at `_form.html.erb:44`; `prose-paragraph-relaxed` conditional at `show.html.erb:61`; CSS rule at `application.tailwind.css:20` |
| 2 | Admin can insert a table from the toolbar and add/remove rows and columns without leaving the editor | VERIFIED | `insertTable`, all 7 chain-command methods in `tiptap_editor_controller.js:167-196`; BubbleMenu wired at `_form.html.erb:301`; `Table.configure` in extensions array |
| 3 | Blog body sanitizer passes `<table>` markup through and strips unsafe attributes | VERIFIED | `ALLOWED_TAGS` includes 9 table tags, `ALLOWED_ATTRIBUTES` includes `colspan/rowspan/scope` at `blog.rb:6-7`; model spec 4 examples covering round-trip and strip |
| 4 | Admin can upload an image inline via toolbar click or drag-and-drop; image stored in ActiveStorage | VERIFIED | `triggerImageUpload`, `handleImageFileSelected`, `uploadImage`, `DirectUpload` all present in `tiptap_editor_controller.js`; `click->tiptap-editor#triggerImageUpload` at `_form.html.erb:291`; `imageFileInput` hidden input at `_form.html.erb:381` |
| 5 | Admin users can fill in bio, job title, LinkedIn URL, Twitter handle, and upload an avatar | VERIFIED | Migration `20260519203520`; `app/models/user.rb` has `has_one_attached :avatar`, `full_name`, `initials`, linkedin validation, twitter normalization; all fields present in `app/views/admin/users/_form.html.erb` |
| 6 | Admin user CRUD routes, controller, and views are fully operational | VERIFIED | `resources :users, except: [:show]` at `config/routes.rb:19`; `Admin::UsersController` inherits `Admin::BaseController`; all 4 views exist; 9-example request spec passes |
| 7 | Admin can select an author for a blog post from existing admin users via a dropdown | VERIFIED | `collection_select :author_id` at `_form.html.erb:28-33`; `:author_id` in `blog_params` at `blogs_controller.rb:47-49`; FK migration `20260519210037` |
| 8 | Published blog posts display an author card below the content when an author is set; no card when no author | VERIFIED | `_author_card.html.erb` guards with `@blog.author.present?`; includes "Written by", `full_name`, `initials`, conditional LinkedIn/Twitter; `render "author_card"` at `show.html.erb:65`; legacy byline uses `@blog[:author]` only when `@blog.author.nil?` |
| 9 | Blog JSON-LD emits Person author node when author_id is set; falls back to Organization otherwise | VERIFIED | `author_schema_node` private method at `application_helper.rb:132-139`; `render_article_schema` delegates at line 73; `json_escape(...).html_safe` at line 84; helper spec covers Person, Person-without-links, Organization, and XSS branches |
| 10 | Deleting a User nullifies blogs.author_id without destroying the blog | VERIFIED | `dependent: :nullify` on `User#has_many :authored_blogs` at `user.rb:8`; `on_delete: :nullify` FK at `schema.rb:492`; round-trip smoke check in P5 plan verified |

**Score:** 10/10 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `db/migrate/20260519201530_add_spacing_to_blogs.rb` | spacing column default 'normal' | VERIFIED | Present; schema.rb confirms `t.string "spacing", default: "normal", null: false` |
| `db/migrate/20260519203520_add_author_profile_to_users.rb` | bio/job_title/linkedin_url/twitter_handle columns | VERIFIED | Present; schema.rb confirms all 4 columns at lines 480-483 |
| `db/migrate/20260519210037_add_author_id_to_blogs.rb` | blogs.author_id FK to users with nullify | VERIFIED | Present; schema.rb confirms `t.bigint "author_id"`, index, and FK `on_delete: :nullify` |
| `app/controllers/admin/blogs_controller.rb` | permits :spacing and :author_id | VERIFIED | `:spacing` and `:author_id` both in `blog_params`; legacy author written via `@blog[:author]` directly |
| `app/controllers/admin/users_controller.rb` | Full CRUD inheriting Admin::BaseController | VERIFIED | Class exists, inherits correctly, all 6 actions plus `set_user`/`user_params` present |
| `app/views/admin/blogs/_form.html.erb` | spacing dropdown, author_id collection_select, activated table/image buttons, BubbleMenu DOM | VERIFIED | All items confirmed; zero `disabled` attributes remain in toolbar |
| `app/views/admin/users/_form.html.erb` | All profile fields including avatar | VERIFIED | job_title, bio, linkedin_url, twitter_handle, avatar file_field, admin checkbox all present |
| `app/views/admin/users/index.html.erb` | Avatar/initials, full_name, job_title, role badge | VERIFIED | All fields confirmed at lines 37-52 |
| `app/views/blogs/show.html.erb` | prose-paragraph-relaxed conditional, render author_card, legacy byline with @blog[:author] | VERIFIED | All three present at lines 61, 65, 32-34 |
| `app/views/blogs/_author_card.html.erb` | Written by, full_name, conditional bio/job_title/linkedin/twitter | VERIFIED | Full implementation matches spec; all conditionals present |
| `app/models/blog.rb` | belongs_to :author optional, ALLOWED_TAGS with table tags, ALLOWED_ATTRIBUTES with table attrs | VERIFIED | All confirmed |
| `app/models/user.rb` | has_one_attached :avatar, has_many :authored_blogs :nullify, full_name, initials, linkedin validation, twitter normalization | VERIFIED | All confirmed at lines 7-29 |
| `app/helpers/application_helper.rb` | render_article_schema with Person/Organization via author_schema_node | VERIFIED | Both methods present; json_escape(..).html_safe at line 84 |
| `app/javascript/controllers/tiptap_editor_controller.js` | Table/BubbleMenu/Image extensions, all action methods, DirectUpload, drag-drop, resize | VERIFIED | All imports, targets, extensions, and 12+ action methods confirmed |
| `app/assets/stylesheets/application.tailwind.css` | .prose-paragraph-relaxed p, table cell rules, resize handle rules | VERIFIED | All rules present at lines 20, 47-79 |
| `spec/models/blog_spec.rb` | 4 examples covering table round-trip, onclick strip, img round-trip, onerror strip | VERIFIED | All 4 examples present in `describe "#sanitize_body"` |
| `spec/requests/admin/users_spec.rb` | 9 examples: CRUD + non-admin redirect + linkedin invalid | VERIFIED | 9 examples confirmed |
| `spec/requests/admin/blogs_spec.rb` | spacing round-trip + author_id + legacy author text round-trip | VERIFIED | spacing at line 26; author_id at line 38 |
| `spec/helpers/application_helper_spec.rb` | 4 helper spec examples for Person/Organization/XSS | VERIFIED | File exists with 4 examples covering all branches |
| `spec/factories/users.rb` | first_name, last_name, job_title, bio, linkedin_url, twitter_handle sequences | VERIFIED | All confirmed at lines 4-12 |
| `spec/factories/blogs.rb` | author_user transient with after(:build) | VERIFIED | transient and after(:build) confirmed at lines 11-16 |
| `package.json` | 5 tiptap table packages + bubble-menu + extension-image + @rails/activestorage | VERIFIED | All 7 npm packages present at lines 15-25 |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `_form.html.erb` (spacing select) | `blogs_controller.rb#blog_params` | `form.select :spacing` → `blog[spacing]` → `:spacing` in permit list | VERIFIED | `:spacing` at controller line 49 |
| `_form.html.erb` (author_id select) | `blogs_controller.rb#blog_params` | `collection_select :author_id` → `:author_id` in permit list | VERIFIED | `:author_id` at controller line 47 |
| `show.html.erb` | `blogs.spacing column` | `'prose-paragraph-relaxed' if @blog.spacing == 'relaxed'` literal comparison | VERIFIED | Line 61 confirmed |
| `_form.html.erb` (table button) | `tiptap_editor_controller.js#insertTable` | `click->tiptap-editor#insertTable` data-action | VERIFIED | Line 281 confirmed |
| `_form.html.erb` BubbleMenu DOM | `tiptap_editor_controller.js` BubbleMenu element | `data-tiptap-editor-target="tableMenu"` | VERIFIED | Line 301 confirmed |
| `_form.html.erb` (image button) | `tiptap_editor_controller.js#triggerImageUpload` | `click->tiptap-editor#triggerImageUpload` | VERIFIED | Line 291 confirmed |
| `tiptap_editor_controller.js` | ActiveStorage DirectUpload | `new DirectUpload(file, this.directUploadUrlValue)` | VERIFIED | Line 221 confirmed |
| `blog.rb#belongs_to :author` | `users.id` via `blogs.author_id` | `class_name: "User", foreign_key: "author_id", optional: true` | VERIFIED | blog.rb line 3 confirmed |
| `user.rb#has_many :authored_blogs` | `blogs.author_id` | `dependent: :nullify` + DB `on_delete: :nullify` | VERIFIED | user.rb line 8; schema.rb line 492 |
| `show.html.erb` | `_author_card.html.erb` | `render "author_card"` after prose block | VERIFIED | show.html.erb line 65 confirmed |
| `_author_card.html.erb` | `User#full_name, initials, avatar, linkedin_url, twitter_handle` | ERB conditionals on each social attribute | VERIFIED | All 5 attributes referenced conditionally |
| `application_helper.rb#render_article_schema` | Person/Organization JSON-LD node | `author_schema_node(article)` delegation | VERIFIED | Lines 73 and 132-139 confirmed |

---

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `show.html.erb` spacing class | `@blog.spacing` | `blogs.spacing` DB column (default 'normal') | Yes — literal comparison, not interpolated | FLOWING |
| `_author_card.html.erb` | `@blog.author` | `belongs_to :author` association → `users` table | Yes — real AR association query | FLOWING |
| `application_helper.rb` | `article.author` | Same AR association → `author_schema_node` | Yes — `is_a?(User)` check guards both branches | FLOWING |
| `admin/users/index.html.erb` | `@users` | `User.order(:first_name, :last_name).page(...)` | Yes — real DB query with kaminari pagination | FLOWING |
| `admin/blogs/_form.html.erb` author dropdown | `User.order(:first_name)` | Live DB query at render time | Yes — fresh user list on every form load | FLOWING |

---

### Behavioral Spot-Checks

Step 7b: The phase produces Rails view/controller code. Behavioral checks require a running server. The critical runtime paths are spec-covered:

| Behavior | Verification Method | Status |
|----------|---------------------|--------|
| spacing column round-trip | `spec/requests/admin/blogs_spec.rb` spacing example | VERIFIED via spec |
| table sanitizer round-trip + strip | `spec/models/blog_spec.rb` examples 1-2 | VERIFIED via spec |
| img sanitizer round-trip + onerror strip | `spec/models/blog_spec.rb` examples 3-4 | VERIFIED via spec |
| author_id + legacy author text round-trip | `spec/requests/admin/blogs_spec.rb` example 3 | VERIFIED via spec |
| User CRUD + non-admin redirect | `spec/requests/admin/users_spec.rb` 9 examples | VERIFIED via spec |
| Person/Organization JSON-LD + XSS guard | `spec/helpers/application_helper_spec.rb` 4 examples | VERIFIED via spec |

---

### Probe Execution

Step 7c: No probe scripts declared in any plan and no `scripts/*/tests/probe-*.sh` files found. SKIPPED.

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| RICH-01 | P2 | Table insert and edit via toolbar | SATISFIED | Table extensions, BubbleMenu, 8 action methods all present and wired |
| RICH-02 | P3 | Inline image upload to ActiveStorage | SATISFIED | DirectUpload integration, triggerImageUpload, drag-drop all present |
| RICH-03 | P1 | Paragraph spacing dropdown Normal/Relaxed | SATISFIED | Migration, form select, show-page conditional, CSS rule all present |
| AUTH-01 | P5 | Author dropdown on blog post | SATISFIED | `collection_select :author_id` in form, `:author_id` in strong params |
| AUTH-02 | P4 | Author profile fields on admin user | SATISFIED | 4 new columns, `has_one_attached :avatar`, full_name/initials, CRUD views |
| AUTH-03 | P5 | Author card on published post | SATISFIED | `_author_card.html.erb` present and rendered conditionally on show page |
| AUTH-04 | P5 | Person JSON-LD in article schema | SATISFIED | `author_schema_node` in helper; Person/Organization branches spec-verified |

All 7 declared requirement IDs are satisfied. No orphaned requirements found.

---

### Anti-Patterns Found

No debt markers (TBD, FIXME, XXX) found in any phase-modified file.

"placeholder" occurrences in phase files are all legitimate:
- `tiptap_editor_controller.js:29` — Tiptap editor placeholder configuration text ("Start writing your post...")
- `tiptap_editor_controller.js:218` — Upload-in-progress placeholder element, intentional runtime behavior
- `_form.html.erb` — HTML input `placeholder=` attributes on text fields, not stubs
- `_author_card.html.erb` — HTML comment "Initials placeholder", describes an actual rendered UI element

No empty return values, no no-op handlers, no disconnected data flows found in phase-modified files.

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (none) | — | — | — | — |

---

### Human Verification Required

The following behaviors require human testing in a browser and cannot be verified programmatically:

#### 1. Tiptap Table Editing — Browser Interaction

**Test:** Open a blog post in the admin editor, click the "Insert table" toolbar button, place cursor inside a cell, observe the BubbleMenu.
**Expected:** A 3x3 table with header row appears; the floating BubbleMenu with 7 controls (add row above/below, remove row, add col left/right, remove col, delete table) becomes visible when cursor is in a cell.
**Why human:** BubbleMenu visibility is controlled by Tiptap's BubbleMenu plugin's `shouldShow` callback (`editor.isActive('table')`), which only fires in a live browser with a running ProseMirror instance.

#### 2. Image Upload — Browser Interaction

**Test:** Open a blog post in the admin editor, click "Upload image", select an image file; also try dragging an image onto the editor body.
**Expected:** OS file picker opens (click path); drop zone gains pink dashed border during dragover (drag path); "Uploading image…" placeholder appears; on success, `window.prompt` requests alt text; image appears with `<img>` tag.
**Why human:** DirectUpload requires a live Rails server, an ActiveStorage configuration, and browser File API access. The drag-and-drop visual state (CSS class toggling) requires actual DOM events.

#### 3. Image Resize Handles — Browser Interaction

**Test:** Click on an image inside the editor. Observe corner handles, drag a corner to resize.
**Expected:** Four pink corner handles appear around the selected image; dragging a corner updates the `width` attribute in real-time; handles disappear when image is deselected.
**Why human:** Requires ProseMirror selection events, `getBoundingClientRect` calculations, and `mousemove` on `window` — all live-browser behavior.

#### 4. Author Card Visual Rendering

**Test:** View a published blog post at `/blog/:slug` for a post with an author_id set.
**Expected:** Author card renders below the content with avatar (or initials circle), name, job title, bio, and conditional LinkedIn/Twitter links; no card when author_id is null.
**Why human:** Verifies the visual layout and conditional rendering in a real Rails response; also validates that the avatar ActiveStorage variant renders correctly.

---

### Gaps Summary

No gaps found. All 10 must-have truths are VERIFIED. All 7 requirement IDs are SATISFIED. No debt markers exist in phase-modified files. All artifacts are substantive (not stubs), wired to real data sources, and connected through verified key links.

The 4 human verification items above are browser-interaction checks for JavaScript-driven behaviors (Tiptap runtime, ActiveStorage DirectUpload, drag-and-drop visual states, image resize). They do not represent code deficiencies — the implementation is complete.

---

_Verified: 2026-05-22_
_Verifier: Claude (gsd-verifier)_
