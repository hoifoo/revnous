# Roadmap: Blog CMS & SEO Overhaul

## Overview

Three phases take the blog from a Trix/ActionText editor to a capable, SEO-first publishing tool. Phase 1 replaces the editor and migrates content — the blog must work correctly before anything is added on top. Phase 2 adds rich content capabilities (tables, inline images, paragraph spacing) and full author profiles with structured data. Phase 3 completes the SEO surface: keywords, FAQ schema, canonical URL override, and OG image per post.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Editor Foundation** - Replace Trix with Tiptap, migrate existing content, enforce sanitization and JSON-LD security (completed 2026-05-13)
- [x] **Phase 2: Rich Content & Author Profiles** - Tables, inline images, paragraph spacing, author profile UI, author card on show page, Person schema (completed 2026-05-22)
- [ ] **Phase 3: SEO Fields & FAQ Schema** - Keywords meta, FAQ schema builder, canonical URL override, OG image per post

## Phase Details

### Phase 1: Editor Foundation
**Goal**: As an admin editor, I want to compose blog posts in the new Tiptap editor (replacing Trix) with all existing content migrated intact, so that the marketing team can publish without XSS/injection vulnerabilities or developer involvement.
**Mode:** mvp
**Depends on**: Nothing (first phase)
**Requirements**: EDIT-01, EDIT-02, EDIT-03, EDIT-04, EDIT-05, EDIT-06, SEC-01, SEC-02
**Success Criteria** (what must be TRUE):
  1. Admin can open any blog post and see the Tiptap editor in place of the Trix/ActionText editor
  2. Toolbar stays visible (sticky) while scrolling a long post in the editor
  3. Admin can apply H1 through H6 headings and heading styles match the live page appearance inside the editor
  4. Bullet and numbered lists render correctly on published pages using Tailwind Typography prose classes
  5. All pre-existing blog content is readable and intact after migration; no `<action-text-attachment>` nodes remain in the body column
**Plans**: 3 plans
Plans:
**Wave 1**
- [x] 01-01-PLAN.md — Walking skeleton: npm swap, body column, minimal Tiptap editor with sanitization, factory + show page cutover

**Wave 2** *(blocked on Wave 1 completion)*
- [x] 01-02-PLAN.md — Full toolbar (H1–H6, inline marks, link, undo/redo, disabled table/image stubs) + sticky verification + JSON-LD `json_escape` fix (SEC-02)
- [x] 01-03-PLAN.md — `blogs:migrate_body` Rake task to backfill existing ActionText content into `blogs.body`, stripping `<action-text-attachment>` nodes
**UI hint**: yes

### Phase 2: Rich Content & Author Profiles
**Goal**: Admin can embed tables and images directly in blog posts, control paragraph spacing, and assign an author whose profile card and Person schema appear on the published page
**Mode:** mvp
**Depends on**: Phase 1
**Requirements**: RICH-01, RICH-02, RICH-03, AUTH-01, AUTH-02, AUTH-03, AUTH-04
**Success Criteria** (what must be TRUE):
  1. Admin can insert a table from the toolbar and add or remove rows and columns without leaving the editor
  2. Admin can upload an image inline within the editor body; the image is stored in ActiveStorage and appears as a standard `<img>` tag in the published post
  3. Admin can choose Normal or Relaxed paragraph spacing per post via a dropdown and the change is visible on the published page
  4. Admin users can fill in bio, job title, LinkedIn URL, Twitter handle, and upload an avatar on their profile; admin can select a user as the author on any blog post
  5. Published posts with an author assigned show an author card (avatar, name, role, bio, social links) and the page JSON-LD article schema includes a Person author node
**Plans**: 5 plans
Plans:
**Wave 1**
- [x] 02-P1-PLAN.md — Paragraph spacing slice: blogs.spacing column, dropdown in admin form, prose-paragraph-relaxed class + CSS rule on show page (RICH-03)
- [x] 02-P4-PLAN.md — Admin user CRUD with author profile: bio/job_title/linkedin_url/twitter_handle + avatar attachment, full_name/initials, admin/users routes + views + specs (AUTH-02)

**Wave 2** *(blocked on Wave 1 completion)*
- [x] 02-P2-PLAN.md — Table editing slice: Tiptap table + BubbleMenu extensions, activated toolbar button, sanitizer accepts table tags, model spec proves round-trip (RICH-01)

**Wave 3** *(blocked on Wave 2 completion — shares blog.rb sanitizer + tiptap controller + form)*
- [x] 02-P3-PLAN.md — Inline image upload slice: Tiptap image extension + ActiveStorage DirectUpload, click + drag-and-drop triggers, alt text prompt, resize handles, sanitizer width attribute (RICH-02)

**Wave 4** *(blocked on Wave 3 + Wave 1 P4)*
- [x] 02-P5-PLAN.md — Author wiring slice: blogs.author_id FK, belongs_to :author, admin form dropdown, author card partial on show page, Person/Organization JSON-LD branch (AUTH-01, AUTH-03, AUTH-04)
**UI hint**: yes

### Phase 3: SEO Fields & FAQ Schema
**Goal**: Marketing team can set all SEO metadata fields per post — keywords, canonical URL, OG image, and structured FAQ — without touching code
**Mode:** mvp
**Depends on**: Phase 2
**Requirements**: SEO-01, SEO-02, SEO-03, SEO-04
**Success Criteria** (what must be TRUE):
  1. Admin can enter keywords on the blog form; published page head contains `<meta name="keywords">` with the entered value
  2. Admin can add, edit, and remove FAQ question–answer pairs on the blog form; published page head contains valid FAQPage JSON-LD schema reflecting those pairs
  3. Admin can enter a canonical URL override; published page head uses that URL in the canonical `<link>` tag instead of `request.original_url`
  4. Admin can upload a separate OG image per post; published page uses it as the `og:image` meta tag, falling back to cover photo, then site logo when absent
**Plans**: 4 plans
Plans:
**Wave 1**
- [x] 03-01-PLAN.md — Keywords slice: shared migration (keywords jsonb / faq_schema text / canonical_url_override string) + Blog#og_image attachment + keywords-input Stimulus controller + chip UI + page_keywords helper + layout meta tag (SEO-01)

**Wave 2** *(blocked on 03-01 — shares blog.rb / admin form / admin controller)*
- [x] 03-02-PLAN.md — Canonical URL Override slice: URI::DEFAULT_PARSER validation + admin form field + blogs_controller @canonical_url override (SEO-03)

**Wave 3** *(blocked on 03-02 — shares blog.rb / admin form / admin controller / blogs_controller)*
- [x] 03-03-PLAN.md — OG Image slice: og_image_url model helper + image content-type whitelist + admin form file_field/preview + blogs_controller 3-step fallback chain (SEO-04)

**Wave 4** *(blocked on 03-03 — shares blog.rb / admin form / admin controller / helper / show.html.erb)*
- [ ] 03-04-PLAN.md — FAQ Schema slice: parse_faq_schema callback + faq_pairs reader + faq-builder Stimulus controller + collapsible form section + render_faq_schema helper + visible FAQ section on show + render_article_schema .html_safe cleanup (SEO-02)
**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Editor Foundation | 3/3 | Complete   | 2026-05-13 |
| 2. Rich Content & Author Profiles | 5/5 | Complete   | 2026-05-22 |
| 3. SEO Fields & FAQ Schema | 1/4 | In Progress|  |
