# Requirements — Blog CMS & SEO Overhaul

## v1 Requirements

### Editor Core (EDIT)

- [ ] **EDIT-01**: Admin can compose blog content in Tiptap editor (replaces Trix/ActionText; content stored as sanitized HTML in `blogs.body` text column)
- [x] **EDIT-02**: Editor toolbar remains fixed/sticky while admin scrolls long posts
- [x] **EDIT-03**: Admin can apply H1, H2, H3, H4, H5, H6 headings from the toolbar
- [ ] **EDIT-04**: Heading styles render visually inside the editor matching the live page appearance (WYSIWYG via Tailwind prose applied to editor div)
- [ ] **EDIT-05**: Bullet lists and numbered lists render correctly on live published pages (via Tailwind Typography prose classes)
- [x] **EDIT-06**: Existing blog content migrated from ActionText to the new `body` column without data loss (ActionText attachment nodes stripped via Nokogiri)

### Rich Content (RICH)

- [x] **RICH-01**: Admin can insert and edit tables (insert table, add/remove rows and columns) via toolbar
- [ ] **RICH-02**: Admin can upload images inline within blog body; images stored in ActiveStorage and embedded as standard `<img>` tags
- [x] **RICH-03**: Admin can set paragraph spacing style (Normal or Relaxed) per blog post via a dropdown selector

### Author Profile (AUTH)

- [ ] **AUTH-01**: Admin can select an author for a blog post from existing admin users via a dropdown
- [x] **AUTH-02**: Admin users can set their author profile: bio, job title/role, LinkedIn URL, Twitter handle, and avatar image
- [ ] **AUTH-03**: Published blog posts display an author card below the content showing avatar, name, role, bio, and social links (only when author is set)
- [ ] **AUTH-04**: Blog post JSON-LD article schema includes a Person author node when an author is assigned (falls back to Organization when no author)

### SEO Fields (SEO)

- [ ] **SEO-01**: Admin can enter keywords for a blog post; rendered as `<meta name="keywords">` in the page head
- [ ] **SEO-02**: Admin can add FAQ question–answer pairs to a blog post via a dynamic form; rendered as FAQPage JSON-LD schema in the page head
- [ ] **SEO-03**: Admin can override the canonical URL for a blog post; overrides `request.original_url` in the page head
- [ ] **SEO-04**: Admin can upload a separate OG image per blog post for social sharing; falls back to cover photo, then site logo

### Security (SEC)

- [ ] **SEC-01**: Blog body HTML sanitized server-side via `Rails::Html::SafeListSanitizer` before saving; view renders pre-sanitized value (never `raw`)
- [x] **SEC-02**: All JSON-LD `<script>` tags use `json_escape` to prevent `</script>` injection (fix pre-existing bug in `render_article_schema`, `render_breadcrumbs_schema`, `render_product_schema`)

---

## v2 Requirements (Deferred)

- Advanced spacing: per-paragraph margin control via Tiptap custom extension
- Slash-command menu in editor
- Author public listing page
- Content scheduling / draft preview
- Case studies editor migration (clone of blog editor work)

---

## Out of Scope

- Replacing ActionText on non-blog models (legal documents, etc.) — not requested
- Collaborative editing / version history — out of scope
- Third-party SEO gem — all schema logic stays server-side in Rails helpers
- Separate Author model — admin users serve as authors; no orphan risk

---

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| EDIT-01 | Phase 1 | Pending |
| EDIT-02 | Phase 1 | Complete |
| EDIT-03 | Phase 1 | Complete |
| EDIT-04 | Phase 1 | Pending |
| EDIT-05 | Phase 1 | Pending |
| EDIT-06 | Phase 1 | Complete |
| SEC-01 | Phase 1 | Pending |
| SEC-02 | Phase 1 | Complete |
| RICH-01 | Phase 2 | Complete |
| RICH-02 | Phase 2 | Pending |
| RICH-03 | Phase 2 | Complete |
| AUTH-01 | Phase 2 | Pending |
| AUTH-02 | Phase 2 | Complete |
| AUTH-03 | Phase 2 | Pending |
| AUTH-04 | Phase 2 | Pending |
| SEO-01 | Phase 3 | Pending |
| SEO-02 | Phase 3 | Pending |
| SEO-03 | Phase 3 | Pending |
| SEO-04 | Phase 3 | Pending |
