# Phase 1: Editor Foundation - Pattern Map

**Mapped:** 2026-05-13
**Files analyzed:** 11 (new/modified)
**Analogs found:** 11 / 11

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `db/migrate/YYYYMMDDHHMMSS_add_body_to_blogs.rb` | migration | transform | `db/migrate/20251211144657_add_meta_fields_to_blogs.rb` | exact |
| `lib/tasks/blogs.rake` | utility | batch | `db/migrate/20251216121901_migrate_blog_content_to_rich_text.rb` | role-match (same data, different mechanism) |
| `app/javascript/controllers/tiptap_editor_controller.js` | controller (Stimulus) | event-driven | `app/javascript/controllers/hello_controller.js` | role-match (same lifecycle, richer pattern) |
| `app/javascript/controllers/index.js` | config | — | `app/javascript/controllers/index.js` (self — add one line) | exact |
| `app/models/blog.rb` | model | CRUD | `app/models/legal_document.rb` | exact (constants + callback pattern) |
| `app/javascript/application.js` | config | — | `app/javascript/application.js` (self — remove 2 lines) | exact |
| `app/controllers/admin/blogs_controller.rb` | controller | request-response | `app/controllers/admin/blogs_controller.rb` (self — change strong params) | exact |
| `app/views/admin/blogs/_form.html.erb` | component (view partial) | request-response | `app/views/admin/blogs/_form.html.erb` (self — replace rich_text_area block) | exact |
| `app/views/blogs/show.html.erb` | component (view) | request-response | `app/views/blogs/show.html.erb` (self — change line 62) | exact |
| `app/helpers/application_helper.rb` | utility | request-response | `app/helpers/application_helper.rb` (self — 4 targeted substitutions) | exact |
| `app/assets/stylesheets/application.tailwind.css` | config | — | `app/assets/stylesheets/application.tailwind.css` (self — swap plugin line) | exact |
| `spec/factories/blogs.rb` | test | — | `spec/factories/blogs.rb` (self — rename attribute) | exact |

---

## Pattern Assignments

### `db/migrate/YYYYMMDDHHMMSS_add_body_to_blogs.rb` (migration, transform)

**Analog:** `db/migrate/20251211144657_add_meta_fields_to_blogs.rb`

**Full analog** (lines 1–7):
```ruby
class AddMetaFieldsToBlogs < ActiveRecord::Migration[8.0]
  def change
    add_column :blogs, :meta_title, :string
    add_column :blogs, :meta_description, :text
  end
end
```

**Copy pattern:** Single `add_column` call inside `def change`. New migration adds one `text` column named `body` with no default (body will be nil until the Rake backfill runs).

```ruby
class AddBodyToBlogs < ActiveRecord::Migration[8.0]
  def change
    add_column :blogs, :body, :text
  end
end
```

---

### `lib/tasks/blogs.rake` (utility, batch)

**Analog:** `db/migrate/20251216121901_migrate_blog_content_to_rich_text.rb`

**Core migration loop pattern** (lines 8–22 of analog):
```ruby
# Stub class pattern — avoid depending on current model state during data migration
class MigrationBlog < ApplicationRecord
  self.table_name = "blogs"
end

MigrationBlog.find_each do |blog|
  content = blog.read_attribute(:content)
  next if content.blank?

  ActionText::RichText.create!(
    record_type: "Blog",
    record_id: blog.id,
    name: "content",
    body: content
  )
end
```

**Key pattern to copy:** `find_each` for memory-safe batching; `read_attribute(:body)` to bypass ActiveRecord associations and read raw column value; `next if condition` for skipping guard; `update_column` to bypass callbacks when writing migration data.

**Rake namespace/desc pattern** (no analog in codebase — use standard Rails convention):
```ruby
# lib/tasks/blogs.rake
namespace :blogs do
  desc "Migrate blog content from ActionText to blogs.body column"
  task migrate_body: :environment do
    # task body
  end
end
```

**Progress output pattern** (from CONTEXT.md specifics):
```ruby
total = Blog.count
migrated = 0
puts "Migrated #{migrated}/#{total} posts"   # per-record
puts "Done. #{migrated} posts migrated, #{skipped} skipped."  # final
```

**Idempotent skip guard** (pattern from analog's `next if content.blank?`):
```ruby
if blog.body.present?
  puts "Skipping post #{blog.id} — body already populated"
  skipped += 1
  next
end
```

**Nokogiri stripping pattern** (no codebase analog — use RESEARCH.md Pattern 5):
```ruby
doc = Nokogiri::HTML.fragment(raw_html)
doc.css("action-text-attachment").each(&:remove)
clean_html = doc.to_html
```

---

### `app/javascript/controllers/tiptap_editor_controller.js` (controller, event-driven)

**Analog:** `app/javascript/controllers/hello_controller.js`

**Analog structure** (lines 1–7):
```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.textContent = "Hello World!"
  }
}
```

**Import pattern** — copy this base, add Tiptap-specific imports:
```javascript
import { Controller } from "@hotwired/stimulus"
import { Editor } from "@tiptap/core"
import StarterKit from "@tiptap/starter-kit"
import { Placeholder } from "@tiptap/extensions"
```

**Stimulus target declaration** (new file — no project analog; standard Stimulus 3 pattern):
```javascript
static targets = ["editor", "input"]
```

**connect/disconnect lifecycle** (extend from hello_controller's `connect()` shape):
```javascript
connect() {
  // initialize editor; sync hidden input immediately
  this.inputTarget.value = this.editor.getHTML()
}

disconnect() {
  if (this.editor) {
    this.editor.destroy()
    this.editor = null
  }
}
```

**Turbo cache teardown** (no project analog — see RESEARCH.md Pitfall 2):
```javascript
// In application.js, add once:
document.addEventListener('turbo:before-cache', () => {
  application.controllers.forEach(controller => {
    if (typeof controller.teardown === 'function') {
      controller.teardown()
    }
  })
})
```

**toolbar action method naming convention** — follow `snake_case` converted to `camelCase` per Stimulus convention (CLAUDE.md: snake_case for Ruby methods; JS uses camelCase):
```javascript
toggleBold()   { this.editor.chain().focus().toggleBold().run() }
toggleItalic() { this.editor.chain().focus().toggleItalic().run() }
setHeading(event) {
  const level = parseInt(event.params.level)
  this.editor.chain().focus().toggleHeading({ level }).run()
}
```

---

### `app/javascript/controllers/index.js` (config — add one line)

**Analog:** `app/javascript/controllers/index.js` (self)

**Current structure** (lines 1–9):
```javascript
// This file is auto-generated by ./bin/rails stimulus:manifest:update
// Run that command whenever you add a new controller or create them with
// ./bin/rails generate stimulus controllerName

import { application } from "./application"

import HelloController from "./hello_controller"
application.register("hello", HelloController)
```

**Pattern to copy:** Append registration using identical pattern to line 8–9:
```javascript
import TiptapEditorController from "./tiptap_editor_controller"
application.register("tiptap-editor", TiptapEditorController)
```

---

### `app/models/blog.rb` (model, CRUD — modify)

**Analog:** `app/models/legal_document.rb`

**Constants pattern** (legal_document.rb lines 6–7):
```ruby
DOCUMENT_TYPES = %w[privacy_policy terms_of_service].freeze
```

**Apply:** Define sanitization constants at the top of the class, before validations:
```ruby
ALLOWED_TAGS = %w[p br h1 h2 h3 h4 h5 h6 ul ol li strong em a blockquote code pre].freeze
ALLOWED_ATTRIBUTES = %w[href target rel].freeze
```

**Callback pattern** (legal_document.rb lines 16–17):
```ruby
before_validation :generate_slug, if: -> { slug.blank? && title.present? }
before_validation :set_default_effective_date, if: -> { effective_date.blank? }
```

**Apply:** Add `before_save` callback (after the existing `before_validation`):
```ruby
before_save :sanitize_body
```

**Private method pattern** (legal_document.rb lines 68–74):
```ruby
private

def generate_slug
  base_slug = title.parameterize
  self.slug = product_id ? "#{product_id}-#{base_slug}" : base_slug
end
```

**Apply:** Add `sanitize_body` private method following the same style:
```ruby
private

def sanitize_body
  return if body.blank?
  sanitizer = Rails::Html::SafeListSanitizer.new
  self.body = sanitizer.sanitize(body, tags: ALLOWED_TAGS, attributes: ALLOWED_ATTRIBUTES)
end
```

**Changes required to existing blog.rb:**
- Line 5: change `validates :title, :content, presence: true` → `validates :title, :body, presence: true`
- Line 8: remove `has_rich_text :content`
- Line 21: change `strip_tags(content)` → `strip_tags(body)` in `seo_description`

**Current blog.rb full file** (lines 1–42) — read before editing:
```ruby
class Blog < ApplicationRecord
  has_one_attached :image
  has_and_belongs_to_many :products

  validates :title, :content, presence: true    # CHANGE: :content → :body
  validates :slug, uniqueness: true, allow_nil: true

  has_rich_text :content                        # REMOVE this line

  before_validation :generate_slug, on: :create

  scope :published, -> { where("published_at <= ?", Time.current).order(published_at: :desc) }
  scope :featured, -> { where(featured: true) }
  scope :featured_on_home, -> { where(featured_on_home: true) }

  def seo_title
    meta_title.presence || "#{title} - Revnous"
  end

  def seo_description
    meta_description.presence || ActionController::Base.helpers.strip_tags(content).truncate(160)
    # CHANGE: strip_tags(content) → strip_tags(body)
  end
  # ...
end
```

---

### `app/javascript/application.js` (config — remove 2 lines)

**Current file** (lines 1–7):
```javascript
// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import "./controllers"
import "./altcha"

import "trix"               // REMOVE
import "@rails/actiontext"  // REMOVE
```

**After removal, also add the turbo:before-cache listener here** (see RESEARCH.md Pitfall 2):
```javascript
import { application } from "./controllers/application"

document.addEventListener('turbo:before-cache', () => {
  application.controllers.forEach(controller => {
    if (typeof controller.teardown === 'function') controller.teardown()
  })
})
```

---

### `app/controllers/admin/blogs_controller.rb` (controller, request-response — modify)

**Analog:** `app/controllers/admin/blogs_controller.rb` (self)

**Strong params pattern** (lines 44–51):
```ruby
def blog_params
  params.require(:blog).permit(
    :title, :author, :published_at, :category,
    :excerpt, :content, :slug, :featured, :featured_on_home, :image,
    :meta_title, :meta_description,
    product_ids: []
  )
end
```

**Change:** Replace `:content` with `:body` in the permit list. No other changes to this file.

**Auth pattern** (inherited — no change needed):
```ruby
class Admin::BlogsController < Admin::BaseController
  # Admin::BaseController provides:
  #   before_action :authenticate_user!
  #   before_action :ensure_admin!
```

**Error rendering pattern** (lines 14–18, 25–30 — no change):
```ruby
if @blog.save
  redirect_to admin_blogs_path, notice: "Blog post created successfully."
else
  render :new, status: :unprocessable_entity
end
```

---

### `app/views/admin/blogs/_form.html.erb` (component, request-response — modify)

**Analog:** `app/views/admin/blogs/_form.html.erb` (self)

**Form field label + input pattern** (lines 17–19):
```erb
<%= form.label :title, class: "block text-sm font-medium text-gray-700 mb-2" %>
<%= form.text_field :title, class: "w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-pink-500 focus:border-transparent" %>
```

**Rich text area to replace** (lines 85–88):
```erb
<div>
  <%= form.label :content, class: "block text-sm font-medium text-gray-700 mb-2" %>
  <%= form.rich_text_area :content, class: "..." %>
  <p class="text-sm text-gray-500 mt-1">Supports rich text, images, and formatting</p>
</div>
```

**Replace with Tiptap editor div** (copy structure, new content):
```erb
<div>
  <%= form.label :body, "Content", class: "block text-sm font-medium text-gray-700 mb-2" %>
  <div class="tiptap-editor" data-controller="tiptap-editor">
    <!-- Toolbar (sticky) -->
    <div class="tiptap-toolbar sticky top-0 z-10 bg-white border border-gray-300 rounded-t-md px-3 py-2 flex items-center gap-1 flex-wrap">
      <!-- toolbar buttons — see UI-SPEC Component Specifications section -->
    </div>
    <!-- Editor area -->
    <div class="ProseMirror prose prose-lg max-w-none min-h-[400px] px-4 py-3 border border-t-0 border-gray-300 rounded-b-md focus:outline-none focus:ring-2 focus:ring-pink-500"
         data-tiptap-editor-target="editor"
         role="textbox"
         aria-multiline="true"
         aria-label="Blog content">
    </div>
    <!-- Hidden input for form submission -->
    <input type="hidden"
           name="blog[body]"
           value="<%= @blog.body.to_s %>"
           data-tiptap-editor-target="input">
  </div>
  <p class="text-sm text-gray-500 mt-1">Supports rich text and heading formatting</p>
</div>
```

**Sticky top offset note:** Use `top-0` (not `top-16`). Admin header is `position: static` and scrolls away. See RESEARCH.md Pitfall 1.

**Error block pattern** (lines 2–13 — reuse without modification):
```erb
<% if @blog.errors.any? %>
  <div class="bg-red-50 border-l-4 border-red-500 p-4">
    <h3 class="text-sm font-medium text-red-800 mb-2">
      <%= pluralize(@blog.errors.count, "error") %> prohibited this blog from being saved:
    </h3>
    <ul class="list-disc list-inside text-sm text-red-700">
      <% @blog.errors.each do |error| %>
        <li><%= error.full_message %></li>
      <% end %>
    </ul>
  </div>
<% end %>
```

**Submit button pattern** (lines 101–103 — reuse without modification):
```erb
<%= form.submit class: "px-6 py-2 bg-pink-600 text-white rounded-md hover:bg-pink-700 transition font-medium cursor-pointer" %>
```

---

### `app/views/blogs/show.html.erb` (component, request-response — modify)

**Analog:** `app/views/blogs/show.html.erb` (self)

**Line to change** (line 61–63):
```erb
<!-- Content — CURRENT (broken after migration) -->
<div class="prose prose-lg max-w-none mb-16">
  <%= @blog.content %>
</div>
```

**Change to:**
```erb
<!-- Content — AFTER -->
<div class="prose prose-lg max-w-none mb-16">
  <%= raw @blog.body %>
</div>
```

**Note:** The `prose prose-lg max-w-none` wrapper div at line 61 stays unchanged. Only the inner `<%= @blog.content %>` is replaced with `<%= raw @blog.body %>`. `raw` is safe here because `sanitize_body` runs at `before_save`, ensuring `body` contains only whitelisted tags.

---

### `app/helpers/application_helper.rb` (utility, request-response — modify)

**Analog:** `app/helpers/application_helper.rb` (self)

**Vulnerable pattern** (4 locations — lines 61, 87, 111, 130):
```ruby
content_tag :script, schema.to_json.html_safe, type: "application/ld+json"
```

**Fix pattern** (apply identically to all 4 occurrences):
```ruby
content_tag :script, json_escape(schema.to_json), type: "application/ld+json"
```

**Affected methods:**
- `render_organization_schema` (line 61)
- `render_article_schema` (line 87)
- `render_product_schema` (line 111)
- `render_breadcrumbs_schema` (line 130)

**Important:** `json_escape` returns a non-html_safe string. `content_tag` internally calls `ERB::Util.html_escape` on its content block — but when the string is already escaped via `json_escape`, the double-escaping of JSON-specific characters (the `<`, `>` that matter for injection) does not occur because `json_escape` converts them to `<` / `>` Unicode sequences which are inert in JSON and pass through html_escape safely.

---

### `app/assets/stylesheets/application.tailwind.css` (config — swap import)

**Analog:** `app/assets/stylesheets/application.tailwind.css` (self)

**Current file** (lines 1–5):
```css
@import "tailwindcss";
@import "./actiontext.css";      /* REMOVE */

.trix-content a {                /* REMOVE this entire rule */
    @apply text-pink-600 hover:text-pink-700 underline decoration-pink-300 underline-offset-2;
}
```

**After changes:**
```css
@import "tailwindcss";
@plugin "@tailwindcss/typography";

/* Only add below if prose classes bleed from admin layout styles (try without first): */
/* .tiptap-editor .ProseMirror {
  @apply prose prose-lg max-w-none;
} */
```

**Note:** The `@plugin` directive is the Tailwind CSS 4 equivalent of adding to `plugins: []` in `tailwind.config.js`. No `tailwind.config.js` file exists in this project and none should be created.

---

### `spec/factories/blogs.rb` (test — rename attribute)

**Analog:** `spec/factories/blogs.rb` (self)

**Current** (line 5):
```ruby
content { "Blog post content with lots of interesting information." }
```

**Change to:**
```ruby
body { "<p>Blog post content with lots of interesting information.</p>" }
```

**Rationale:** After removing `has_rich_text :content`, FactoryBot assigns `:content` as a plain attribute. The `blogs` table has no `content` column, causing `ActiveRecord::UnknownAttributeError` in all tests using `create(:blog)`. The body value should be wrapped in `<p>` tags because that is what Tiptap outputs — and the `before_save :sanitize_body` callback allows `<p>` tags through the safelist.

---

## Shared Patterns

### Admin Authentication Guard
**Source:** `app/controllers/admin/base_controller.rb` (lines 1–18)
**Apply to:** `app/controllers/admin/blogs_controller.rb` (already inherited — no action needed)

```ruby
class Admin::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin!

  layout "admin"

  private

  def ensure_admin!
    unless current_user&.admin?
      redirect_to root_path, alert: "Access denied. Admin privileges required."
    end
  end
end
```

### Controller Error Rendering
**Source:** `app/controllers/admin/blogs_controller.rb` (lines 14–20, 25–31)
**Apply to:** No new controllers in Phase 1 — pattern stays in place

```ruby
if @blog.save
  redirect_to admin_blogs_path, notice: "Blog post created successfully."
else
  render :new, status: :unprocessable_entity
end
```

### Model Callback + Private Method
**Source:** `app/models/legal_document.rb` (lines 16–17, 66–74) and `app/models/blog.rb` (lines 10, 38–41)
**Apply to:** `app/models/blog.rb` `sanitize_body` addition

```ruby
# Callback declaration (before private keyword):
before_save :sanitize_body

# Private method (after private keyword, matching generate_slug style):
private

def sanitize_body
  return if body.blank?
  # ...
end
```

### Form Field Pattern (Tailwind classes)
**Source:** `app/views/admin/blogs/_form.html.erb` (lines 17–19)
**Apply to:** All form fields including the new Tiptap container label

```erb
class: "block text-sm font-medium text-gray-700 mb-2"    # label
class: "w-full px-4 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-pink-500 focus:border-transparent"  # input
```

### Stimulus Controller Lifecycle
**Source:** `app/javascript/controllers/hello_controller.js` (lines 1–7)
**Apply to:** `app/javascript/controllers/tiptap_editor_controller.js`

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() { /* initialize */ }
  disconnect() { /* cleanup */ }
}
```

---

## No Analog Found

All files have analogs. No entries in this section.

---

## Metadata

**Analog search scope:** `app/models/`, `app/controllers/admin/`, `app/views/admin/blogs/`, `app/views/blogs/`, `app/javascript/controllers/`, `app/helpers/`, `app/assets/stylesheets/`, `db/migrate/`, `spec/factories/`
**Files scanned:** 18
**Pattern extraction date:** 2026-05-13
