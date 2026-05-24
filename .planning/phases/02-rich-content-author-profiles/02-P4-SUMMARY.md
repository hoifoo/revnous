---
phase: 02-rich-content-author-profiles
plan: P4
subsystem: admin-user-crud
tags: [rails-migration, admin-crud, active-storage, devise, author-profile]
one_liner: "Admin user CRUD with bio/job_title/linkedin_url/twitter_handle profile columns, has_one_attached :avatar, full_name/initials helpers, linkedin URL validation, and full request spec coverage"
completed_at: "2026-05-19T20:42:21Z"
duration_minutes: 15

dependency_graph:
  requires:
    - 02-P1 (users table, devise setup, Admin::BaseController)
  provides:
    - users.bio, users.job_title, users.linkedin_url, users.twitter_handle columns
    - User#full_name, User#initials, User#avatar attachment
    - Admin::UsersController with full CRUD
    - admin/users routes (index/new/create/edit/update/destroy)
  affects:
    - 02-P5 (author_id FK on blogs references these user profile attributes)
    - 02-P6 (author card on blog show page consumes full_name/initials/avatar/linkedin_url/twitter_handle)

tech_stack:
  added:
    - URI::DEFAULT_PARSER.make_regexp for linkedin_url format validation
    - has_one_attached :avatar via ActiveStorage (already installed)
    - kaminari pagination on Admin::UsersController#index
  patterns:
    - before_validation callback for twitter_handle normalization (strip leading @)
    - blank-password-preserve pattern in update action (T-02-P4-03)
    - Admin::BaseController inheritance for ensure_admin! gate

key_files:
  created:
    - db/migrate/20260519203520_add_author_profile_to_users.rb
    - app/controllers/admin/users_controller.rb
    - app/views/admin/users/index.html.erb
    - app/views/admin/users/new.html.erb
    - app/views/admin/users/edit.html.erb
    - app/views/admin/users/_form.html.erb
    - spec/requests/admin/users_spec.rb
  modified:
    - app/models/user.rb
    - db/schema.rb
    - spec/factories/users.rb
    - config/routes.rb

decisions:
  - "form.submit label uses ternary on @user.persisted? to render Save User vs Update User without separate partials"
  - "resources :users, except: [:show] mirrors existing admin resource pattern"
  - "user_params.except(:password, :password_confirmation) used in update when blank — preserves encrypted_password"

metrics:
  total_tasks: 2
  completed_tasks: 2
  files_created: 7
  files_modified: 4
---

# Phase 02 Plan P4: Admin User CRUD + Author Profile Data Model Summary

Admin user CRUD with bio/job_title/linkedin_url/twitter_handle profile columns, has_one_attached :avatar, full_name/initials helpers, linkedin URL validation, and full request spec coverage.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Add author-profile columns, has_one_attached :avatar, model methods, linkedin validation, twitter normalization, extend factory | e016bc9 | db/migrate/20260519203520_add_author_profile_to_users.rb, app/models/user.rb, spec/factories/users.rb |
| 2 | Mount admin/users routes, Admin::UsersController, index/new/edit/_form views, request specs | e0723e1 | config/routes.rb, app/controllers/admin/users_controller.rb, app/views/admin/users/*, spec/requests/admin/users_spec.rb |

## Migration

**Timestamp:** 20260519203520
**Migration:** `AddAuthorProfileToUsers`
**Columns added to `users`:**
- `bio` (text)
- `job_title` (string)
- `linkedin_url` (string)
- `twitter_handle` (string)

## Model Surface (app/models/user.rb)

- `has_one_attached :avatar` — ActiveStorage attachment for profile photo
- `full_name` — `[first_name, last_name].compact_blank.join(' ').presence || email` (fallback to email when both blank)
- `initials` — `[first_name&.first, last_name&.first].compact.join.upcase.presence || '?'` (verbatim from UI-SPEC §12)
- `validates :linkedin_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), allow_blank: true }` — rejects `javascript:`, `data:`, and other non-http(s) schemes (T-02-P4-01)
- `before_validation :normalize_twitter_handle` — strips leading `@` so bare handle is stored (e.g., `nakamura` not `@nakamura`)

## Routes Mounted

`resources :users, except: [ :show ]` added to admin namespace in `config/routes.rb`.

Named routes: `admin_users` (GET index / POST create), `new_admin_user` (GET), `edit_admin_user` (GET), `admin_user` (PATCH/PUT/DELETE).

## Controller Actions

`Admin::UsersController < Admin::BaseController` with:
- `index` — paginated `User.order(:first_name, :last_name).page(params[:page]).per(20)`
- `new` / `create` — `User.new(user_params)` with redirect on success, `:unprocessable_entity` on failure
- `edit` / `update` — blank-password strip: `user_params.except(:password, :password_confirmation)` when `params[:user][:password].blank?` (T-02-P4-03)
- `destroy` — `@user.destroy` + redirect with notice

`user_params` permits: `:first_name, :last_name, :email, :password, :password_confirmation, :bio, :job_title, :linkedin_url, :twitter_handle, :avatar, :admin`

## Views Created

- `index.html.erb` — table with Avatar/Name (initials placeholder when no avatar), Email, Job Title, Role badge (Admin/Member), Edit/Delete actions; empty state row with CTA link
- `new.html.erb` — heading "New User" + subtitle + form partial
- `edit.html.erb` — heading "Edit User" + subtitle + form partial
- `_form.html.erb` — First/Last Name (2-col grid), Email, Password (with "Leave blank to keep current" on edit), Password Confirmation, Author Profile section divider, Job Title, Bio (textarea), LinkedIn URL, Twitter Handle, Avatar file upload with preview, Admin checkbox, Cancel + Save User / Update User submit

## Factory Traits

`spec/factories/users.rb` extended with: `sequence(:first_name)`, `sequence(:last_name)`, `job_title`, `bio`, `linkedin_url` (nil default), `twitter_handle` (nil default). Existing `:admin` trait preserved.

## Request Spec Coverage (9 examples, all passing)

| Scenario | Result |
|----------|--------|
| GET /admin/users renders index | PASS |
| GET /admin/users/new renders form | PASS |
| POST /admin/users creates user with profile fields | PASS |
| POST with invalid linkedin_url returns 422 | PASS |
| PATCH /admin/users/:id updates profile fields | PASS |
| PATCH with blank password preserves existing password | PASS |
| DELETE /admin/users/:id removes user | PASS |
| Non-admin GET redirects to root with "Access denied" | PASS |
| Non-admin DELETE does not change User count | PASS |

## Security Mitigations Applied

| Threat ID | Disposition | Implementation |
|-----------|-------------|----------------|
| T-02-P4-01 (XSS via linkedin_url) | Mitigated | `validates :linkedin_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), allow_blank: true }` rejects `javascript:alert(1)` — spec confirms 422 + no record created |
| T-02-P4-02 (non-admin to /admin/users) | Mitigated | `ensure_admin!` in Admin::BaseController; spec confirms redirect + "Access denied" |
| T-02-P4-03 (blank password reset bypass) | Mitigated | `user_params.except(:password, :password_confirmation)` when blank — spec confirms `valid_password?("password123")` still passes |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed ERB syntax error in _form.html.erb form.submit call**
- **Found during:** Task 2 execution (rspec run)
- **Issue:** `<%= form.submit(...), class: "..." %>` — parentheses around the first argument caused a Ruby parse error in ERB. The `, class:` was outside the method call.
- **Fix:** Changed to `<%= form.submit @user.persisted? ? "Update User" : "Save User", class: "..." %>` (no parentheses)
- **Files modified:** app/views/admin/users/_form.html.erb
- **Commit:** e0723e1

## Known Stubs

None — all fields are wired to the database. Avatar display uses ActiveStorage attachment, no placeholder data.

## Threat Flags

None — all new routes are within the admin namespace which requires `ensure_admin!`. No new public endpoints created.

## Self-Check: PASSED

- [x] `db/migrate/20260519203520_add_author_profile_to_users.rb` exists
- [x] `app/models/user.rb` contains `has_one_attached :avatar`, `full_name`, `initials`, linkedin validation, twitter normalization
- [x] `config/routes.rb` contains `resources :users`
- [x] `app/controllers/admin/users_controller.rb` exists and inherits from `Admin::BaseController`
- [x] All 4 views exist in `app/views/admin/users/`
- [x] `spec/factories/users.rb` extended with profile attributes
- [x] `spec/requests/admin/users_spec.rb` exists with 9 examples, all passing
- [x] Commit e016bc9 exists (Task 1)
- [x] Commit e0723e1 exists (Task 2)
