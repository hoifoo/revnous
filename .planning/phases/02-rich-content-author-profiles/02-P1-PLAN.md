---
phase: 02-rich-content-author-profiles
plan: P1
type: execute
wave: 1
depends_on: []
files_modified:
  - db/migrate/YYYYMMDDHHMMSS_add_spacing_to_blogs.rb
  - db/schema.rb
  - app/controllers/admin/blogs_controller.rb
  - app/views/admin/blogs/_form.html.erb
  - app/views/blogs/show.html.erb
  - app/assets/stylesheets/application.tailwind.css
  - spec/requests/admin/blogs_spec.rb
autonomous: true
requirements: [RICH-03]
tags: [rails-migration, blog-form, tailwind, paragraph-spacing]

must_haves:
  truths:
    - "Admin can edit a blog post and select 'Normal' or 'Relaxed' from a Paragraph Spacing dropdown in the form metadata grid [D-23]"
    - "Submitting the blog form with 'relaxed' selected persists blogs.spacing = 'relaxed' [D-22]"
    - "Visiting /blog/:slug for a blog with spacing='relaxed' shows the content wrapper with the additional class 'prose-paragraph-relaxed' [D-24]"
    - "When spacing='relaxed' is in effect, the live CSS rule '.prose-paragraph-relaxed p { margin-bottom: 2em }' applies to paragraphs in the prose container [D-24]"
    - "Default value for blogs.spacing is 'normal' for both new and existing rows [D-22]"
    - "Existing admin blog request spec continues to pass; a new request spec proves the spacing field round-trips"
  artifacts:
    - path: "db/migrate/*_add_spacing_to_blogs.rb"
      provides: "Schema migration adding blogs.spacing string column with default 'normal'"
      contains: "add_column :blogs, :spacing, :string, default: \"normal\", null: false"
    - path: "app/controllers/admin/blogs_controller.rb"
      provides: "blog_params permit list extended with :spacing"
      contains: ":spacing"
    - path: "app/views/admin/blogs/_form.html.erb"
      provides: "Paragraph Spacing dropdown rendered inside metadata grid"
      contains: "form.select :spacing"
    - path: "app/views/blogs/show.html.erb"
      provides: "Content prose container conditionally adds 'prose-paragraph-relaxed' class when spacing == 'relaxed'"
      contains: "prose-paragraph-relaxed"
    - path: "app/assets/stylesheets/application.tailwind.css"
      provides: "Custom CSS rule for relaxed paragraph spacing"
      contains: ".prose-paragraph-relaxed p"
  key_links:
    - from: "app/views/admin/blogs/_form.html.erb"
      to: "app/controllers/admin/blogs_controller.rb#blog_params"
      via: "form.select :spacing posts blog[spacing] which must be in permit list"
      pattern: "form\\.select :spacing"
    - from: "app/controllers/admin/blogs_controller.rb"
      to: "blogs.spacing column"
      via: "params.require(:blog).permit(... :spacing ...) reaches Blog#update"
      pattern: ":spacing"
    - from: "app/views/blogs/show.html.erb"
      to: "blogs.spacing column"
      via: "Embedded ERB conditional that toggles the prose-paragraph-relaxed class on the .prose wrapper"
      pattern: "@blog\\.spacing"
    - from: "app/assets/stylesheets/application.tailwind.css"
      to: "rendered .prose-paragraph-relaxed wrapper on show page"
      via: ".prose-paragraph-relaxed p selector targets paragraph children inside the wrapper"
      pattern: "\\.prose-paragraph-relaxed p"
---

<objective>
## Phase Goal

**As an** admin editor, **I want to** choose between Normal and Relaxed paragraph spacing per blog post via a simple dropdown, **so that** I can give long-form posts more breathing room on the published page without writing CSS.

This is the **first vertical slice** of Phase 2. It is intentionally the lightest end-to-end change in the phase — column, permit, form input, show-page wrapper class, CSS rule — and exercises the full migration → controller → view → public-page flow before more complex editor features land. Once this ships, the blog form already has a metadata-grid slot that future plans (P5 author dropdown) will sit next to.

**Purpose:** Activate per-post paragraph spacing control (RICH-03) end-to-end.
**Output:** New `blogs.spacing` column with default `"normal"`; spacing dropdown in admin form; conditional `prose-paragraph-relaxed` wrapper class on show page; CSS rule that increases paragraph `margin-bottom` to `2em`; one new request spec proving the round-trip.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/REQUIREMENTS.md
@.planning/phases/02-rich-content-author-profiles/02-CONTEXT.md
@.planning/phases/02-rich-content-author-profiles/02-UI-SPEC.md
@CLAUDE.md

@app/controllers/admin/blogs_controller.rb
@app/views/admin/blogs/_form.html.erb
@app/views/blogs/show.html.erb
@app/assets/stylesheets/application.tailwind.css
@spec/requests/admin/blogs_spec.rb
@db/migrate/20260513121220_add_body_to_blogs.rb

<interfaces>
<!-- Tailwind Typography prose plugin already imported via `@plugin "@tailwindcss/typography"` -->
<!-- Default .prose paragraph margin is approximately 1.25em — relaxed bumps it to 2em -->
<!-- Existing form metadata grid uses: <div class="grid grid-cols-1 md:grid-cols-2 gap-6"> with per-field wrappers -->
<!-- Existing show page content wrapper at app/views/blogs/show.html.erb is: -->
<!--   <div class="prose prose-lg max-w-none mb-16"> -->
<!-- Existing strong params permit list shape in blog_params (admin/blogs_controller.rb): -->
<!--   permitted = %i[title author published_at category excerpt body featured featured_on_home image meta_title meta_description] -->
<!--   permitted << :slug if action_name == 'create' -->
<!--   params.require(:blog).permit(*permitted, product_ids: []) -->
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add blogs.spacing column with default 'normal' and extend strong params</name>
  <files>db/migrate/YYYYMMDDHHMMSS_add_spacing_to_blogs.rb, db/schema.rb, app/controllers/admin/blogs_controller.rb</files>
  <read_first>
    - db/migrate/20260513121220_add_body_to_blogs.rb (last migration — copy its `ActiveRecord::Migration[8.0]` style and single `add_column` shape)
    - db/schema.rb (lines 121–136, `create_table "blogs"` block — confirm no existing `spacing` column)
    - app/controllers/admin/blogs_controller.rb (current `blog_params` permit list — extend without reordering existing entries)
    - .planning/phases/02-rich-content-author-profiles/02-CONTEXT.md (D-22: `blogs.spacing` string default `'normal'`; values `'normal'` or `'relaxed'`)
  </read_first>
  <action>
Generate a new migration named `add_spacing_to_blogs` using `bin/rails generate migration AddSpacingToBlogs spacing:string`. Edit the generated migration so the single `add_column` call sets `default: "normal"` and `null: false`. The migration class must inherit from `ActiveRecord::Migration[8.0]` (matching the most recent migration). Run `bin/rails db:migrate` so `db/schema.rb` regenerates with the new column.

Extend `app/controllers/admin/blogs_controller.rb` `blog_params` private method: add `:spacing` to the `permitted` array (place it right after `:meta_description`). Do NOT change the `:slug` branch, the `product_ids: []` mass-assignment, or the order of any existing entries.

Do NOT touch the Blog model — there is no validation or sanitization to add for this column. Do NOT change the show page or form in this task — those happen in Task 2.
  </action>
  <verify>
    <automated>bin/rails runner "raise 'spacing column missing' unless Blog.column_names.include?('spacing'); raise 'wrong default' unless Blog.columns_hash['spacing'].default == 'normal'; raise 'should be NOT NULL' if Blog.columns_hash['spacing'].null"</automated>
    <automated>grep -q ':spacing' app/controllers/admin/blogs_controller.rb</automated>
  </verify>
  <acceptance_criteria>
    - Running `bin/rails runner "puts Blog.columns_hash['spacing'].sql_type"` prints a string type (e.g. `character varying`)
    - `Blog.columns_hash['spacing'].default` equals `"normal"`
    - `Blog.columns_hash['spacing'].null` is `false`
    - `app/controllers/admin/blogs_controller.rb` contains the literal token `:spacing` inside `blog_params`
    - `db/schema.rb` `create_table "blogs"` block contains `t.string "spacing"` with the `default: "normal"` and `null: false` modifiers
    - `db/schema.rb` version line uses a timestamp greater than `2026_05_13_121220`
  </acceptance_criteria>
  <done>Spacing column exists in the database with default `"normal"` NOT NULL, schema.rb reflects the column, and the admin blogs controller permits the `spacing` parameter on create and update.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Add Paragraph Spacing dropdown to blog form, conditional prose class to show page, and relaxed CSS rule</name>
  <files>app/views/admin/blogs/_form.html.erb, app/views/blogs/show.html.erb, app/assets/stylesheets/application.tailwind.css, spec/requests/admin/blogs_spec.rb</files>
  <read_first>
    - app/views/admin/blogs/_form.html.erb (lines 15–77 metadata grid — locate the existing Category field to place Spacing nearby; confirm shared input class string `w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-pink-500 focus:border-transparent`)
    - app/views/blogs/show.html.erb (line 61 — the exact wrapper `<div class="prose prose-lg max-w-none mb-16">` that gets the conditional extra class)
    - app/assets/stylesheets/application.tailwind.css (top of file — confirm `@plugin "@tailwindcss/typography"` is already imported and that existing custom rules use `@apply` or plain CSS)
    - .planning/phases/02-rich-content-author-profiles/02-UI-SPEC.md (§7 Paragraph Spacing Dropdown — copy block, helper text, class names verbatim; §6 last bullet `prose-paragraph-relaxed` NOT `prose-relaxed`)
    - spec/requests/admin/blogs_spec.rb (existing PATCH /update spec — extend with new spacing assertion using the same `sign_in admin` setup)
  </read_first>
  <behavior>
    - Rendering the admin blog form shows a `<select name="blog[spacing]">` element with two options: value `"normal"` (label "Normal") and value `"relaxed"` (label "Relaxed").
    - The Spacing dropdown defaults to `"normal"` for new blogs (no spacing persisted yet).
    - PATCH `/admin/blogs/:id` with `params[:blog][:spacing] = "relaxed"` updates `blog.spacing` to `"relaxed"`.
    - Visiting `/blog/:slug` for a blog with `spacing == "relaxed"` renders the content wrapper `<div>` with the literal substring `prose-paragraph-relaxed` in its class list.
    - Visiting `/blog/:slug` for a blog with `spacing == "normal"` renders the content wrapper `<div>` WITHOUT the substring `prose-paragraph-relaxed`.
    - The compiled CSS contains a rule body for selector `.prose-paragraph-relaxed p` that sets `margin-bottom: 2em`.
  </behavior>
  <action>
Edit `app/views/admin/blogs/_form.html.erb` and add a Spacing dropdown inside the existing metadata grid (the `<div class="grid grid-cols-1 md:grid-cols-2 gap-6">` block that holds Category, Published At, SEO Title, SEO Description, Slug). Insert the new field wrapper immediately after the Category field wrapper. Use the form-field shape from UI-SPEC §7:
- Label text "Paragraph Spacing", standard label class `block text-sm font-medium text-gray-700 mb-2`.
- `form.select :spacing` with options `[["Normal", "normal"], ["Relaxed", "relaxed"]]`, selected default `@blog.spacing || "normal"`, classes matching every other input in this grid: `w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-pink-500 focus:border-transparent`.
- Helper text below: `<p class="text-sm text-gray-500 mt-1">Relaxed adds more space between paragraphs</p>` (verbatim from UI-SPEC Copywriting table).
Do NOT remove or reorder any existing field. Do NOT change the body/Tiptap section.

Edit `app/views/blogs/show.html.erb`: locate the content wrapper line (currently `<div class="prose prose-lg max-w-none mb-16">`). Replace it with the conditional variant from UI-SPEC §7 such that the class list becomes `prose prose-lg max-w-none mb-16 prose-paragraph-relaxed` when `@blog.spacing == 'relaxed'` and remains the original class list otherwise. The conditional must use the literal class name `prose-paragraph-relaxed` (NOT Tailwind Typography's built-in `prose-relaxed`). Do NOT change the inner `<%= sanitize @blog.body, ... %>` rendering.

Edit `app/assets/stylesheets/application.tailwind.css`: append a new rule block (after the existing `.tiptap-editor` rules) that sets `margin-bottom: 2em` on `p` elements inside `.prose-paragraph-relaxed`. Use a plain CSS selector — do NOT use `@apply` and do NOT use Tailwind Typography modifier syntax. The selector is exactly `.prose-paragraph-relaxed p`.

Extend `spec/requests/admin/blogs_spec.rb` with one new example inside the existing `describe "PATCH /update"` block: it patches `admin_blog_path(blog)` with `params: { blog: { spacing: "relaxed" } }`, reloads the blog, and asserts `blog.spacing == "relaxed"`. Reuse the existing `let(:admin)`, `let(:blog)`, and `before { sign_in admin }`. Do NOT modify the existing meta-fields example.
  </action>
  <verify>
    <automated>grep -q 'form\.select :spacing' app/views/admin/blogs/_form.html.erb</automated>
    <automated>grep -q 'prose-paragraph-relaxed' app/views/blogs/show.html.erb</automated>
    <automated>grep -q '\.prose-paragraph-relaxed p' app/assets/stylesheets/application.tailwind.css</automated>
    <automated>bundle exec rspec spec/requests/admin/blogs_spec.rb -e "PATCH /update"</automated>
    <automated>npm run build:css</automated>
  </verify>
  <acceptance_criteria>
    - `app/views/admin/blogs/_form.html.erb` contains the literal string `form.select :spacing` and both option labels `"Normal"` and `"Relaxed"`
    - `app/views/admin/blogs/_form.html.erb` contains the helper text `Relaxed adds more space between paragraphs`
    - `app/views/blogs/show.html.erb` contains the literal substring `prose-paragraph-relaxed` and references `@blog.spacing == 'relaxed'` (or equivalent string compare)
    - `app/assets/stylesheets/application.tailwind.css` contains a rule with selector `.prose-paragraph-relaxed p` and declaration `margin-bottom: 2em`
    - `bundle exec rspec spec/requests/admin/blogs_spec.rb` exits 0
    - New spec example PATCHes `blog[spacing] = "relaxed"`, reloads, asserts `blog.spacing == "relaxed"`, and passes
    - `npm run build:css` exits 0 (CSS still compiles cleanly)
  </acceptance_criteria>
  <done>Spacing dropdown is visible in admin form, defaults to Normal, persists to the DB on submit, public show page wraps content in `prose-paragraph-relaxed` only when `spacing == 'relaxed'`, and the CSS rule increases paragraph bottom margin to 2em in that case.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| browser→Rails (admin form) | Admin posts `blog[spacing]` — untrusted string until validated |
| stored value→show page render | `@blog.spacing` value flows into class attribute |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-02-P1-01 | Tampering | `params[:blog][:spacing]` | mitigate | Strong params only permit `:spacing`; the show page hard-compares against the literal string `'relaxed'` — any other value (including injection attempts) falls through to the default class list, so untrusted content cannot reach the rendered class attribute |
| T-02-P1-02 | Information Disclosure | spacing column | accept | Spacing value is purely presentational metadata, not sensitive — no PII, no access control needed |
| T-02-P1-03 | Tampering (XSS via class injection) | show page wrapper class | mitigate | The class string is computed in ERB by a literal-string comparison, not by interpolating `@blog.spacing` directly into the class attribute — even if `spacing` contained `"><script>`, it would never reach the rendered HTML |
</threat_model>

<verification>
- Migration runs cleanly: `bin/rails db:migrate` produces no errors and `db/schema.rb` includes `spacing` on the blogs table
- Admin form renders with the Paragraph Spacing dropdown visible
- PATCH spec passes proving the round-trip from form to DB
- Public show page diff shows the conditional class only when `spacing == 'relaxed'`
- CSS build succeeds with the new rule present in the compiled stylesheet
</verification>

<success_criteria>
- Phase Success Criterion #3 satisfied: "Admin can choose Normal or Relaxed paragraph spacing per post via a dropdown and the change is visible on the published page"
- Requirement RICH-03 traceable in `requirements:` frontmatter and via the spec example
- All existing tests still green (no regression)
</success_criteria>

<output>
After completion, create `.planning/phases/02-rich-content-author-profiles/02-P1-SUMMARY.md` summarizing: migration timestamp, column default verified, dropdown placement, show-page conditional wrapper, CSS rule shipped, request-spec example added.
</output>
</output>
