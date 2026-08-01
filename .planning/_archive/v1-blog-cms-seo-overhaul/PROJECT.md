# Blog CMS & SEO Overhaul

## What This Is

A set of targeted improvements to the Revnous admin blog section that replace the default Trix/ActionText editor with Tiptap, add full author profile support linked to admin users, and extend the SEO/schema tooling with keywords, FAQ schema, canonical URL, and OG image override fields. The goal is to make the blog a capable, SEO-first publishing tool for a marketing freelancer without needing developer involvement for routine content.

## Core Value

Marketing team can publish well-formatted, fully SEO-optimized blog posts from the admin UI without touching code or workarounds.

## Requirements

### Validated

- ✓ Blog CRUD with title, author text field, category, excerpt, slug, published_at — existing
- ✓ Basic meta_title and meta_description fields — existing
- ✓ Article + Breadcrumb JSON-LD schema rendering — existing
- ✓ Cover image via ActiveStorage — existing
- ✓ Related articles and share section on blog show page — existing

### Active

- [ ] Replace Trix with Tiptap editor (sticky toolbar, H1–H6, bullet/numbered lists, tables, body images, spacing control)
- [ ] Heading preview rendered correctly inside editor (WYSIWYG heading styles)
- [ ] Inline image uploads in body content via ActiveStorage direct upload
- [ ] Author profile linked to admin User (avatar, bio, role/title, LinkedIn, Twitter)
- [ ] Author profile card rendered on blog show page
- [ ] Author Person schema emitted in JSON-LD when author is set
- [ ] Keywords meta field on blog form
- [ ] FAQ schema builder (Q&A pairs) → FAQPage JSON-LD
- [ ] Canonical URL override per blog post
- [ ] OG image override (separate from cover photo)

### Out of Scope

- Case studies editor improvements — not requested, can be added later as a clone
- Public author pages/listing — not requested
- Content scheduling / draft previews — deferred, current published_at blank = draft is sufficient
- Replacing ActionText on other models (legal documents, etc.) — out of scope for this milestone

## Context

- Stack: Ruby on Rails 8, ActionText (currently), Trix 2.x, Stimulus, Tailwind CSS 4, esbuild
- Current editor: `has_rich_text :content` in Blog model → rendered via `<%= @blog.content %>` wrapped in `.prose.prose-lg` div
- Tiptap migration: replace ActionText rich text with a plain `body` text column storing HTML; Stimulus controller wraps Tiptap; `raw @blog.body` on show page
- Author model: `User` via Devise; need author profile columns on `users` table + `has_one_attached :avatar` + `blogs.author_id` FK
- SEO: `ApplicationHelper` already has `render_article_schema`, `render_breadcrumbs_schema`; article schema hardcodes author as Organization — needs Person support
- Content rendering: live pages use Tailwind Typography (`prose prose-lg`); Tiptap HTML output must be compatible with `prose` classes

## Constraints

- **Tech stack**: Must stay on Rails/Stimulus/esbuild — no React/Vue frontend frameworks
- **Editor storage**: Tiptap output stored as sanitized HTML in a plain `text` column (not ActionText) to simplify rendering and avoid `<action-text-attachment>` dependencies on the public side
- **Image uploads**: Use ActiveStorage direct uploads; Tiptap image extension configured to POST to existing Rails blob endpoint
- **No external SEO plugins**: All SEO/schema logic stays server-side in Rails helpers — no third-party SEO gem

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Replace Trix with Tiptap | Trix cannot natively support H2-H6, tables, or paragraph spacing. Tiptap is modular and works with esbuild. | — Pending |
| Store HTML in plain `body` column | Avoids ActionText's attachment complexity on the public side; Tiptap outputs standard HTML | — Pending |
| Author = admin User | Reuse existing Devise user accounts rather than a separate Author model — simpler, no orphan risk | — Pending |
| Author profile columns on `users` table | Author profile (bio, role, social) belongs to the user; blogs reference via FK | — Pending |
| FAQ stored as JSON in `faq_schema` text column | Flexible structure for Q&A pairs; serialized/deserialized in the model | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-05-13 after initialization*
