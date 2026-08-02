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
