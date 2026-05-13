# Roadmap: Blog CMS & SEO Overhaul

## Overview

Three phases take the blog from a Trix/ActionText editor to a capable, SEO-first publishing tool. Phase 1 replaces the editor and migrates content — the blog must work correctly before anything is added on top. Phase 2 adds rich content capabilities (tables, inline images, paragraph spacing) and full author profiles with structured data. Phase 3 completes the SEO surface: keywords, FAQ schema, canonical URL override, and OG image per post.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Editor Foundation** - Replace Trix with Tiptap, migrate existing content, enforce sanitization and JSON-LD security
- [ ] **Phase 2: Rich Content & Author Profiles** - Tables, inline images, paragraph spacing, author profile UI, author card on show page, Person schema
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
- [ ] 01-03-PLAN.md — `blogs:migrate_body` Rake task to backfill existing ActionText content into `blogs.body`, stripping `<action-text-attachment>` nodes
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
**Plans**: TBD
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
**Plans**: TBD
**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Editor Foundation | 2/3 | In Progress|  |
| 2. Rich Content & Author Profiles | 0/TBD | Not started | - |
| 3. SEO Fields & FAQ Schema | 0/TBD | Not started | - |
