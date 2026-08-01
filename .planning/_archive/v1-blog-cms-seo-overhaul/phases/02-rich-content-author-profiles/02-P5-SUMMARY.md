---
phase: "02-rich-content-author-profiles"
plan: "P5"
subsystem: "blog-author-wiring"
tags: [rails-migration, foreign-key, belongs-to, json-ld, schema-person, author-card, tdd]
dependency_graph:
  requires: [P1, P4]
  provides: [author-card-partial, person-schema, author_id-fk]
  affects: [blogs-show, admin-blogs-form, application-helper]
tech_stack:
  added: []
  patterns:
    - "belongs_to :author with class_name redirect for natural association name"
    - "write_attribute pattern for legacy text column coexisting with AR association"
    - "json_escape(...).html_safe pattern for content_tag script blocks"
    - "TDD RED/GREEN pattern for helper + request specs"
key_files:
  created:
    - db/migrate/20260519210037_add_author_id_to_blogs.rb
    - app/views/blogs/_author_card.html.erb
    - spec/helpers/application_helper_spec.rb
  modified:
    - db/schema.rb
    - app/models/blog.rb
    - app/models/user.rb
    - app/controllers/admin/blogs_controller.rb
    - app/views/admin/blogs/_form.html.erb
    - app/views/blogs/show.html.erb
    - app/helpers/application_helper.rb
    - spec/factories/blogs.rb
    - spec/requests/admin/blogs_spec.rb
decisions:
  - "D-11 implemented: belongs_to :author, class_name: User, FK: author_id, optional: true"
  - "D-16 implemented: dependent: :nullify on User + on_delete: :nullify on FK for double safety"
  - "D-10 implemented: legacy byline uses @blog[:author] only when @blog.author.nil?"
  - "D-19 implemented: Person node with conditional url/sameAs; Organization fallback"
  - "author= setter conflict resolved: blog_params removes :author from permit; controller sets @blog[:author] directly"
  - "json_escape(...).html_safe required for content_tag to not double-encode JSON in script tags"
metrics:
  duration: "~55 minutes active (session gap during execution)"
  completed_date: "2026-05-22"
  tasks_completed: 2
  files_modified: 11
---

# Phase 02 Plan P5: Blog Author Wiring — Summary

**One-liner:** FK `blogs.author_id → users(id)` with `on_delete: :nullify`, `belongs_to :author` on Blog, author card partial, admin form dropdown, and `Person` JSON-LD author node with `Organization` fallback.

---

## What Was Built

### Task 1: Schema, Models, Controller, Factory

**Migration (`20260519210037_add_author_id_to_blogs.rb`):**
- `add_reference :blogs, :author, null: true, foreign_key: { to_table: :users, on_delete: :nullify }`
- Creates `t.bigint "author_id"` column, `index_blogs_on_author_id`, and `add_foreign_key "blogs", "users", column: "author_id", on_delete: :nullify` in schema.rb

**Blog model (`app/models/blog.rb`):**
- Added `belongs_to :author, class_name: "User", foreign_key: "author_id", optional: true` above `has_and_belongs_to_many :products`
- This reassigns `blog.author` from the legacy text column to a User|nil association

**User model (`app/models/user.rb`):**
- Added `has_many :authored_blogs, class_name: "Blog", foreign_key: "author_id", dependent: :nullify`
- AR-level nullify paired with DB-level `on_delete: :nullify` for defense-in-depth

**Admin controller (`app/controllers/admin/blogs_controller.rb`):**
- Removed `:author` from `blog_params` permit list (would conflict with association setter)
- Added `:author_id` to permit list
- Added `@blog[:author] = params.dig(:blog, :author).presence` in both `create` and `update` to write legacy text directly to the raw column

**Show page (`app/views/blogs/show.html.erb`):**
- Legacy byline now uses `<% if @blog.author.nil? && @blog[:author].present? %>` and `<%= @blog[:author] %>` (D-10 priority rule)

**Factory (`spec/factories/blogs.rb`):**
- Added `transient do; author_user { nil }; end` + `after(:build) { |blog, evaluator| blog.author = evaluator.author_user if evaluator.author_user }`

### Task 2: Admin Dropdown, Author Card, Schema, Specs (TDD)

**Admin form (`app/views/admin/blogs/_form.html.erb`):**
- `:author` text field now uses `value: @blog[:author]` to read raw column (not association)
- New `collection_select :author_id` dropdown with `User.order(:first_name)`, blank option `"— No author profile —"`, helper text per UI-SPEC §8

**Author card partial (`app/views/blogs/_author_card.html.erb`) — new file:**
- Conditionally renders on `@blog.author.present?`
- Avatar: `image_tag` when attached, initials placeholder `bg-gray-200 w-16 h-16 rounded-full` otherwise
- "Written by" label + full_name + conditional job_title, bio, LinkedIn link, Twitter link
- All social links conditional on `.present?`, with `rel="noopener noreferrer"` (T-02-P5-04)

**Show page (`app/views/blogs/show.html.erb`):**
- `<%= render "author_card" %>` inserted after content prose block, before Share Section

**Application helper (`app/helpers/application_helper.rb`):**
- `render_article_schema` delegates author to `author_schema_node(article)`
- `json_escape(schema.to_json).html_safe` — `.html_safe` added so `content_tag` does not double-encode JSON
- Private `author_schema_node`: returns Person hash (with conditional url/sameAs) when `article.author.is_a?(User)`, else Organization fallback

**Specs:**
- `spec/helpers/application_helper_spec.rb` (new): 4 examples — Person with social links, Person without social links, Organization fallback, json_escape XSS protection
- `spec/requests/admin/blogs_spec.rb`: added author_id + legacy author text round-trip example

---

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] belongs_to :author setter conflicts with legacy author text column assignment**
- **Found during:** Task 2 RED phase (request spec failure)
- **Issue:** Adding `belongs_to :author` makes `blog.author=` an association setter expecting a User. Passing `author: "Legacy Byline"` via `blog_params` caused `ActiveRecord::AssociationTypeMismatch`
- **Fix:** Removed `:author` from `blog_params` permit list; controller now writes legacy text directly via `@blog[:author] = params.dig(:blog, :author).presence` in both `create` and `update`; form's text field uses `value: @blog[:author]` to read raw column
- **Files modified:** `app/controllers/admin/blogs_controller.rb`, `app/views/admin/blogs/_form.html.erb`
- **Commit:** a37e45b (test), 8ec5fe0 (fix in implementation)

**2. [Rule 1 - Bug] json_escape result double-encoded by content_tag**
- **Found during:** Task 2 GREEN phase (helper spec failure)
- **Issue:** `json_escape(schema.to_json)` returns a non-html_safe String. When passed to `content_tag`, Rails HTML-encodes it (turning `"` into `&quot;`), producing broken JSON in the script tag
- **Fix:** Changed to `json_escape(schema.to_json).html_safe` — `json_escape` already handles `<`, `>`, `&` escaping for XSS prevention; `.html_safe` tells content_tag to embed the result verbatim
- **Files modified:** `app/helpers/application_helper.rb`
- **Commit:** 8ec5fe0

**3. [Rule 1 - Bug] Test assertion '"url":' too broad — matched publisher.logo.url**
- **Found during:** Task 2 GREEN phase  
- **Issue:** The `expect(output).not_to include('"url":')` check in the "omits url" test case was matching the publisher's logo `"url"` field in the JSON, causing a false failure
- **Fix:** Updated test to parse the JSON and check `schema.dig("author")` hash directly for missing keys
- **Files modified:** `spec/helpers/application_helper_spec.rb`
- **Commit:** 8ec5fe0

---

## Threat Surface Scan

| Flag | File | Description |
|------|------|-------------|
| (none new) | | All surfaces were in the plan's threat model (T-02-P5-01 through T-02-P5-07) |

Security mitigations confirmed implemented:
- **T-02-P5-01:** `json_escape(...).html_safe` in `render_article_schema` — `</script>` injection prevented; helper spec asserts this
- **T-02-P5-02:** `linkedin_url` URL-validated at User model layer (P4); `link_to` escapes href
- **T-02-P5-03:** `twitter_handle` normalized (strip `@`) at User model; interpolated into `https://twitter.com/` prefix
- **T-02-P5-04:** All external links use `rel="noopener noreferrer"`
- **T-02-P5-05:** `dependent: :nullify` + DB `on_delete: :nullify` — blog preserved when user deleted

---

## Spec Coverage Matrix

| Spec File | What's Covered |
|-----------|----------------|
| `spec/helpers/application_helper_spec.rb` | Person author with linkedin+twitter; Person without social links; Organization fallback; json_escape XSS |
| `spec/requests/admin/blogs_spec.rb` | author_id FK + legacy author text round-trip via PATCH |

All 56 examples pass, 0 failures, 5 pre-existing pending stubs.

---

## Known Stubs

None — all fields are wired to real data sources.

---

## Self-Check: PASSED

Files exist:
- `db/migrate/20260519210037_add_author_id_to_blogs.rb` — FOUND
- `app/views/blogs/_author_card.html.erb` — FOUND
- `spec/helpers/application_helper_spec.rb` — FOUND

Commits exist:
- `40e394d` (Task 1: FK, models, controller, factory, show-page byline) — FOUND
- `a37e45b` (TDD RED: tests + controller bug fix) — FOUND
- `8ec5fe0` (TDD GREEN: form, partial, show page, helper, spec fix) — FOUND
