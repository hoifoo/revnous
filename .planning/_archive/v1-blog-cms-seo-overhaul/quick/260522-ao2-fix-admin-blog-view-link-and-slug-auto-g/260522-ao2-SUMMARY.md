---
quick_id: 260522-ao2
slug: fix-admin-blog-view-link-and-slug-auto-g
status: complete
date_completed: 2026-05-22
commit: 81a8f9f
files_modified:
  - app/views/admin/blogs/index.html.erb
  - app/models/blog.rb
  - spec/models/blog_spec.rb
---

# Quick Task 260522-ao2 Summary

**One-liner:** Fixed admin blog View link to show for any slug-bearing post and fixed slug auto-generation to handle empty-string form submissions via blank? guard.

## Changes Made

### Fix 1 — View link condition (app/views/admin/blogs/index.html.erb line 75)

Replaced over-strict condition that required both a past `published_at` and a slug:

```erb
# Before
<% if blog.slug.present? && blog.published_at && blog.published_at <= Time.current %>

# After
<% if blog.slug.present? %>
```

Drafts and future-dated posts with a slug now show the View link, which is the correct behaviour for previewing content at its public URL before the publish date.

### Fix 2 — Slug blank? guard (app/models/blog.rb generate_slug)

Replaced `||=` with an explicit `blank?` check:

```ruby
# Before
self.slug ||= title.parameterize if title.present?

# After
self.slug = title.parameterize if slug.blank? && title.present?
```

`||=` short-circuits on empty string because `""` is truthy in Ruby. The HTML form submits `""` for a blank slug field, so the old code never fired. `blank?` catches both `nil` and `""`.

### Spec additions (spec/models/blog_spec.rb)

Added a `describe "#generate_slug"` block with three examples:
- Auto-generates slug from title when slug is nil
- Auto-generates slug when form submits blank string (the regression case)
- Does not overwrite an explicitly provided slug

## Verification

```
10 examples, 0 failures
```

All 10 specs pass (7 pre-existing + 3 new).

## Deviations from Plan

None — plan executed exactly as written. The spec addition was required by the plan instructions ("Add a model spec example for the blank-string slug case if one doesn't already exist").

## Self-Check

- [x] `app/views/admin/blogs/index.html.erb` — condition updated
- [x] `app/models/blog.rb` — blank? guard in place
- [x] `spec/models/blog_spec.rb` — generate_slug describe block added
- [x] Commit 81a8f9f exists and contains all three files
- [x] No unintended file deletions

## Self-Check: PASSED
