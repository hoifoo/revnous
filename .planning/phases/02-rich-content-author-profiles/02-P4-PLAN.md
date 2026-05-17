---
phase: 02-rich-content-author-profiles
plan: P4
type: execute
wave: 1
depends_on: []
files_modified:
  - db/migrate/YYYYMMDDHHMMSS_add_author_profile_to_users.rb
  - db/schema.rb
  - app/models/user.rb
  - config/routes.rb
  - app/controllers/admin/users_controller.rb
  - app/views/admin/users/index.html.erb
  - app/views/admin/users/new.html.erb
  - app/views/admin/users/edit.html.erb
  - app/views/admin/users/_form.html.erb
  - spec/factories/users.rb
  - spec/requests/admin/users_spec.rb
autonomous: true
requirements: [AUTH-02]
tags: [rails-migration, admin-crud, active-storage, devise, author-profile]

must_haves:
  truths:
    - "Visiting /admin/users as an admin shows the users index table with avatar/name, email, job title, role, and Edit/Delete actions [D-12]"
    - "Visiting /admin/users/new shows the user form with Name (first/last), Email, Password + Confirmation, Job Title, Bio, LinkedIn URL, Twitter Handle, Avatar upload, and Admin checkbox fields [D-12, D-13, D-14]"
    - "POST /admin/users with valid params creates a User record with bio/job_title/linkedin_url/twitter_handle persisted and avatar (if attached) stored in ActiveStorage [D-12, D-13]"
    - "PATCH /admin/users/:id updates the same profile fields; if Password is left blank, the existing password is preserved [D-12, D-14]"
    - "DELETE /admin/users/:id removes the User (no FK constraint failure — author_id nullification handled in Plan P5; for P4 we accept that blogs do not yet reference users) [D-12, D-16]"
    - "User#initials returns the first letters of first_name and last_name uppercased (or '?' when both are missing) [D-13]"
    - "User#full_name returns 'first last' (existing or new method — must exist after P4) [D-13]"
    - "linkedin_url must validate http(s) format and reject `javascript:` schemes; invalid URL shows form error and does NOT persist [D-13]"
    - "Non-admin users hitting /admin/users are redirected to root_path with 'Access denied' flash"
    - "Request spec covers admin create + update + destroy and a non-admin redirect [D-12, D-14, D-15]"
  artifacts:
    - path: "db/migrate/*_add_author_profile_to_users.rb"
      provides: "Migration adding bio (text), job_title (string), linkedin_url (string), twitter_handle (string) to users"
      contains: "add_column :users, :bio, :text"
    - path: "app/models/user.rb"
      provides: "User model with has_one_attached :avatar, full_name, initials, linkedin URL format validation, twitter_handle normalization"
      contains: "has_one_attached :avatar"
    - path: "config/routes.rb"
      provides: "admin namespace gains resources :users"
      contains: "resources :users"
    - path: "app/controllers/admin/users_controller.rb"
      provides: "Full CRUD controller inheriting from Admin::BaseController with user_params permit list"
      contains: "class Admin::UsersController < Admin::BaseController"
    - path: "app/views/admin/users/index.html.erb"
      provides: "Users index table matching admin/blogs/index.html.erb pattern (header, avatar/name, email, job title, role, actions)"
      contains: "Users"
    - path: "app/views/admin/users/_form.html.erb"
      provides: "User form with name/email/password/profile section/avatar/admin toggle"
      contains: "form.file_field :avatar"
    - path: "spec/requests/admin/users_spec.rb"
      provides: "Request specs for create/update/destroy + non-admin redirect"
      contains: "RSpec.describe \"Admin::Users\""
    - path: "spec/factories/users.rb"
      provides: "Factory extended with first_name/last_name/job_title/bio/linkedin_url/twitter_handle traits"
      contains: "first_name"
  key_links:
    - from: "config/routes.rb (admin namespace)"
      to: "app/controllers/admin/users_controller.rb"
      via: "resources :users routes to Admin::UsersController#index,new,create,edit,update,destroy"
      pattern: "resources :users"
    - from: "app/controllers/admin/users_controller.rb"
      to: "app/models/user.rb"
      via: "user_params permit list (first_name, last_name, email, password, password_confirmation, bio, job_title, linkedin_url, twitter_handle, avatar, admin)"
      pattern: "user_params"
    - from: "app/views/admin/users/_form.html.erb"
      to: "User attributes"
      via: "form.text_field/text_area/url_field/file_field/check_box on every profile attribute"
      pattern: "form\\.(text_field|text_area|url_field|file_field|check_box)"
    - from: "app/views/admin/users/index.html.erb"
      to: "User#full_name + User#initials + user.avatar"
      via: "image_tag user.avatar if attached else initials placeholder div"
      pattern: "user\\.avatar"
    - from: "app/models/user.rb"
      to: "linkedin_url format validation"
      via: "validates :linkedin_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), allow_blank: true }"
      pattern: "URI::DEFAULT_PARSER\\.make_regexp"
---

<objective>
## Phase Goal

**As an** admin, **I want to** create and manage admin users (including their author profile fields and avatar), **so that** future blog posts can be assigned to specific users and the published page can show a real author card.

This is the **fourth vertical slice** of Phase 2 — the User-side of the author story. It runs in **Wave 1 in parallel with P1** because it does not touch any blog files. By the end of this plan, admin user CRUD is fully end-to-end and the User model carries the author-profile attributes. Plan P5 will then wire `blogs.author_id` to these users.

**Purpose:** Build admin user CRUD + author profile data model (AUTH-02).
**Output:** Migration adding `bio/job_title/linkedin_url/twitter_handle` to `users`; `has_one_attached :avatar`; `full_name` + `initials` helpers; `linkedin_url` URL format validation; admin namespace `resources :users`; `Admin::UsersController` with `index/new/create/edit/update/destroy`; `index/new/edit/_form` views matching the admin/blogs visual pattern; factory extended; request spec covering create/update/destroy + non-admin redirect.
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
@CLAUDE.md

@app/models/user.rb
@app/controllers/admin/base_controller.rb
@app/controllers/admin/blogs_controller.rb
@app/views/admin/blogs/index.html.erb
@app/views/admin/blogs/new.html.erb
@app/views/admin/blogs/edit.html.erb
@app/views/admin/blogs/_form.html.erb
@config/routes.rb
@spec/factories/users.rb
@spec/requests/admin/blogs_spec.rb
@spec/requests/admin/resource_deletion_spec.rb

<interfaces>
<!-- Existing User model (post-Phase 1): -->
<!--   devise :database_authenticatable, :registerable, :recoverable, :rememberable, :validatable -->
<!--   columns include: email, encrypted_password, first_name, last_name, admin (boolean default false) -->

<!-- Existing Admin::BaseController gates: -->
<!--   before_action :authenticate_user! -->
<!--   before_action :ensure_admin! -->
<!--   layout "admin" -->
<!--   redirect non-admin to root_path with flash[:alert] "Access denied. Admin privileges required." -->

<!-- Existing admin index pattern (admin/blogs/index.html.erb): -->
<!--   <h1 class="text-3xl font-bold text-gray-900"> + subtitle <p class="text-gray-600 mt-2"> -->
<!--   <table class="min-w-full divide-y divide-gray-200"> with <thead class="bg-gray-50"> -->
<!--   per-row hover: bg-gray-50; Edit (text-indigo-600) and Delete (text-red-600) actions -->

<!-- Existing _form.html.erb pattern: -->
<!--   form_with(model: [:admin, @blog], class: "space-y-6") do |form| -->
<!--   error block with red-50 bg + list-disc -->
<!--   labels: block text-sm font-medium text-gray-700 mb-2 -->
<!--   inputs: w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-pink-500 focus:border-transparent -->
<!--   submit footer: flex items-center justify-end space-x-4 pt-6 border-t border-gray-200; Cancel link + bg-pink-600 submit -->

<!-- Existing Devise patterns: password update with blank-to-keep-current — Devise built-in: -->
<!--   if params[:user][:password].blank? then user.update(user_params.except(:password, :password_confirmation)) -->
<!--   else user.update(user_params) -->

<!-- Existing factory pattern (users.rb): -->
<!--   FactoryBot.define do; factory :user do; ...; trait :admin do; admin { true }; end; end; end -->
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add author-profile columns to users, has_one_attached :avatar, full_name + initials methods, linkedin_url format validation, twitter_handle normalization, and extend the user factory</name>
  <files>db/migrate/YYYYMMDDHHMMSS_add_author_profile_to_users.rb, db/schema.rb, app/models/user.rb, spec/factories/users.rb</files>
  <read_first>
    - db/migrate/20260513121220_add_body_to_blogs.rb (Rails 8.0 migration class style — copy)
    - db/schema.rb (users table, lines 454–479 — confirm none of `bio`, `job_title`, `linkedin_url`, `twitter_handle` exist)
    - app/models/user.rb (current contents — only devise modules; extend in place)
    - .planning/phases/02-rich-content-author-profiles/02-CONTEXT.md (D-13 column list + has_one_attached, D-15 admin column already present, Specifics: Twitter `sameAs` uses normalized handle without `@`)
    - .planning/phases/02-rich-content-author-profiles/02-UI-SPEC.md (§12 Avatar Initials Placeholder — `[first_name&.first, last_name&.first].compact.join.upcase.presence || '?'`; Security Contract — LinkedIn URL format validation rule)
    - spec/factories/users.rb (existing factory — extend traits, do not break the existing `:admin` trait)
  </read_first>
  <action>
**Migration:**

Generate `bin/rails generate migration AddAuthorProfileToUsers bio:text job_title:string linkedin_url:string twitter_handle:string`. The generated file should already produce the correct `add_column` calls — verify the class inherits `ActiveRecord::Migration[8.0]`. Run `bin/rails db:migrate` so `db/schema.rb` regenerates with the four new columns on the `users` table.

**User model (`app/models/user.rb`):**

1. Below the existing `devise` line, add:
   - `has_one_attached :avatar`

2. Add validations (these can sit below `devise` and the attachment):
   - `validates :linkedin_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), allow_blank: true, message: "must be a valid http or https URL" }`

3. Add a `before_validation` callback `:normalize_twitter_handle` that, if `twitter_handle.present?`, strips a leading `@` so the stored value is the bare handle (e.g. `nakamura` not `@nakamura`).

4. Add public instance methods:
   - `full_name` → `[first_name, last_name].compact_blank.join(' ').presence || email`. If both first and last are blank, fall back to `email` (so the index table always renders a non-empty label).
   - `initials` → `[first_name&.first, last_name&.first].compact.join.upcase.presence || '?'` (verbatim from UI-SPEC §12).

5. Private method `normalize_twitter_handle`: `self.twitter_handle = twitter_handle.to_s.strip.delete_prefix('@').presence` (the `presence` ensures empty values become `nil` not `""`).

Do NOT change the `devise` module list or remove existing columns.

**Factory (`spec/factories/users.rb`):**

6. Extend the existing `factory :user` block with the new author-profile attributes — leave the `:admin` trait intact:
   - `sequence(:first_name) { |n| "First#{n}" }`
   - `sequence(:last_name) { |n| "Last#{n}" }`
   - `job_title { "Content Marketing Manager" }`
   - `bio { "A short bio for testing." }`
   - `linkedin_url { nil }` (default nil so URL validation does not fail unexpectedly)
   - `twitter_handle { nil }`

Keep `password`, `password_confirmation`, `admin`, and `email` exactly as they are.
  </action>
  <verify>
    <automated>bin/rails runner "%w[bio job_title linkedin_url twitter_handle].each { |c| raise \"missing column: #{c}\" unless User.column_names.include?(c) }"</automated>
    <automated>bin/rails runner "u = User.new(first_name: 'Ada', last_name: 'Lovelace'); raise 'full_name wrong' unless u.full_name == 'Ada Lovelace'; raise 'initials wrong' unless u.initials == 'AL'"</automated>
    <automated>bin/rails runner "u = User.new; raise 'initials fallback wrong' unless u.initials == '?'"</automated>
    <automated>bin/rails runner "u = User.new(email: 'x@y.com', password: 'password123', password_confirmation: 'password123', linkedin_url: 'javascript:alert(1)'); raise 'should be invalid' if u.valid?; raise 'wrong field' unless u.errors[:linkedin_url].any?"</automated>
    <automated>bin/rails runner "u = User.new(twitter_handle: '@nakamura'); u.valid?; raise \"normalize failed: #{u.twitter_handle.inspect}\" unless u.twitter_handle == 'nakamura'"</automated>
    <automated>bundle exec rspec spec/factories</automated>
  </verify>
  <acceptance_criteria>
    - `users` table has columns `bio` (text), `job_title` (string), `linkedin_url` (string), `twitter_handle` (string)
    - `db/schema.rb` `create_table "users"` block contains `t.text "bio"`, `t.string "job_title"`, `t.string "linkedin_url"`, `t.string "twitter_handle"`
    - `User.new.respond_to?(:avatar)` is true (ActiveStorage attachment defined)
    - `User.new(first_name: 'Ada', last_name: 'Lovelace').full_name == 'Ada Lovelace'`
    - `User.new.full_name == User.new.email` (fallback when both name fields blank — non-error)
    - `User.new(first_name: 'Ada', last_name: 'Lovelace').initials == 'AL'`
    - `User.new.initials == '?'`
    - LinkedIn URL `javascript:alert(1)` fails validation (`u.valid? == false`, `u.errors[:linkedin_url].any?`)
    - Twitter handle stored with leading `@` is normalized to bare handle
    - `spec/factories/users.rb` contains `first_name`, `last_name`, `job_title`, `bio` attribute declarations
    - FactoryBot lint passes (or `bundle exec rspec spec/factories` exits 0 if there is a factory spec)
  </acceptance_criteria>
  <done>Users table has the new profile columns, model exposes `full_name`/`initials`/`avatar` and validates `linkedin_url`, twitter handle is normalized, and the factory is extended.</done>
</task>

<task type="auto">
  <name>Task 2: Mount admin/users routes, create Admin::UsersController, build index/new/edit/_form views, and write request specs covering CRUD + non-admin redirect</name>
  <files>config/routes.rb, app/controllers/admin/users_controller.rb, app/views/admin/users/index.html.erb, app/views/admin/users/new.html.erb, app/views/admin/users/edit.html.erb, app/views/admin/users/_form.html.erb, spec/requests/admin/users_spec.rb</files>
  <read_first>
    - config/routes.rb (admin namespace block lines 4–19 — add `resources :users` alongside the existing entries)
    - app/controllers/admin/blogs_controller.rb (FULL file — copy the controller shape: `before_action :set_blog`, the seven action methods, the private `set_*`/`*_params` pair; substitute User for Blog)
    - app/views/admin/blogs/index.html.erb (full file — copy header structure, table classes, action buttons; substitute user fields)
    - app/views/admin/blogs/new.html.erb (4-line wrapper — copy)
    - app/views/admin/blogs/edit.html.erb (4-line wrapper — copy)
    - app/views/admin/blogs/_form.html.erb (form shape — error block, label classes, input classes, submit footer — copy)
    - .planning/phases/02-rich-content-author-profiles/02-UI-SPEC.md (§9 Admin Users Index — exact heading "Users" + subtitle "Manage admin users and author profiles", per-cell classes, empty state markup; §10 Admin User Form — field layout order, placeholders, helper text, admin role checkbox; Copywriting table — all flash + button strings)
    - .planning/phases/02-rich-content-author-profiles/02-CONTEXT.md (D-14 password set directly in form, D-12 full CRUD)
    - spec/requests/admin/blogs_spec.rb (admin sign-in pattern)
    - spec/requests/admin/resource_deletion_spec.rb (full file — copy the non-admin redirect test structure)
  </read_first>
  <action>
**Routes (`config/routes.rb`):**

1. Inside the `namespace :admin do … end` block, add a new line `resources :users` (placement: just below `resources :seo_metadata, except: [ :show ]` is fine — alphabetical placement is not required for this Rails project). The full CRUD route set is needed: index, new, create, edit, update, destroy. The `:show` action is not required (D-12 lists index/show/new/create/edit/update/destroy — but show is not in UI-SPEC, so we use the default 7-action set; `index`, `new`, `create`, `edit`, `update`, `destroy` is what we actually need, but adding `:show` does no harm because Rails resources include all 7 by default).

   For cleanliness mirroring `resources :blogs, except: [ :show ]`, write: `resources :users, except: [ :show ]`. This is the form to use.

**Controller (`app/controllers/admin/users_controller.rb`) — new file:**

2. Define `class Admin::UsersController < Admin::BaseController`. Mirror `Admin::BlogsController` exactly:

   - `before_action :set_user, only: [:edit, :update, :destroy]`
   - `index` → `@users = User.order(:first_name, :last_name).page(params[:page]).per(20)` (uses kaminari — already in the project)
   - `new` → `@user = User.new`
   - `create` →
     - `@user = User.new(user_params)`
     - `if @user.save then redirect_to admin_users_path, notice: "User was successfully created." else render :new, status: :unprocessable_entity`
   - `edit` → (empty body — `@user` set by before_action)
   - `update` →
     - When `params[:user][:password].blank?`, strip `:password` and `:password_confirmation` from the params hash before calling `@user.update(...)` so the existing password is preserved (D-14 semantics: "Leave blank to keep current")
     - On success redirect to `admin_users_path` with notice `"User profile was successfully updated."`
     - On failure render `:edit, status: :unprocessable_entity`
   - `destroy` → `@user.destroy; redirect_to admin_users_path, notice: "User was successfully deleted."`

   Private:
   - `set_user` → `@user = User.find(params[:id])`
   - `user_params` → permit `:first_name, :last_name, :email, :password, :password_confirmation, :bio, :job_title, :linkedin_url, :twitter_handle, :avatar, :admin`

**Index view (`app/views/admin/users/index.html.erb`) — new file:**

3. Use the UI-SPEC §9 layout. Header: `Users` (h1 `text-3xl font-bold text-gray-900`) + subtitle `Manage admin users and author profiles` (`text-gray-600 mt-2`) + "New User" button (`new_admin_user_path`, classes `px-6 py-3 bg-pink-600 text-white rounded-md hover:bg-pink-700 transition font-medium inline-flex items-center`). Table head cells (each `px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider`): `Avatar / Name`, `Email`, `Job Title`, `Role`, `Actions`.

   Per-row (loop `@users.each do |user|`): hover class `hover:bg-gray-50`.
   - Avatar/Name cell: if `user.avatar.attached?` then `image_tag user.avatar, class: "h-10 w-10 rounded-full object-cover", alt: user.full_name`. Else a `<div class="h-10 w-10 rounded-full bg-gray-200 flex items-center justify-center" aria-label="<%= user.full_name %>"><span class="text-sm font-semibold text-gray-500" aria-hidden="true"><%= user.initials %></span></div>`. Beside the avatar render `user.full_name` (text-gray-900 font-medium).
   - Email cell: `user.email` (text-gray-600 text-sm).
   - Job Title cell: `user.job_title.presence || "—"`.
   - Role cell: if `user.admin?` render an `<span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-purple-100 text-purple-800">Admin</span>` else `<span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-gray-100 text-gray-700">Member</span>`.
   - Actions cell: `link_to "Edit", edit_admin_user_path(user), class: "text-indigo-600 hover:text-indigo-900"` and `link_to "Delete", admin_user_path(user), data: { turbo_method: :delete, turbo_confirm: "Delete this user? Their blog posts will be unassigned but not deleted." }, class: "text-red-600 hover:text-red-900 ml-3"`.

   Empty state (when `@users.none?`): full-width row matching UI-SPEC §9 — `<tr><td colspan="5" class="px-6 py-12 text-center text-gray-500">No admin users yet. <%= link_to "Add the first user", new_admin_user_path, class: "text-pink-600 hover:underline" %>.</td></tr>`.

**New + Edit views (`app/views/admin/users/new.html.erb`, `app/views/admin/users/edit.html.erb`) — new files:**

4. Mirror the four-line blogs new/edit wrappers exactly:
   - `new.html.erb`: heading "New User" + subtitle "Create a new admin user" + `<%= render "form", user: @user %>` inside a `bg-white rounded-lg shadow p-8` card.
   - `edit.html.erb`: heading "Edit User" + subtitle "Update admin user details" + same form render.

**Form partial (`app/views/admin/users/_form.html.erb`) — new file:**

5. Build the form to UI-SPEC §10 specification. Structure:

   - `form_with(model: [:admin, @user], class: "space-y-6") do |form|`
   - Error block at top (red-50 + list-disc) mirroring `admin/blogs/_form.html.erb` lines 2–13 — same class string, just substitute `@user` and "this user from being saved".
   - 2-col grid `<div class="grid grid-cols-1 md:grid-cols-2 gap-6">`:
     - First Name: `form.label :first_name` + `form.text_field :first_name` (standard input classes)
     - Last Name: `form.label :last_name` + `form.text_field :last_name`
     - Email: `form.label :email` + `form.email_field :email, autocomplete: "email"`
     - Password: `form.label :password` + `form.password_field :password, autocomplete: "new-password"` + helper "Leave blank to keep current" (only when editing — use `<% if @user.persisted? %>`)
     - Password Confirmation: `form.label :password_confirmation` + `form.password_field :password_confirmation, autocomplete: "new-password"`
   - Section divider: `<div class="border-t border-gray-200 pt-6 col-span-2"><h2 class="text-base font-semibold text-gray-900 mb-4">Author Profile</h2></div>` placed across both columns (or close the prior grid and open a new one — both acceptable).
   - Job Title: `form.text_field :job_title, placeholder: "e.g. Content Marketing Manager"`
   - Bio: `form.text_area :bio, rows: 4, placeholder: "A short bio that appears on published posts..."`
   - LinkedIn URL: `form.url_field :linkedin_url, placeholder: "https://linkedin.com/in/..."`
   - Twitter Handle: `form.text_field :twitter_handle, placeholder: "@handle (without the @)"`
   - Avatar: `form.label :avatar` + `form.file_field :avatar, accept: "image/*", aria: { label: "Upload avatar image" }`. If `@user.persisted? && @user.avatar.attached?`, show `image_tag @user.avatar, class: "w-20 h-20 rounded-full object-cover mt-2"`. Helper "Shown on published blog posts. Square image recommended."
   - Admin checkbox: `form.check_box :admin, class: "h-5 w-5 text-pink-600 focus:ring-pink-500 border-gray-300 rounded"` + `<span class="ml-2 text-sm text-gray-600">This user has admin access</span>`.
   - Submit footer: identical class string to blog form — Cancel link to `admin_users_path` + submit button `bg-pink-600 text-white px-6 py-2 rounded-md hover:bg-pink-700`. Submit label: "Save User" for new, "Update User" for edit (Rails default `form.submit` handles this if we explicitly pass the label — pass `form.submit (@user.persisted? ? "Update User" : "Save User")`).

   Every text/email/password/url input uses the shared class string `w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-pink-500 focus:border-transparent`. Every label uses `block text-sm font-medium text-gray-700 mb-2`. Every helper `<p>` uses `text-sm text-gray-500 mt-1`.

**Request spec (`spec/requests/admin/users_spec.rb`) — new file:**

6. Cover the contract end-to-end:
   - `require 'rails_helper'`
   - `RSpec.describe "Admin::Users", type: :request do`
   - `let(:admin) { create(:user, :admin) }`
   - `let(:member) { create(:user) }`
   - Group `context "as an admin"` with `before { sign_in admin }`:
     - "GET /admin/users renders the index" → `get admin_users_path; expect(response).to have_http_status(:ok); expect(response.body).to include("Users")`
     - "GET /admin/users/new renders the form" → `get new_admin_user_path; expect(response).to have_http_status(:ok); expect(response.body).to include("New User")`
     - "POST /admin/users creates a user with profile" → expect `User.count` to change by 1 when posting `{ user: { first_name: "Ada", last_name: "Lovelace", email: "ada@ex.com", password: "password123", password_confirmation: "password123", job_title: "Engineer", bio: "Bio.", linkedin_url: "https://linkedin.com/in/ada", twitter_handle: "@ada", admin: "1" } }`; then `User.last.bio == "Bio."`, `User.last.twitter_handle == "ada"`, `User.last.admin == true`, redirect to `admin_users_path`
     - "PATCH /admin/users/:id updates profile" → existing user gets `bio` updated; password blank in params → existing password preserved (assert `User.find(member.id).valid_password?("password123")`); `bio` and `job_title` reflect submitted values; redirect to `admin_users_path`
     - "DELETE /admin/users/:id removes the user" → `expect { delete admin_user_path(member) }.to change(User, :count).by(-1)`; redirect to `admin_users_path`; flash includes "deleted"
     - "POST with invalid linkedin_url re-renders new with 422" → submit `linkedin_url: "javascript:alert(1)"` plus other valid fields → response `:unprocessable_entity`, no record created
   - Group `context "as a non-admin"` with `before { sign_in member }`:
     - "GET /admin/users redirects to root with access denied" → `get admin_users_path; expect(response).to redirect_to(root_path); follow_redirect!; expect(response.body).to include("Access denied")`
     - "DELETE /admin/users/:id does not destroy the user" → expect no count change

   Use the existing Devise sign-in helper (`spec/support/devise.rb` already includes `Devise::Test::IntegrationHelpers, type: :request`).
  </action>
  <verify>
    <automated>grep -q 'resources :users' config/routes.rb</automated>
    <automated>test -f app/controllers/admin/users_controller.rb</automated>
    <automated>test -f app/views/admin/users/index.html.erb</automated>
    <automated>test -f app/views/admin/users/new.html.erb</automated>
    <automated>test -f app/views/admin/users/edit.html.erb</automated>
    <automated>test -f app/views/admin/users/_form.html.erb</automated>
    <automated>bin/rails routes -c admin/users | grep -E 'admin_users|admin/users'</automated>
    <automated>bundle exec rspec spec/requests/admin/users_spec.rb</automated>
  </verify>
  <acceptance_criteria>
    - `config/routes.rb` admin namespace includes `resources :users` (or `resources :users, except: [ :show ]`)
    - `bin/rails routes` lists `admin_users` (GET/POST), `new_admin_user`, `edit_admin_user`, `admin_user` (GET/PATCH/PUT/DELETE)
    - `Admin::UsersController` inherits from `Admin::BaseController` and defines `index`, `new`, `create`, `edit`, `update`, `destroy` with private `set_user` and `user_params`
    - `user_params` permits exactly: `:first_name, :last_name, :email, :password, :password_confirmation, :bio, :job_title, :linkedin_url, :twitter_handle, :avatar, :admin`
    - Update action strips `:password` and `:password_confirmation` from params when `params[:user][:password].blank?` so the existing password is preserved
    - Index view shows heading "Users" and subtitle "Manage admin users and author profiles" and a "New User" button linking to `new_admin_user_path`
    - Form partial uses `form_with(model: [:admin, @user]...)` and includes all fields named above
    - Submit button label is "Save User" on new and "Update User" on edit
    - `bundle exec rspec spec/requests/admin/users_spec.rb` exits 0 with all examples passing
    - Non-admin redirect spec confirms `redirect_to(root_path)` and flash includes "Access denied"
    - Invalid-LinkedIn-URL spec confirms response is `:unprocessable_entity` and no User row is created
  </acceptance_criteria>
  <done>Admin user CRUD is fully wired: routes, controller, four views, working create/update/destroy, blank-password preserves existing, request spec green covering happy path + non-admin redirect + URL validation error.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Admin browser → /admin/users | Admin posts user profile data; `ensure_admin!` gate enforces role |
| User-supplied linkedin_url → published author card (in P5) | URL ends up inside `link_to`; must be http(s) only |
| Avatar file → ActiveStorage | Admin uploads file; ActiveStorage stores via direct upload semantics |
| Devise password update | Blank password must preserve existing — never silently set password to empty |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-02-P4-01 | Tampering (XSS via linkedin_url) | User model validation | mitigate | `validates :linkedin_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), allow_blank: true }` rejects `javascript:`, `data:`, and other schemes; spec asserts `javascript:alert(1)` fails validation |
| T-02-P4-02 | Elevation of Privilege (non-admin reaches /admin/users) | Admin::BaseController | mitigate | `ensure_admin!` before_action redirects non-admin to root; spec asserts redirect + flash |
| T-02-P4-03 | Tampering (password reset bypass via blank password) | Admin::UsersController#update | mitigate | Controller explicitly strips `:password`/`:password_confirmation` when password param is blank, so the existing `encrypted_password` is never overwritten with the Devise-blank treatment; spec asserts `valid_password?("password123")` still passes after update with blank password |
| T-02-P4-04 | Information Disclosure (admin promoting non-admins) | admin attribute in user_params | accept | Admin promotion is intentional functionality — by definition an admin can grant admin to others. Acceptable for solo-developer marketing-team workflow per CONTEXT.md decisions. |
| T-02-P4-05 | Spoofing (avatar uploaded as non-image) | file_field accept attribute | mitigate | HTML accept attribute `image/*` filters the OS picker; server-side ActiveStorage content-type sniffing is the fallback. Note: admin-only surface. |
| T-02-P4-06 | Repudiation (delete user destroys audit trail) | destroy action | accept | Project already has `audits` table tracking destructive actions; admin destroying users is intentional and recorded by existing audit infrastructure |
</threat_model>

<verification>
- Migration applies cleanly
- `bin/rails runner` smoke checks for `full_name`, `initials`, URL validation, twitter normalization all pass
- Routes list includes `admin_users` and friends
- Request spec covers create/update/destroy/non-admin/URL-invalid
- Factory extension does not break existing specs
</verification>

<success_criteria>
- Phase Success Criterion #4 satisfied: "Admin users can fill in bio, job title, LinkedIn URL, Twitter handle, and upload an avatar on their profile"
- Requirement AUTH-02 covered end-to-end
- Admin user CRUD is shippable as a self-contained feature even before P5 wires authors to blog posts
</success_criteria>

<output>
After completion, create `.planning/phases/02-rich-content-author-profiles/02-P4-SUMMARY.md` summarizing: migration timestamp, model surface (full_name/initials/validation/normalization), routes mounted, controller actions, views created, factory traits, request spec coverage.
</output>
</output>
