# Walking Skeleton — Blog CMS & SEO Overhaul

**Phase:** 1 (Editor Foundation)
**Generated:** 2026-05-13

## Capability Proven End-to-End

An admin can open `/admin/blogs/:id/edit`, type and format content in the new Tiptap editor (replacing Trix), save the form, and see the saved HTML render on the public `/blog/:slug` page — proving the Stimulus ↔ esbuild ↔ Rails ↔ PostgreSQL round-trip for the new `blogs.body` text column with server-side sanitization.

This is NOT a brand-new application. It is the thinnest end-to-end slice of the NEW feature (Tiptap replaces Trix; HTML stored in plain column with sanitization) layered onto the existing Rails 8 / Stimulus / esbuild stack.

## Architectural Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Editor engine | Tiptap 3.23.2 (`@tiptap/core` + `@tiptap/starter-kit` + `@tiptap/extensions`) | Headless ProseMirror; works with vanilla Stimulus and esbuild ESM output; supports H1–H6, tables, images (Phase 2) without React/Vue (D-01 in CONTEXT, RESEARCH stack table) |
| Storage shape | Plain `blogs.body text` column with HTML string (NOT ActionText) | Avoids `<action-text-attachment>` complexity on public side; one `raw` render call is enough after server-side sanitization (PROJECT.md key decision) |
| Sanitization | `Rails::Html::SafeListSanitizer` in `before_save :sanitize_body` on `Blog` model | Server-side at write time, not render time; safelist locked to `p, br, h1-h6, ul, ol, li, strong, em, a, blockquote, code, pre` for Phase 1 (D-12) |
| Migration mechanism | Schema migration adds column; separate `rake blogs:migrate_body` backfills | Re-runnable; deploy sequence = `db:migrate` then rake; rows in `action_text_rich_texts` remain in DB as rollback path (D-01, D-03) |
| Stimulus wiring | One controller `tiptap_editor_controller.js`; targets `editor` + `input`; lifecycle `connect`/`disconnect`/`teardown` | Standard Stimulus pattern from `hello_controller.js`; `teardown` handles Turbo cache (RESEARCH Pitfall 2) |
| WYSIWYG typography | `prose prose-lg` (Tailwind Typography v4 via `@plugin "@tailwindcss/typography"`) applied to `.ProseMirror` div | Identical classes already used on public blog show page → automatic WYSIWYG match (D-10) |
| Sticky toolbar offset | `sticky top-0 z-10` (NOT `top-16`) | Admin header is `position: static` and scrolls away; `top-0` is correct for static-header layout (RESEARCH Pitfall 1 — overrides UI-SPEC `top-16`) |
| JSON-LD security | `json_escape(schema.to_json)` replacing `schema.to_json.html_safe` across all 4 schema helpers | Prevents `</script>` injection in JSON-LD blocks; applies to `render_organization_schema`, `render_article_schema`, `render_product_schema`, `render_breadcrumbs_schema` (D-14 + RESEARCH SEC-02 note) |
| Directory layout | Existing Rails conventions; no new top-level structure | Files land in `app/javascript/controllers/`, `app/models/`, `app/views/admin/blogs/`, `lib/tasks/`, `db/migrate/` per existing analogs |

## Stack Touched in Phase 1

- [x] Project scaffold — npm packages added (`@tiptap/core`, `@tiptap/starter-kit`, `@tiptap/extensions`, `@tailwindcss/typography`); Trix + `@rails/actiontext` packages removed; esbuild/Tailwind builds run (D-05, D-06)
- [x] Routing — no new routes; existing `admin_blog_path(:id)` edit form and public `blog_path(slug)` show page are the entry points
- [x] Database — `add_column :blogs, :body, :text` migration (one real write path: admin save; one real read path: public show)
- [x] UI — Tiptap Stimulus controller wired to hidden form field; sticky toolbar with H1–H6, bold, italic, strike, lists, link, undo/redo, plus disabled table/image stubs
- [x] Deployment — runs on existing `bin/dev` (Foreman) for local; deploy sequence documented: `db:migrate` then `rake blogs:migrate_body`

## Out of Scope (Deferred to Later Slices)

- Table insert/edit toolbar wiring (Phase 2 — RICH-01; stub button present in Phase 1 but inert)
- Inline image upload via ActiveStorage direct upload (Phase 2 — RICH-02; stub button present in Phase 1 but inert)
- Paragraph spacing control (Normal / Relaxed) per post (Phase 2 — RICH-03)
- Author profile fields on `users` table, author dropdown on blog form, author card on show page, Person schema in JSON-LD (Phase 2 — AUTH-01 through AUTH-04)
- Keywords meta field (Phase 3 — SEO-01)
- FAQ schema builder + FAQPage JSON-LD (Phase 3 — SEO-02)
- Canonical URL override field (Phase 3 — SEO-03)
- OG image per post (Phase 3 — SEO-04)
- Dropping `action_text_rich_texts` rows (never — rollback safety per D-03)
- Replacing ActionText on non-blog models (out of scope, PROJECT.md)

## Subsequent Slice Plan

Each later phase adds one vertical slice on top of this skeleton without altering its architectural decisions:

- **Phase 2 — Rich Content & Author Profiles:** Activates the table and image stub buttons (real Tiptap extensions + ActiveStorage upload endpoint); adds paragraph spacing dropdown; adds author profile fields to `users` + `blogs.author_id` FK; renders author card on show page and Person schema in `render_article_schema`.
- **Phase 3 — SEO Fields & FAQ Schema:** Adds `keywords`, `canonical_url`, `og_image`, `faq_schema` (JSON-serialized) columns on `blogs`; renders meta keywords + FAQPage JSON-LD + override-aware canonical link + override-aware OG image in the head.
