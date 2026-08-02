# Deferred Items — Phase 01

Items discovered during execution that are out of scope for the current plan/task and were not fixed.

## Plan 01-01

### Pre-existing: Tailwind/Propshaft CSS asset not built in this worktree

- **Found during:** Task 2 verification (`bundle exec rspec spec/models spec/requests`)
- **Symptom:** 24 unrelated request-spec failures with `Propshaft::MissingAssetError: The asset 'application.css' was not found in the load path.`
- **Affected files (not touched by this plan):** `spec/requests/admin/resource_deletion_spec.rb`, `spec/requests/admin/seo_metadata_spec.rb`, `spec/requests/admin/users_spec.rb`, `spec/requests/blogs_spec.rb`
- **Root cause:** `app/assets/builds/*` is gitignored (only `.keep` is tracked); this worktree has not run `yarn build:css` / the Tailwind CLI build, so any view rendering `stylesheet_link_tag "application"` fails in request specs.
- **Why deferred:** Out of scope — none of Plan 01-01's task files (`db/migrate/*_add_toc_fields_to_blogs.rb`, `db/schema.rb`, `app/controllers/admin/blogs_controller.rb`, `spec/models/blog_spec.rb`) touch the asset pipeline, views, or CSS. `spec/models/blog_spec.rb` (the only spec file this plan modified) passes 39/39. Per SCOPE BOUNDARY rule, pre-existing failures in unrelated files are not auto-fixed.
- **Suggested resolution:** Run the CSS build step (`yarn build:css` or `npm run build:css`, per `package.json`) before running the full request-spec suite in this worktree, or ensure CI/dev setup runs it automatically before `bin/rails test`/`rspec`.

## Plan 01-04

### Pre-existing: Rubocop offenses in generated DB schema files

- **Found during:** Task 3 full-suite Rubocop gate (`bundle exec rubocop`)
- **Symptom:** 160 `Layout/SpaceInsideArrayLiteralBrackets` (and related) offenses across `db/schema.rb`, `db/cache_schema.rb`, `db/queue_schema.rb`, `db/cable_schema.rb`.
- **Affected files (not touched by this plan):** the four generated schema files above.
- **Root cause:** These are Rails-generated schema dump files (auto-formatted array literals like `["blogs_products"]` without inner spacing); Rubocop's Omakase config flags the array-bracket spacing style. Last modified by plan 01-01 (schema migration commit `92983bb`), not this plan.
- **Why deferred:** Out of scope per SCOPE BOUNDARY rule — this plan touches only `app/helpers/blogs_helper.rb`, `app/views/blogs/show.html.erb`, and `spec/requests/blogs_toc_spec.rb`, all of which are Rubocop-clean (0 offenses). `git status` confirms the schema files have no working-tree changes from this plan.
- **Suggested resolution:** Either add `db/*_schema.rb` to `.rubocop.yml`'s `AllCops: Exclude` (standard Rails convention — generated files are not usually linted) or run `rubocop -A` on them in a dedicated cleanup task, as a project-wide convention decision outside this phase's scope.
