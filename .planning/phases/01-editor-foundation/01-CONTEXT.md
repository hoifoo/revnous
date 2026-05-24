# Phase 1: Editor Foundation - Context

**Gathered:** 2026-05-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Replace the Trix/ActionText editor on the admin blog form with a Tiptap-powered Stimulus controller, migrate all existing blog content to a new plain `blogs.body` text column, and fix server-side XSS vulnerabilities in JSON-LD schema helpers. The blog must work correctly end-to-end before Phase 2 adds rich content and author profiles.

**In scope:** EDIT-01, EDIT-02, EDIT-03, EDIT-04, EDIT-05, EDIT-06, SEC-01, SEC-02
**Out of scope:** Tables (RICH-01), inline images (RICH-02), paragraph spacing (RICH-03), author profiles (AUTH-*), all SEO fields (SEO-*)

</domain>

<decisions>
## Implementation Decisions

### Content Migration (EDIT-06)
- **D-01:** Migration approach = Rake task. Schema migration adds `blogs.body text` column; a separate `rake blogs:migrate_body` task backfills content. Can be re-run if it fails partway. Deploy sequence = `db:migrate` then `rake blogs:migrate_body` (documented in deploy notes).
- **D-02:** ActionText attachment nodes — strip silently via Nokogiri. `<action-text-attachment>` tags removed; surrounding text preserved intact.
- **D-03:** Clean cutover — remove `has_rich_text :content` from Blog model in the same commit that adds Tiptap. The `action_text_rich_texts` table rows stay in DB untouched (safe rollback path) but no app code reads them after migration.

### ActionText / Trix Cleanup
- **D-04:** Remove `has_rich_text :content` declaration from `app/models/blog.rb`.
- **D-05:** Remove `import "trix"` and `import "@rails/actiontext"` from `app/javascript/application.js`.
- **D-06:** Remove `trix` npm package from `package.json`. The `actiontext` Rails gem stays (it's bundled inside Rails 8 and cannot be removed without forking the gemspec).

### Tiptap Toolbar (EDIT-02, EDIT-03)
- **D-07:** Build the full toolbar in Phase 1 — include Phase 2 feature buttons (table insert, image upload) now as disabled stubs to avoid rework. Active in Phase 1: H1–H6, bold, italic, strikethrough, bullet list, ordered list, link, undo, redo.
- **D-08:** Disabled stub buttons (table, image) appear greyed out (`opacity-50`, `cursor-not-allowed`) with a "Coming soon" tooltip on hover. No click handler. Enabled + wired up in Phase 2.
- **D-09:** Toolbar uses `position: sticky` with a `top` offset matching the admin navbar height so it stays at the top of the viewport while scrolling without overlapping the nav.

### WYSIWYG Heading Styles (EDIT-04)
- **D-10:** Apply `prose prose-lg` (Tailwind Typography) directly to the `.ProseMirror` contenteditable div so heading styles inside the editor match the live published page automatically. No custom CSS duplication needed.
- **D-11:** If admin layout styles bleed in, scope it as `.tiptap-editor .ProseMirror.prose` — researcher/planner to verify with Tailwind CSS 4 Typography behavior.

### Sanitization (SEC-01)
- **D-12:** HTML sanitized via `Rails::Html::SafeListSanitizer` in a `before_save` callback on the Blog model. Safelist for Phase 1: `p, br, h1, h2, h3, h4, h5, h6, ul, ol, li, strong, em, a, blockquote, code, pre`. Table tags (`table, thead, tbody, tr, td, th`) added in Phase 2 when tables are introduced.
- **D-13:** View renders pre-sanitized body with `raw @blog.body` — sanitization happens once at save, not on every render.

### JSON-LD Security (SEC-02)
- **D-14:** Replace `.to_json.html_safe` with `json_escape(schema.to_json)` in `ApplicationHelper` for `render_article_schema`, `render_breadcrumbs_schema`, and `render_product_schema`. This prevents `</script>` injection in JSON-LD blocks.

### Claude's Discretion
- **Migration cutover:** Clean cutover chosen (no dual-read period). Researcher/planner should verify there are no other callers of `blog.content` in views or helpers before removing `has_rich_text`.
- **ActionText gem:** Keep Rails actiontext gem; removal is not feasible without significant effort.
- **WYSIWYG scoping:** If `prose` classes conflict with admin layout in Tailwind CSS 4, researcher should find the correct scoping approach — preference is zero custom CSS duplication.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Context
- `.planning/ROADMAP.md` — Phase 1 goal, success criteria, requirement IDs
- `.planning/REQUIREMENTS.md` — Full EDIT-01–06, SEC-01–02 requirement descriptions
- `.planning/PROJECT.md` — Key decisions table, constraints, context section

### Existing Code (read before touching these files)
- `app/models/blog.rb` — Current Blog model with `has_rich_text :content`, validations, scopes
- `app/javascript/application.js` — Current Trix/ActionText imports to remove
- `app/helpers/application_helper.rb` — `render_article_schema`, `render_breadcrumbs_schema` helpers with SEC-02 bug
- `app/views/admin/blogs/_form.html.erb` — Admin blog form to replace Trix field with Tiptap
- `app/views/admin/blogs/edit.html.erb` — Blog edit view

No external ADRs or spec documents — all decisions captured above.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `app/helpers/application_helper.rb#render_article_schema` — existing Article JSON-LD helper; SEC-02 fix applies here
- Tailwind Typography (`prose prose-lg`) — already applied on the public blog show page; WYSIWYG uses same classes
- ActiveStorage + `has_one_attached :image` pattern on Blog — image upload pattern exists for Phase 2 inline images (reference, not Phase 1 work)
- `Admin::BaseController` — all admin controllers inherit auth + ensure_admin; Tiptap controller will live in `app/javascript/controllers/`

### Established Patterns
- Stimulus controllers: snake_case filenames in `app/javascript/controllers/`, auto-loaded via `index.js`
- Model callbacks: `before_validation` pattern used for slug generation; SEC-01 sanitization should follow same `before_save` style
- Strong params: `params.require(:blog).permit(...)` in `Admin::BlogsController` — must add `:body` and remove `:content`
- esbuild bundles `app/javascript/**` — Tiptap installed via npm, imported in new Stimulus controller

### Integration Points
- `Blog` model → add `body:text` column via migration, remove `has_rich_text :content`, add `before_save :sanitize_body`
- `Admin::BlogsController` → update strong params to permit `:body`, remove `:content`
- `app/javascript/application.js` → remove Trix/ActionText imports, Stimulus auto-loads the new controller
- `app/views/admin/blogs/_form.html.erb` → replace `<%= form.rich_text_area :content %>` with Tiptap editor div
- `app/views/blogs/show.html.erb` (public) → verify it renders `raw @blog.body` inside `.prose.prose-lg` container

</code_context>

<specifics>
## Specific Ideas

- Toolbar sticky offset must account for the admin navbar height — researcher to measure or use a CSS variable
- "Coming soon" tooltip on disabled buttons: simple CSS `title` attribute or a lightweight Stimulus tooltip is fine — no external tooltip library
- Rake task should print progress (e.g., "Migrated 12/47 posts") so the operator knows it's working during production deploy

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within Phase 1 scope.

</deferred>

---

*Phase: 1-Editor Foundation*
*Context gathered: 2026-05-13*
