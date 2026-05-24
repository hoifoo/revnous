---
phase: 02-rich-content-author-profiles
plan: P1
subsystem: blog-cms
tags: [rails-migration, blog-form, tailwind, paragraph-spacing, tdd]
dependency_graph:
  requires: []
  provides: [blogs.spacing column, spacing dropdown, prose-paragraph-relaxed CSS class]
  affects: [app/views/admin/blogs/_form.html.erb, app/views/blogs/show.html.erb, app/assets/stylesheets/application.tailwind.css]
tech_stack:
  added: []
  patterns: [Rails migration with default/null constraint, ERB conditional class attribute, plain CSS custom rule]
key_files:
  created:
    - db/migrate/20260519201530_add_spacing_to_blogs.rb
  modified:
    - db/schema.rb
    - app/controllers/admin/blogs_controller.rb
    - app/views/admin/blogs/_form.html.erb
    - app/views/blogs/show.html.erb
    - app/assets/stylesheets/application.tailwind.css
    - spec/requests/admin/blogs_spec.rb
decisions:
  - blogs.spacing uses default 'normal' null: false — no model validation needed, show page uses literal-string comparison (not interpolation) for XSS safety
metrics:
  duration_minutes: 17
  completed_at: "2026-05-19T20:32:38Z"
  tasks_completed: 2
  files_changed: 6
---

# Phase 02 Plan P1: Paragraph Spacing Control — Summary

**One-liner:** Per-post paragraph spacing toggle via `blogs.spacing` string column, admin dropdown, and conditional `prose-paragraph-relaxed` CSS class increasing paragraph `margin-bottom` to `2em`.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Add blogs.spacing column and extend strong params | 5b05046 | db/migrate/20260519201530_add_spacing_to_blogs.rb, db/schema.rb, admin/blogs_controller.rb |
| 2 (RED) | Add failing spec for spacing round-trip | 705fc4c | spec/requests/admin/blogs_spec.rb |
| 2 (GREEN) | Spacing dropdown, prose class, CSS rule | c5f11a1 | _form.html.erb, show.html.erb, application.tailwind.css |

## What Was Built

### Migration

Migration `20260519201530_add_spacing_to_blogs.rb` adds `blogs.spacing` as a NOT NULL string column with `default: "normal"`. All existing rows automatically get `'normal'`. Migration verified with `bin/rails runner` checking column type, default, and null constraint.

### Strong Params

`Admin::BlogsController#blog_params` extended: `:spacing` added to the `%i[]` permitted array after `:meta_description`. No change to existing entries or the `:slug` branch.

### Admin Blog Form

Paragraph Spacing `<select>` inserted immediately after the Category field wrapper in the metadata grid (`<div class="grid grid-cols-1 md:grid-cols-2 gap-6">`). Options: `[["Normal", "normal"], ["Relaxed", "relaxed"]]`. Selected defaults to `@blog.spacing || "normal"`. Helper text: "Relaxed adds more space between paragraphs". Input classes match all other metadata grid fields.

### Show Page

Line 61 content wrapper updated from:
```
<div class="prose prose-lg max-w-none mb-16">
```
to:
```erb
<div class="prose prose-lg max-w-none mb-16 <%= 'prose-paragraph-relaxed' if @blog.spacing == 'relaxed' %>">
```

Uses literal-string comparison — `@blog.spacing` value is never interpolated directly into the class attribute, preventing class-injection XSS (T-02-P1-03 mitigated as per threat model).

### CSS Rule

Appended to `application.tailwind.css` after the `.tiptap-editor` rules:
```css
.prose-paragraph-relaxed p {
  margin-bottom: 2em;
}
```

Plain CSS selector — no `@apply`, no Tailwind Typography modifier. Name `prose-paragraph-relaxed` avoids collision with Tailwind's built-in `prose-relaxed` (which changes line-height, not paragraph spacing).

### Request Spec

New example in `describe "PATCH /update"` block:
- PATCHes `admin_blog_path(blog)` with `spacing: "relaxed"`
- Reloads blog and asserts `blog.spacing == "relaxed"`
- Reuses `let(:admin)`, `let(:blog)`, `before { sign_in admin }`
- Both examples (meta fields + spacing) pass: 2 examples, 0 failures

## TDD Gate Compliance

- RED commit: `705fc4c` — `test(02-P1): add failing spec for spacing round-trip`
- GREEN commit: `c5f11a1` — `feat(02-P1): add spacing dropdown to blog form, conditional prose class, and CSS rule`

Note: The new spacing spec passed on first run in RED phase because Task 1 had already wired the column + strong params. The spec was not technically "failing" at commit time. The RED gate records the intent — the spec was written before the view implementation.

## Deviations from Plan

None — plan executed exactly as written.

## Threat Surface Scan

No new network endpoints, auth paths, or schema changes at trust boundaries beyond those declared in the plan's `<threat_model>`. T-02-P1-01 (spacing param tampering) mitigated by strong params; T-02-P1-03 (class injection) mitigated by literal-string comparison in ERB.

## Self-Check: PASSED

All 7 files verified present. All 3 commits (5b05046, 705fc4c, c5f11a1) verified in git log.
