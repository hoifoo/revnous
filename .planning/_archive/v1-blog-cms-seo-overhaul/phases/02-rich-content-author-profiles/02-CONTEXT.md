# Phase 2: Rich Content & Author Profiles - Context

**Gathered:** 2026-05-14
**Status:** Ready for planning

<domain>
## Phase Boundary

Enable tables and inline images in the Tiptap editor (activating disabled stubs from Phase 1), add paragraph spacing control per post, and build full author profiles on admin User records with an author card + Person schema on published posts. Admin user management via a new admin/users CRUD.

**In scope:** RICH-01, RICH-02, RICH-03, AUTH-01, AUTH-02, AUTH-03, AUTH-04
**Out of scope:** SEO fields (Phase 3), public author listing page, case studies editor (deferred)

</domain>

<decisions>
## Implementation Decisions

### Inline Image Upload (RICH-02)

- **D-01:** Admin triggers upload via two methods: hidden file picker (clicking toolbar image button) AND drag-and-drop into the editor body. Both handled in the Tiptap Stimulus controller.
- **D-02:** While upload is in progress, insert a placeholder node with a spinner at the cursor position. Replace with `<img>` on success, remove on error.
- **D-03:** On upload success, inject `rails_blob_path(blob)` (relative, served by Rails) as the `src` attribute. No CDN/S3 in scope — local disk storage only.
- **D-04:** At upload time, prompt admin for alt text (accessibility + SEO). Required before injection.
- **D-05:** Admin can resize inserted images using drag corner handles. Width stored as `width` attribute on `<img>`. On the published show page, the width attribute is respected, capped by the prose column width (`max-width`).
- **D-06:** ActiveStorage direct upload endpoint: `/rails/active_storage/direct_uploads` (Rails built-in). Stimulus controller POSTs presigned upload, then injects blob URL into editor.
- **D-07:** Sanitizer ALLOWED_TAGS already includes `img, figure, figcaption`. ALLOWED_ATTRIBUTES must include `width` (for resize) in addition to existing `src, alt, height`. Table tags (`table, thead, tbody, tr, td, th, colgroup, col`) and `colspan`, `rowspan` attributes added when table extension is enabled.

### Author Legacy Field (AUTH-01)

- **D-08:** `blogs.author` (plain text string) is kept as a legacy fallback — no data migration or nulling out. No new Rake task needed.
- **D-09:** Admin blog form retains both the existing `author` text field AND a new `author_id` dropdown (select of admin users). Both are submitted together.
- **D-10:** Display priority on published post: if `author_id` is set, show the associated User's full profile card (AUTH-03) and use User name. The `author` string field is ignored when `author_id` is present. If `author_id` is null but `author` string exists, show the plain-text byline only (no card).
- **D-11:** Blog model: `belongs_to :author, class_name: 'User', foreign_key: 'author_id', optional: true`. Schema migration adds `author_id bigint references users(id)`.

### Admin User Management (AUTH-02)

- **D-12:** Full CRUD at `admin/users` (index, show, new, create, edit, update, destroy). New resource added to the admin namespace in routes.rb.
- **D-13:** Author profile fields on User: `bio` (text), `job_title` (string), `linkedin_url` (string), `twitter_handle` (string), `has_one_attached :avatar`. These are added via migration.
- **D-14:** On create: admin sets a temporary password directly in the form. Devise's `password` and `password_confirmation` fields in the form. User logs in and changes via Devise password reset flow.
- **D-15:** The User model gains author profile fields in a separate migration from Phase 1 `users` table work. New `admin` boolean or roles check already present via `roles` JSON column — `Admin::UsersController` inherits from `Admin::BaseController` (auth + ensure_admin!).
- **D-16:** `destroy` action: researcher to verify whether destroying a User that has authored blog posts (`author_id` FK) should nullify or restrict. Prefer nullify (`nullify` dependent strategy) so blog posts are not deleted.

### Author Card on Published Post (AUTH-03, AUTH-04)

- **D-17:** Author card rendered below blog content on `blogs/show.html.erb` when `@blog.author_id` is set. Shows: avatar, full name (`first_name last_name`), job title, bio, LinkedIn link, Twitter link (social links shown only when present).
- **D-18:** If admin has no avatar uploaded, show a placeholder avatar (initials or generic icon — researcher picks simplest approach consistent with Tailwind Typography styling).
- **D-19:** `render_article_schema` in ApplicationHelper updated: when `blog.author` (the User association) is present, emit a `Person` author node (`@type: Person, name: user.full_name, url: user.linkedin_url`). Fallback to `Organization` when no `author_id`.

### Table Controls (RICH-01)

- **D-20:** Table editing controls (add row above/below, remove row, add col left/right, remove col, delete table) appear as a Tiptap BubbleMenu that shows when cursor is inside a table cell. Keeps the main toolbar clean.
- **D-21:** Toolbar table stub button (currently disabled) is activated to insert a default 3×3 table with headers.

### Paragraph Spacing (RICH-03)

- **D-22:** `blogs` table gets a `spacing` string column (default `'normal'`). Values: `'normal'` or `'relaxed'`.
- **D-23:** Spacing dropdown is a `<select>` in the admin blog form metadata section (near excerpt/category fields). No JavaScript required — persists on save.
- **D-24:** On the show page, apply a conditional CSS class to the `.prose` container: `prose-relaxed` when `blog.spacing == 'relaxed'`. Custom CSS added to the app stylesheet: `.prose-relaxed p { margin-bottom: 2em }` (or equivalent — researcher to tune the value). Default `normal` uses Tailwind Typography's standard prose spacing.

### Claude's Discretion

- Image placeholder spinner: implementation (inline SVG spinner vs CSS animation) left to researcher/planner.
- Avatar placeholder (no image): initials extraction or generic SVG icon — researcher picks simplest approach.
- Resize handles: researcher to evaluate `@tiptap/extension-image` with `allowBase64` off + custom resize, or a community extension. Must store `width` as HTML attribute, not inline style (sanitizer must allow `width`).
- Table extension: researcher to confirm `@tiptap/extension-table` + `@tiptap/extension-table-row` + `@tiptap/extension-table-cell` + `@tiptap/extension-table-header` package set.
- `destroy` User with authored posts: implement nullify dependency (`dependent: :nullify` or `before_destroy` callback to nullify `blogs.author_id`).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Context
- `.planning/ROADMAP.md` — Phase 2 goal, success criteria, requirement IDs (RICH-01–03, AUTH-01–04)
- `.planning/REQUIREMENTS.md` — Full requirement descriptions for RICH-01–03, AUTH-01–04
- `.planning/PROJECT.md` — Key decisions table, constraints, out-of-scope items

### Phase 1 Decisions (carry forward)
- `.planning/phases/01-editor-foundation/01-CONTEXT.md` — D-07 (toolbar stubs), D-08 (disabled state), D-12/D-13 (sanitizer pattern). Phase 2 extends, not replaces.

### Existing Code (read before touching)
- `app/models/blog.rb` — ALLOWED_TAGS, ALLOWED_ATTRIBUTES, sanitize_body callback, associations
- `app/models/user.rb` — Devise setup, existing columns (first_name, last_name, roles)
- `app/controllers/admin/blogs_controller.rb` — Strong params to extend (author_id, spacing)
- `app/controllers/admin/base_controller.rb` — Inheritance pattern for new Admin::UsersController
- `app/javascript/controllers/tiptap_editor_controller.js` — Existing Stimulus controller; table + image extensions added here
- `app/views/admin/blogs/_form.html.erb` — Form to extend (author dropdown, spacing select)
- `app/views/blogs/show.html.erb` — Show page for author card placement and prose class update
- `app/helpers/application_helper.rb` — render_article_schema to update with Person author node
- `db/schema.rb` — Current blogs and users table structure (no author_id, no spacing, no author profile columns)
- `config/routes.rb` — Admin namespace to add resources :users

No external ADRs or spec documents — all decisions captured above.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `has_one_attached :image` on Blog — exact pattern to replicate as `has_one_attached :avatar` on User
- `Admin::BaseController` — inherit for Admin::UsersController; auth + ensure_admin! included
- `rails_blob_path(blob)` — used for cover image serving; same for inline image blobs
- Tailwind `prose prose-lg max-w-none` on show page — prose container to conditionally add `prose-relaxed`
- Existing toolbar button HTML pattern in `_form.html.erb` — reuse same button structure to activate table/image buttons

### Established Patterns
- `before_save :sanitize_body` — sanitizer runs on save; add table tags + `width` to ALLOWED_TAGS/ALLOWED_ATTRIBUTES in same callback
- `params.require(:blog).permit(...)` — add `author_id`, `spacing` to the permit list
- `scope :published` — no change; author_id is a metadata field, not a scope condition
- Stimulus controller `connect/disconnect` pattern — extend tiptap_editor_controller, not replace

### Integration Points
- `blogs` table: add `author_id bigint references users(id)` + `spacing string default 'normal'`
- `users` table: add `bio text`, `job_title string`, `linkedin_url string`, `twitter_handle string` + `has_one_attached :avatar`
- `config/routes.rb` admin namespace: `resources :users`
- `app/javascript/application.js`: import Tiptap table + image extensions (npm packages)
- `app/views/blogs/show.html.erb`: author card partial below content + conditional prose class

</code_context>

<specifics>
## Specific Ideas

- Table BubbleMenu should show only when cursor is inside a table cell — use Tiptap's `shouldShow` callback on BubbleMenu
- Spacing "Relaxed" visual target: larger paragraph gaps than Tailwind's default prose — exact `margin-bottom` value for researcher to test (2em is a starting point)
- Author card should only render social links that are actually set (LinkedIn, Twitter shown conditionally)
- `render_article_schema` Person node: use `linkedin_url` as the `url` field if present; `sameAs` array for Twitter if present

</specifics>

<deferred>
## Deferred Ideas

- Public author listing/bio pages (`/authors/:slug`) — not requested; out of scope
- Case studies editor — mentioned in PROJECT.md out of scope; not touched in Phase 2
- Advanced image controls (caption field, alignment, float left/right) — not in RICH-02 success criteria; defer if needed
- Drag-and-drop image upload UX on the public show page (reader uploads) — not applicable

</deferred>

---

*Phase: 2-Rich Content & Author Profiles*
*Context gathered: 2026-05-14*
