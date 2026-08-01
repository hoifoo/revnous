---
phase: 02-rich-content-author-profiles
plan: P5
type: execute
wave: 4
depends_on: [P1, P4]
files_modified:
  - db/migrate/YYYYMMDDHHMMSS_add_author_id_to_blogs.rb
  - db/schema.rb
  - app/models/blog.rb
  - app/models/user.rb
  - app/controllers/admin/blogs_controller.rb
  - app/views/admin/blogs/_form.html.erb
  - app/views/blogs/_author_card.html.erb
  - app/views/blogs/show.html.erb
  - app/helpers/application_helper.rb
  - spec/factories/blogs.rb
  - spec/requests/admin/blogs_spec.rb
  - spec/helpers/application_helper_spec.rb
autonomous: true
requirements: [AUTH-01, AUTH-03, AUTH-04]
tags: [rails-migration, foreign-key, json-ld, author-card, schema-person]

must_haves:
  truths:
    - "Schema migration adds blogs.author_id (bigint, nullable, references users) with an index [D-11]"
    - "Blog model gains belongs_to :author, class_name: 'User', foreign_key: 'author_id', optional: true [D-11]"
    - "User model gains has_many :authored_blogs, class_name: 'Blog', foreign_key: 'author_id', dependent: :nullify (deleting a user nullifies blogs.author_id rather than destroying the blog) [D-16]"
    - "Admin blog form shows an Author Profile dropdown listing existing users by full_name, with blank option '— No author profile —' [D-09]"
    - "PATCH /admin/blogs/:id with author_id persists the FK; the legacy author text field remains submittable in parallel [D-08, D-09]"
    - "When a blog has author_id set, /blog/:slug renders the author card partial with avatar/full_name/job_title/bio and conditional LinkedIn + Twitter links [D-10, D-17]"
    - "When a blog has author_id null but the legacy author text is set, the plain-text byline remains in the meta row and NO author card renders [D-08, D-10, D-18]"
    - "render_article_schema emits a Person author node (with linkedin_url as url and twitter sameAs array) when blog.author is present; falls back to Organization Revnous when no author_id [D-19]"
    - "Deleting a User who authored blog posts nullifies those blogs' author_id (no FK violation, no blog deletion) [D-16]"
    - "Helper spec asserts both Person and Organization branches of render_article_schema; request spec asserts blog form persists author_id; integration check verifies the show page renders the card [D-19]"
  artifacts:
    - path: "db/migrate/*_add_author_id_to_blogs.rb"
      provides: "Migration adding blogs.author_id with FK to users(id) and nullify dependency at the DB level for safety"
      contains: "add_reference :blogs, :author"
    - path: "app/models/blog.rb"
      provides: "belongs_to :author, optional: true with class_name and foreign_key"
      contains: "belongs_to :author"
    - path: "app/models/user.rb"
      provides: "has_many :authored_blogs with dependent: :nullify"
      contains: "has_many :authored_blogs"
    - path: "app/views/admin/blogs/_form.html.erb"
      provides: "Author Profile dropdown using form.collection_select :author_id below the existing :author text field"
      contains: "collection_select :author_id"
    - path: "app/views/blogs/_author_card.html.erb"
      provides: "Author card partial rendered only when @blog.author is present"
      contains: "Written by"
    - path: "app/views/blogs/show.html.erb"
      provides: "Renders <%= render 'author_card' %> immediately before the Share Section"
      contains: "render 'author_card'"
    - path: "app/helpers/application_helper.rb"
      provides: "render_article_schema updated to emit Person author when blog.author present, Organization fallback otherwise"
      contains: "Person"
    - path: "spec/helpers/application_helper_spec.rb"
      provides: "Spec covering both author schema branches"
      contains: "render_article_schema"
  key_links:
    - from: "app/views/admin/blogs/_form.html.erb"
      to: "app/controllers/admin/blogs_controller.rb#blog_params"
      via: "form.collection_select :author_id posts blog[author_id] which must appear in permit list"
      pattern: ":author_id"
    - from: "app/models/blog.rb#author"
      to: "users.id via blogs.author_id"
      via: "belongs_to :author, class_name: 'User', foreign_key: 'author_id', optional: true"
      pattern: "belongs_to :author"
    - from: "app/models/user.rb#authored_blogs"
      to: "blogs.author_id"
      via: "has_many :authored_blogs, class_name: 'Blog', foreign_key: 'author_id', dependent: :nullify"
      pattern: "dependent: :nullify"
    - from: "app/views/blogs/show.html.erb"
      to: "app/views/blogs/_author_card.html.erb"
      via: "<%= render 'author_card' %> placed after the content prose block and before the Share Section"
      pattern: "render ['\"]author_card['\"]"
    - from: "app/views/blogs/_author_card.html.erb"
      to: "User#full_name + User#initials + user.avatar + linkedin_url + twitter_handle"
      via: "ERB conditionals render each social link only when present?"
      pattern: "@blog\\.author"
    - from: "app/helpers/application_helper.rb#render_article_schema"
      to: "schema.org Article + nested Person/Organization author node"
      via: "schema[:author] = blog.author ? Person hash : Organization hash; content_tag :script, json_escape(schema.to_json)"
      pattern: "\"@type\": \"Person\""
---

<objective>
## Phase Goal

**As a** reader on a Revnous blog post, **I want to** see who wrote the article (avatar, name, role, bio, social links) and have search engines understand the author via Person structured data, **so that** the blog feels personal and authoritative and the Person → sameAs graph gets indexed.

This is the **fifth and final vertical slice** of Phase 2 — the wiring that connects users (P4) to blogs and surfaces them on both the admin form, the public page, and the JSON-LD article schema. It must run AFTER P1 (the form's metadata grid layout is set), P2 (sanitizer state), P3 (image upload — independent but uses the same form), and P4 (User profile attributes exist).

**Purpose:** Wire `blogs.author_id` to `users`, surface the author on the published page, and emit Person JSON-LD (AUTH-01, AUTH-03, AUTH-04).
**Output:** Migration adding `blogs.author_id` FK + index; `Blog#belongs_to :author, optional: true`; `User#has_many :authored_blogs, dependent: :nullify`; Author Profile dropdown in the admin blog form; admin strong params permit `:author_id`; new `_author_card.html.erb` partial; show page renders the card; `render_article_schema` emits Person/Organization; specs cover the wiring.
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
@.planning/phases/02-rich-content-author-profiles/02-P1-PLAN.md
@.planning/phases/02-rich-content-author-profiles/02-P4-PLAN.md
@CLAUDE.md

@app/models/blog.rb
@app/models/user.rb
@app/controllers/admin/blogs_controller.rb
@app/views/admin/blogs/_form.html.erb
@app/views/blogs/show.html.erb
@app/helpers/application_helper.rb
@spec/requests/admin/blogs_spec.rb
@spec/factories/blogs.rb

<interfaces>
<!-- Existing render_article_schema (app/helpers/application_helper.rb, current shape): -->
<!--   schema = { -->
<!--     "@context": "https://schema.org", -->
<!--     "@type": "Article", -->
<!--     "headline": article.title, -->
<!--     "description": article.meta_description || article.excerpt, -->
<!--     "image": article.cover_photo_url, -->
<!--     "datePublished": article.created_at.iso8601, -->
<!--     "dateModified": article.updated_at.iso8601, -->
<!--     "author": { "@type": "Organization", "name": "Revnous" }, -->
<!--     "publisher": { "@type": "Organization", "name": "Revnous", "logo": { "@type": "ImageObject", "url": asset_url("logo.png") } } -->
<!--   } -->
<!--   content_tag :script, json_escape(schema.to_json), type: "application/ld+json" -->

<!-- Plan P1 already added :spacing to permit list — preserve that change -->
<!-- Plan P4 adds: User#full_name, User#initials, has_one_attached :avatar, validates :linkedin_url, normalize_twitter_handle -->

<!-- Existing show page meta row (lines 22–37 of blogs/show.html.erb) — keep the legacy byline -->
<!--   <% if @blog.author.present? %> ... by <%= @blog.author %> ... <% end %> -->
<!-- D-10: legacy author text remains as fallback when author_id is null. -->
<!-- After this plan, @blog.author is the ASSOCIATION (User|nil), not the text string. -->
<!-- The legacy text column will be referenced as @blog[:author] or @blog.read_attribute(:author) to avoid collision. -->

<!-- D-11: belongs_to :author, class_name: 'User', foreign_key: 'author_id', optional: true -->
<!-- D-16: prefer dependent: :nullify -->
<!-- D-19: render_article_schema Person node with name + url(linkedin_url) + sameAs(twitter) -->
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add blogs.author_id FK migration, Blog belongs_to :author (optional), User has_many :authored_blogs with dependent: :nullify, extend admin strong params, and patch the show-page meta row to reference the legacy text via read_attribute</name>
  <files>db/migrate/YYYYMMDDHHMMSS_add_author_id_to_blogs.rb, db/schema.rb, app/models/blog.rb, app/models/user.rb, app/controllers/admin/blogs_controller.rb, app/views/blogs/show.html.erb, spec/factories/blogs.rb</files>
  <read_first>
    - db/migrate/20260513121220_add_body_to_blogs.rb (Rails 8.0 migration style)
    - db/schema.rb (blogs table lines 121–136 — confirm no `author_id` yet)
    - app/models/blog.rb (post-P2 state — has `has_one_attached :image`, `has_and_belongs_to_many :products`, ALLOWED_TAGS extended; add belongs_to ABOVE the validations to keep relations grouped at the top, matching the existing structure)
    - app/models/user.rb (post-P4 state — devise, avatar, validations, full_name/initials helpers, normalize_twitter_handle)
    - app/controllers/admin/blogs_controller.rb (current `blog_params` list — must already include `:spacing` from P1; append `:author_id`)
    - app/views/blogs/show.html.erb (lines 32–37 — the existing `by <%= @blog.author %>` byline references the legacy text column; after `belongs_to :author` is added this same call would return a User|nil, breaking the byline)
    - .planning/phases/02-rich-content-author-profiles/02-CONTEXT.md (D-08 keep legacy column, D-10 priority rule, D-11 association definition, D-16 dependent strategy)
    - spec/factories/blogs.rb (current factory — add an `:authored` trait so other specs can create blogs with a user author)
  </read_first>
  <action>
**Migration:**

Generate `bin/rails generate migration AddAuthorIdToBlogs author:references`. Rails will produce `add_reference :blogs, :author, foreign_key: { to_table: :users }`. Edit the migration so the reference is explicitly `null: true` (Rails default is true for `add_reference` but make it explicit so the FK is nullable for the `dependent: :nullify` strategy to work at the DB level). The FK constraint must be `foreign_key: { to_table: :users, on_delete: :nullify }` so that DB-level user deletion ALSO nullifies the column (defense-in-depth alongside the AR `dependent: :nullify`). Run `bin/rails db:migrate` and confirm `db/schema.rb` shows `t.bigint "author_id"` on the blogs table, an index, and an `add_foreign_key "blogs", "users", column: "author_id", on_delete: :nullify` entry at the bottom.

**Blog model (`app/models/blog.rb`):**

1. Above the existing `has_and_belongs_to_many :products` line (so all relations cluster), add:
   - `belongs_to :author, class_name: "User", foreign_key: "author_id", optional: true`

Important: this REASSIGNS the semantics of `blog.author`. Previously `blog.author` returned the legacy text string column; now it returns a User instance or nil. The legacy column is preserved on the schema (D-08), but is now accessible only via `read_attribute(:author)` or `blog[:author]`. This is the intentional design.

Do NOT remove the `:author` text column. Do NOT add a `belongs_to :author_user` (we use the natural `:author` name per D-11). Do NOT change validations or scopes.

**User model (`app/models/user.rb`):**

2. Add: `has_many :authored_blogs, class_name: "Blog", foreign_key: "author_id", dependent: :nullify`

This pairs with the DB-level `on_delete: :nullify` from the migration as defense-in-depth.

**Admin controller (`app/controllers/admin/blogs_controller.rb`):**

3. Extend the `blog_params` `permitted` array to include `:author_id` (place it right after `:spacing` added in P1, alphabetically optional).

**Show page legacy byline (`app/views/blogs/show.html.erb`):**

4. The current `by <%= @blog.author %>` will now print `#<User:…>` instead of the text. Change the meta-row conditional in lines ~32–37 so the legacy text byline reads the raw column, and ONLY renders when no author user is assigned (so the new author card is the single source of attribution when present). Specifically:

   - Replace the existing `<% if @blog.author.present? %>` block with `<% if @blog.author.nil? && @blog[:author].present? %>` and inside it print `<%= @blog[:author] %>` (legacy text byline, no author card). This implements D-10's third bullet: "if author_id is null but author string exists, show the plain-text byline only (no card)".
   - Keep the surrounding markup (category badge, date, span classes) identical.

Do NOT add the author card render here — Task 2 handles that.

**Factory (`spec/factories/blogs.rb`):**

5. Add a trait so tests can create blogs with an author user:
   ```
   trait :with_author do
     author_user { association :user, :admin }
     after(:build) { |blog, evaluator| blog.author = evaluator.author_user if evaluator.respond_to?(:author_user) }
   end
   ```
   Simpler alternative (preferred) — add a `transient` block:
   - Inside the existing `factory :blog do … end`, add:
     - `transient do; author_user { nil }; end`
     - `after(:build) { |blog, evaluator| blog.author = evaluator.author_user if evaluator.author_user }`

   This keeps the default factory unchanged but lets specs do `create(:blog, author_user: some_user)`.
  </action>
  <verify>
    <automated>bin/rails runner "raise 'author_id missing' unless Blog.column_names.include?('author_id'); raise 'wrong assoc' unless Blog.reflect_on_association(:author).options[:class_name] == 'User'; raise 'not optional' unless Blog.reflect_on_association(:author).options[:optional] == true"</automated>
    <automated>bin/rails runner "raise 'authored_blogs missing' unless User.reflect_on_association(:authored_blogs); raise 'wrong dependent' unless User.reflect_on_association(:authored_blogs).options[:dependent] == :nullify"</automated>
    <automated>grep -q ':author_id' app/controllers/admin/blogs_controller.rb</automated>
    <automated>grep -E '@blog\[:author\]|@blog\.read_attribute\(:author\)' app/views/blogs/show.html.erb</automated>
    <automated>bin/rails runner "u = User.create!(email: 'tx@ex.com', password: 'password123', password_confirmation: 'password123', first_name: 'T', last_name: 'X'); b = Blog.create!(title: 'T', body: '<p>x</p>'); b.update!(author: u); raise 'belongs_to broke' unless b.reload.author == u; u.destroy!; raise 'nullify failed' unless b.reload.author_id.nil?"</automated>
  </verify>
  <acceptance_criteria>
    - `db/schema.rb` blogs table contains `t.bigint "author_id"` and `index ["author_id"]`
    - `db/schema.rb` has `add_foreign_key "blogs", "users", column: "author_id", on_delete: :nullify`
    - `Blog.reflect_on_association(:author).options` includes `class_name: "User"`, `foreign_key: "author_id"`, `optional: true`
    - `User.reflect_on_association(:authored_blogs).options` includes `class_name: "Blog"`, `foreign_key: "author_id"`, `dependent: :nullify`
    - `Admin::BlogsController#blog_params` permit list includes `:author_id`
    - `app/views/blogs/show.html.erb` references the legacy column as `@blog[:author]` (or `@blog.read_attribute(:author)`) — NOT bare `@blog.author`, since that now returns a User
    - Round-trip smoke check: creating a user, attaching as blog.author, destroying the user → blog reloads with `author_id == nil` (no FK violation, no blog deletion)
    - Factory accepts `author_user:` transient and assigns it via `after(:build)`
  </acceptance_criteria>
  <done>Schema and model wiring complete; legacy byline retained behind the no-author-user branch; strong params permit author_id; user deletion nullifies the FK at both AR and DB level; factory supports authored-blog construction.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Add Author Profile dropdown to admin blog form, create _author_card partial, render it on show page, update render_article_schema with Person node, and add request + helper specs</name>
  <files>app/views/admin/blogs/_form.html.erb, app/views/blogs/_author_card.html.erb, app/views/blogs/show.html.erb, app/helpers/application_helper.rb, spec/requests/admin/blogs_spec.rb, spec/helpers/application_helper_spec.rb</files>
  <read_first>
    - app/views/admin/blogs/_form.html.erb (post-P3 state — the metadata grid; the legacy `:author` text field at lines 21–24 must be retained per D-09; the new `:author_id` dropdown sits below it)
    - app/views/blogs/show.html.erb (after Task 1 edit — meta row now uses `@blog[:author]`; content prose block; Share Section is the next sibling — the author card render goes between them)
    - app/helpers/application_helper.rb (lines 64–88 — `render_article_schema` shape; reuse the `content_tag :script, json_escape(schema.to_json), type: "application/ld+json"` ending)
    - .planning/phases/02-rich-content-author-profiles/02-UI-SPEC.md (§8 author dropdown markup, §11 author card partial — copy the entire ERB block; §11 visual rules — `border border-gray-200 rounded-xl p-6 mb-16`; Copywriting table — "Author Profile" label, "— No author profile —" blank, dropdown helper text)
    - .planning/phases/02-rich-content-author-profiles/02-CONTEXT.md (D-09 retain both fields, D-17 card placement, D-18 placeholder, D-19 Person schema rules)
    - spec/requests/admin/blogs_spec.rb (after P1 — add new example covering author_id round-trip)
    - spec/helpers (this directory may or may not exist — create if missing)
  </read_first>
  <behavior>
    - Admin blog form shows both the legacy `:author` text field AND a new `:author_id` `<select>` with options drawn from `User.order(:first_name)`, displaying `:full_name`, with `include_blank: "— No author profile —"`.
    - PATCH /admin/blogs/:id with `params[:blog][:author_id] = "<id>"` and `params[:blog][:author] = "Legacy"` persists BOTH fields; reload confirms `blog.author == User#<id>` and `blog[:author] == "Legacy"`.
    - Visiting `/blog/:slug` for a blog with `author_id` set renders a partial containing the literal string "Written by" plus the author's `full_name`, job title, bio, and conditional LinkedIn/Twitter links.
    - When `linkedin_url` is blank on the author, the LinkedIn link is NOT rendered (no empty anchor).
    - When `twitter_handle` is blank, the Twitter link is NOT rendered.
    - When the author has no avatar attached, an initials placeholder div with `bg-gray-200` renders the author's `initials` value.
    - Visiting `/blog/:slug` for a blog with `author_id` null and legacy text still set renders the plain-text byline in the meta row and DOES NOT render the author card.
    - `render_article_schema(blog)` with a blog whose `author` association returns a User produces JSON-LD with `"author": { "@type": "Person", "name": "<full_name>", "url": "<linkedin_url or empty>", "sameAs": ["https://twitter.com/<handle>"] }` — `sameAs` only present when twitter handle is set; `url` only present when linkedin_url is set.
    - `render_article_schema(blog)` with a blog whose author is nil produces JSON-LD with `"author": { "@type": "Organization", "name": "Revnous" }` (existing fallback).
    - All emitted JSON-LD passes through `json_escape` (existing pattern from SEC-02).
  </behavior>
  <action>
**Admin blog form (`app/views/admin/blogs/_form.html.erb`):**

1. Locate the existing `:author` text field at the top of the metadata grid (lines ~21–24). KEEP this field unchanged — it implements D-09's legacy-text-retention requirement.

2. Immediately AFTER the existing `:author` field wrapper, add a new wrapper containing the Author Profile dropdown. Use UI-SPEC §8 verbatim:
   - Label "Author Profile" with class `block text-sm font-medium text-gray-700 mb-2`.
   - `form.collection_select :author_id, User.order(:first_name), :id, :full_name, { include_blank: "— No author profile —", selected: @blog.author_id }, class: "w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-pink-500 focus:border-transparent"`
   - Helper text: `<p class="text-sm text-gray-500 mt-1">Overrides the Author text field when set. Select an admin user to show their full profile card on the published post.</p>`

3. Do NOT remove or reorder any other field (Spacing from P1, Category, Published At, etc.).

**Author card partial (`app/views/blogs/_author_card.html.erb`) — new file:**

4. Implement the partial from UI-SPEC §11 verbatim. Outer wrapper:
   - `<% if @blog.author.present? %>` … `<% end %>` so the partial is a no-op when no author is assigned.
   - `<div class="author-card border border-gray-200 rounded-xl p-6 mb-16 flex items-start gap-5">`

   Avatar block:
   - `<div class="flex-shrink-0">` containing either `image_tag @blog.author.avatar, class: "w-16 h-16 rounded-full object-cover", alt: @blog.author.full_name` (when attached) or an initials placeholder div `<div class="w-16 h-16 rounded-full bg-gray-200 flex items-center justify-center" aria-label="<%= @blog.author.full_name %>"><span class="text-base font-semibold text-gray-500" aria-hidden="true"><%= @blog.author.initials %></span></div>`.

   Text content block:
   - `<div class="flex-1 min-w-0">`
   - `<p class="text-xs font-semibold text-gray-400 uppercase tracking-wide mb-1">Written by</p>`
   - `<p class="text-base font-semibold text-gray-900"><%= @blog.author.full_name %></p>`
   - Conditional `<% if @blog.author.job_title.present? %><p class="text-sm text-gray-500 mb-2"><%= @blog.author.job_title %></p><% end %>`
   - Conditional `<% if @blog.author.bio.present? %><p class="text-base text-gray-600 leading-relaxed mb-3"><%= @blog.author.bio %></p><% end %>`
   - Social links block `<div class="flex items-center gap-4">`:
     - Conditional LinkedIn: only when `@blog.author.linkedin_url.present?`. `link_to @blog.author.linkedin_url, target: "_blank", rel: "noopener noreferrer", class: "text-sm text-pink-600 hover:text-pink-700 font-medium inline-flex items-center gap-1"` with body "LinkedIn".
     - Conditional Twitter: only when `@blog.author.twitter_handle.present?`. `link_to "https://twitter.com/#{@blog.author.twitter_handle.delete_prefix('@')}", target: "_blank", rel: "noopener noreferrer", class: "text-sm text-pink-600 hover:text-pink-700 font-medium inline-flex items-center gap-1"` with body "Twitter". (`delete_prefix('@')` is redundant since the User model normalizes the handle, but kept defensive.)

**Show page (`app/views/blogs/show.html.erb`):**

5. Locate the closing `</div>` of the content prose block (currently around line 63 — `<div class="prose prose-lg max-w-none ...">…</div>`). Immediately after this closing tag, before the Share Section comment, add `<%= render "author_card" %>`. Do NOT pass `blog: @blog` — the partial reads `@blog` directly per UI-SPEC §11. Do NOT touch the Share Section markup or anything after it.

**Helper (`app/helpers/application_helper.rb`):**

6. Refactor `render_article_schema(article)` so the `:author` key is computed by a new private helper `author_schema_node(article)` (place it in the same `private` block at the bottom of the helper):
   - If `article.respond_to?(:author) && article.author.is_a?(User)` (defensive — works both for blogs and any other model passed in): build a Person hash.
   - Person hash:
     - `"@type": "Person"`
     - `"name": article.author.full_name`
     - Add `"url": article.author.linkedin_url` only if `article.author.linkedin_url.present?`
     - Add `"sameAs": ["https://twitter.com/#{article.author.twitter_handle}"]` only if `article.author.twitter_handle.present?`
   - Else: keep the existing Organization fallback `{ "@type": "Organization", "name": "Revnous" }`.

   Replace the inline `"author": { "@type": "Organization", "name": "Revnous" }` literal in `render_article_schema` with `"author": author_schema_node(article)`. Do NOT change the `publisher`, `headline`, `description`, `image`, `datePublished`, or `dateModified` keys. Do NOT change the `content_tag :script, json_escape(schema.to_json), type: "application/ld+json"` final line.

**Request spec (`spec/requests/admin/blogs_spec.rb`):**

7. Add one new example inside the existing `describe "PATCH /update"` block:
   - "updates the author_id and preserves the legacy author text byline":
     - `user = create(:user, :admin)`
     - `patch admin_blog_path(blog), params: { blog: { author_id: user.id, author: "Legacy Byline" } }`
     - `expect(response).to redirect_to(admin_blogs_path)`
     - `blog.reload`
     - `expect(blog.author).to eq(user)`
     - `expect(blog[:author]).to eq("Legacy Byline")`

**Helper spec (`spec/helpers/application_helper_spec.rb`) — new file (create the directory `spec/helpers/` if missing):**

8. Create the file with `require 'rails_helper'` and `RSpec.describe ApplicationHelper, type: :helper do`. Add `describe "#render_article_schema"`:

   - Example "emits Person author node when blog.author is a User with linkedin and twitter":
     - `user = create(:user, first_name: "Ada", last_name: "Lovelace", linkedin_url: "https://linkedin.com/in/ada", twitter_handle: "ada")`
     - `blog = create(:blog, author_user: user)`
     - `output = helper.render_article_schema(blog)`
     - `expect(output).to include('"@type":"Person"')` (note: `to_json` produces no spaces after colon by default)
     - `expect(output).to include('"name":"Ada Lovelace"')`
     - `expect(output).to include('"url":"https://linkedin.com/in/ada"')`
     - `expect(output).to include('"sameAs":["https://twitter.com/ada"]')`

   - Example "omits url and sameAs when linkedin_url and twitter_handle are blank":
     - `user = create(:user, first_name: "Ada", last_name: "Lovelace", linkedin_url: nil, twitter_handle: nil)`
     - `blog = create(:blog, author_user: user)`
     - `output = helper.render_article_schema(blog)`
     - `expect(output).to include('"@type":"Person"')`
     - `expect(output).to include('"name":"Ada Lovelace"')`
     - `expect(output).not_to include('"url":')`
     - `expect(output).not_to include('"sameAs":')`

   - Example "falls back to Organization author when blog has no author user":
     - `blog = create(:blog)` (no author user)
     - `output = helper.render_article_schema(blog)`
     - `expect(output).to include('"@type":"Organization"')`
     - `expect(output).to include('"name":"Revnous"')`

   - Example "json_escape protects against </script> injection in title":
     - `blog = create(:blog, title: "Hack </script><script>alert(1)</script>")`
     - `output = helper.render_article_schema(blog)`
     - `expect(output).not_to match(/<\/script><script>alert/i)`
     - `expect(output).to match(/Hack/)` (the safe-escaped form remains)
  </action>
  <verify>
    <automated>grep -q 'collection_select :author_id' app/views/admin/blogs/_form.html.erb</automated>
    <automated>test -f app/views/blogs/_author_card.html.erb</automated>
    <automated>grep -q "render \"author_card\"\|render 'author_card'" app/views/blogs/show.html.erb</automated>
    <automated>grep -q '"@type": "Person"\|"@type":"Person"\|@type.*Person' app/helpers/application_helper.rb</automated>
    <automated>bundle exec rspec spec/requests/admin/blogs_spec.rb spec/helpers/application_helper_spec.rb</automated>
  </verify>
  <acceptance_criteria>
    - `app/views/admin/blogs/_form.html.erb` contains `collection_select :author_id` and the verbatim blank label `— No author profile —`
    - The legacy `:author` text field is still present in the form (not removed)
    - `app/views/blogs/_author_card.html.erb` exists, conditionally renders on `@blog.author.present?`, includes the literal strings `Written by`, references `@blog.author.full_name`, `@blog.author.initials`, `@blog.author.linkedin_url`, `@blog.author.twitter_handle`
    - LinkedIn and Twitter links each render only when the corresponding User attribute `.present?`
    - `app/views/blogs/show.html.erb` invokes `render "author_card"` exactly once, placed after the closing tag of the `prose prose-lg max-w-none` content wrapper
    - `app/helpers/application_helper.rb` has `author_schema_node` private method that returns a Person hash for User authors and Organization hash otherwise; `render_article_schema` uses `author_schema_node(article)` for the `:author` value
    - `render_article_schema` still uses `json_escape(schema.to_json)`
    - `bundle exec rspec spec/requests/admin/blogs_spec.rb spec/helpers/application_helper_spec.rb` exits 0
    - Helper spec asserts both Person (with and without optional fields) and Organization branches
    - Helper spec asserts json_escape still protects against `</script>` injection (SEC-02 carry-over)
    - Request spec confirms author_id and legacy author text both round-trip
  </acceptance_criteria>
  <done>Admin form has Author Profile dropdown alongside the retained legacy text field, public show page renders the author card when an author is assigned, JSON-LD article schema emits Person/Organization correctly, and specs prove every branch including json_escape safety.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Admin form → blogs.author_id | Admin posts a user id; FK is enforced at DB level via add_reference foreign_key |
| User.linkedin_url, User.twitter_handle → public page link_to + JSON-LD | URLs are interpolated into href attributes and into JSON-LD url/sameAs; XSS risk if not validated/escaped |
| Blog title/body → render_article_schema | Title flows into JSON-LD as headline; must pass through json_escape to prevent `</script>` injection |
| User deletion → blogs.author_id | Cascade behavior must be nullify (not destroy) to preserve published content |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-02-P5-01 | Tampering (XSS via JSON-LD `</script>` injection) | render_article_schema | mitigate | Continue using `json_escape(schema.to_json)` (existing SEC-02 fix); helper spec asserts `</script>` in title is escaped to `</script>` and does NOT appear verbatim |
| T-02-P5-02 | Tampering (XSS via linkedin_url) | _author_card partial + JSON-LD | mitigate | User#linkedin_url is validated against `URI::DEFAULT_PARSER.make_regexp(%w[http https])` in P4 — rejects `javascript:` and `data:` schemes before persistence; `link_to` further escapes the href value |
| T-02-P5-03 | Tampering (XSS via twitter_handle) | _author_card partial + JSON-LD | mitigate | User#normalize_twitter_handle strips the `@` and the handle is interpolated into the URL `https://twitter.com/<handle>` — any HTML-special characters in the handle are URL-encoded by Rails when passed through `link_to`; in JSON-LD they pass through `json_escape` |
| T-02-P5-04 | Tampering (broken link / open redirect via target=_blank) | author card social links | mitigate | All external links use `rel="noopener noreferrer"` (verbatim from UI-SPEC §11) to prevent window.opener-based reverse tabnabbing |
| T-02-P5-05 | Information Disclosure (deleting a user reveals private blog posts) | User#destroy cascade | mitigate | `dependent: :nullify` (model) + `on_delete: :nullify` (DB) — blog stays published, just loses author attribution. This is the explicit D-16 product decision. |
| T-02-P5-06 | Tampering (admin assigns arbitrary author_id) | blog_params permit list | accept | Admin is trusted; any User row is valid as an author. No additional restriction needed. |
| T-02-P5-07 | Information Disclosure (admin form leaks user list to non-admins) | admin/blogs#edit | accept | Only admins reach `/admin/blogs/*` per Admin::BaseController gate; user dropdown rendering is admin-only |
</threat_model>

<verification>
- Migration applies cleanly, FK is created with on_delete: :nullify
- Model smoke check: creating User+Blog, attaching, destroying user → blog reloads with author_id nil
- Admin form renders the Author Profile dropdown
- /blog/:slug renders the author card when author_id set, nothing when not
- Helper spec passes for Person, Person-with-blanks, Organization, and json_escape branches
- Request spec passes for author_id + legacy text round-trip
- No existing test regresses (P1, P2, P3 specs still green)
</verification>

<success_criteria>
- Phase Success Criterion #4 (second half) and #5 satisfied: admin can select author on blog post; published post shows author card and Person JSON-LD
- Requirements AUTH-01, AUTH-03, AUTH-04 covered end-to-end
- json_escape safety (SEC-02) carried forward — no XSS regression
- Phase 2 complete after P5 ships — all seven requirement IDs satisfied
</success_criteria>

<output>
After completion, create `.planning/phases/02-rich-content-author-profiles/02-P5-SUMMARY.md` summarizing: migration timestamp + FK shape, model association decisions, admin form addition, partial creation, show-page integration point, helper refactor (Person/Organization branch), spec coverage matrix.
</output>
</output>
