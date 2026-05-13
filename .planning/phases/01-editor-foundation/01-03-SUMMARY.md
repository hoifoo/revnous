---
phase: 01-editor-foundation
plan: "03"
subsystem: rake-migration
tags: [rake, migration, actiontext, nokogiri, blogs]
dependency_graph:
  requires: [01-01]
  provides: [blogs:migrate_body task, EDIT-06]
  affects: [blogs.body column, action_text_rich_texts table]
tech_stack:
  added: []
  patterns: [Rake namespace/task pattern, Nokogiri HTML fragment stripping, ActiveRecord find_each batching, update_column callback bypass]
key_files:
  created:
    - lib/tasks/blogs.rake
  modified: []
decisions:
  - "Use read_attribute(:body) not rich_text.body.to_s to avoid ActionText render pipeline during migration"
  - "Use update_column(:body) not blog.save to bypass before_save :sanitize_body callback (source HTML is trusted ActionText output)"
  - "No transaction wrapping: per-record update_column is atomic; re-runnability is the safety mechanism (D-01)"
  - "ActionText rows left untouched: rollback path preserved (D-03)"
metrics:
  duration: "~10 minutes"
  completed: "2026-05-13"
  tasks_completed: 1
  files_created: 1
  files_modified: 0
requirements: [EDIT-06]
---

# Phase 01 Plan 03: Rake Migration Task Summary

**One-liner:** Idempotent `blogs:migrate_body` Rake task reads ActionText rich text rows, strips `<action-text-attachment>` nodes via Nokogiri, and backfills `blogs.body` with cleaned HTML.

## What Was Built

`lib/tasks/blogs.rake` defines a single Rake task `blogs:migrate_body` that:

1. Iterates all Blog records using `Blog.find_each` (memory-safe 1000-record batches)
2. Skips records where `blog.body.present?` (idempotent — already migrated rows are no-ops)
3. Skips records where no matching `ActionText::RichText` row exists (blogs created post-migration)
4. Reads raw Trix HTML via `rich_text.read_attribute(:body)` — bypasses the `ActionText::Content` object and the Rails view layer
5. Strips `<action-text-attachment>` nodes via Nokogiri CSS selector while preserving surrounding inline text
6. Writes cleaned HTML via `blog.update_column(:body, clean_html)` — bypasses `before_save :sanitize_body` callback intentionally (source is trusted admin-authored Trix HTML)
7. Prints per-record progress (`Migrated N/Total posts` or `Skipping post X — ...`) and a final tally

## Task Structure

```ruby
namespace :blogs do
  desc "Migrate blog content from ActionText to blogs.body column"
  task migrate_body: :environment do
    ...
  end
end
```

The `:environment` symbol ensures the full Rails app is loaded (models, database connection, ActionText constants).

## Verification (Automated — Task 1)

All acceptance criteria verified:

| Check | Result |
|-------|--------|
| `lib/tasks/blogs.rake` exists | PASS |
| `namespace :blogs do` present | PASS |
| `task migrate_body: :environment` present | PASS |
| `desc "Migrate blog content from ActionText..."` present | PASS |
| `Blog.find_each` used (not `Blog.all.each`) | PASS |
| `ActionText::RichText.find_by(record_type: "Blog", ...)` present | PASS |
| `read_attribute(:body)` used (not `.body` accessor) | PASS |
| `Nokogiri::HTML.fragment(...)` + `.css("action-text-attachment").each(&:remove)` present | PASS |
| `blog.update_column(:body, clean_html)` used | PASS |
| Idempotent skip guard `if blog.body.present?` present | PASS |
| Progress output `puts "Migrated #{migrated}/#{total} posts"` present | PASS |
| Final output `puts "Done. #{migrated} posts migrated, #{skipped} skipped."` present | PASS |
| `bundle exec rake -T blogs` lists `blogs:migrate_body` | PASS |

## Commits

| Task | Commit | Files |
|------|--------|-------|
| Task 1: Create lib/tasks/blogs.rake | b35907d | lib/tasks/blogs.rake (new, 42 lines) |

## Deviations from Plan

None — plan executed exactly as written.

## Rollback Path Confirmation

`action_text_rich_texts` rows for `record_type='Blog'` are NOT deleted or modified. The task is read-only with respect to ActionText. If rollback is needed:
```ruby
Blog.update_all(body: nil)
```
Then revert the Plan 01 code changes to restore ActionText rendering.

## Known Stubs

None — this is a data transformation utility with no UI or rendering stubs.

## Threat Flags

No new security surface introduced. The rake task runs in a trusted CLI context (operator-controlled deployment shell). `action_text_rich_texts.body` → `blogs.body` is a trusted-source data copy; T-01-11 through T-01-14 are addressed in the plan's threat model.

## Self-Check: PASSED

- [x] `lib/tasks/blogs.rake` exists: FOUND
- [x] Commit b35907d exists in git log
