---
phase: 03-seo-fields-faq-schema
reviewed: 2026-05-24T00:00:00Z
depth: standard
files_reviewed: 14
files_reviewed_list:
  - app/controllers/admin/blogs_controller.rb
  - app/controllers/blogs_controller.rb
  - app/helpers/application_helper.rb
  - app/javascript/controllers/faq_builder_controller.js
  - app/javascript/controllers/index.js
  - app/models/blog.rb
  - app/views/admin/blogs/_faq_row_fields.html.erb
  - app/views/admin/blogs/_form.html.erb
  - app/views/blogs/_faq_section.html.erb
  - app/views/blogs/show.html.erb
  - spec/helpers/application_helper_spec.rb
  - spec/models/blog_spec.rb
  - spec/requests/admin/blogs_spec.rb
  - spec/requests/blogs_spec.rb
findings:
  critical: 3
  warning: 4
  info: 2
  total: 9
status: issues_found
---

# Phase 03: Code Review Report

**Reviewed:** 2026-05-24
**Depth:** standard
**Files Reviewed:** 14
**Status:** issues_found

## Summary

Phase 03 added keywords (jsonb), canonical_url_override, og_image (ActiveStorage), faq_schema (text/JSON), FAQPage JSON-LD, and a visible FAQ section. The structural choices are sound: `json_escape` is used consistently in JSON-LD helpers, ERB auto-escaping protects the FAQ HTML section, and the og_image content-type allowlist correctly excludes SVG. However, three blockers were found: a side-effect-in-validation method that calls `og_image.purge` inside `validate :validate_og_image_content_type` (data-loss risk on the wrong lifecycle event), a `blog[:author]` write that bypasses strong params and is applied before `update` in the update action (creating an unsaved state window), and an XSS risk in the share section where `request.original_url` and `@blog.title` are interpolated unescaped into href attributes. Four warnings cover the double-JSON-encode risk in `faq_schema=`, an absent nil guard in `og_image_for`, a flawed injection test assertion in the helper spec, and missing slug update protection in the admin controller strong params.

---

## Critical Issues

### CR-01: `og_image.purge` Called Inside a Validator — Data Loss on Reload / Re-validate

**File:** `app/models/blog.rb:97`

**Issue:** `validate_og_image_content_type` calls `og_image.purge` while executing as a `validate` callback. Rails validators are expected to be side-effect-free — they are called by `valid?`, which is invoked automatically on every `save`, by `update_attributes`, by any manual `valid?` call in tests or console sessions, and potentially twice per request if a controller calls `valid?` before `save`. The purge call is an irreversible ActiveStorage deletion that fires before the transaction commits. More critically, if a record is re-validated after a prior successful attach (e.g., another field fails validation), the existing og_image is destroyed even though the current upload was never invalid. The correct pattern is a `before_save` callback that purges-and-errors only when about to persist, or using `errors.add` alone in the validator and purging in a `before_save`.

Additionally, `og_image.purge` issues a database write (marking the blob for deletion) inside what ActiveRecord considers a pure-read callback chain, which can cause partial-transaction states.

**Fix:**
```ruby
# In validate callback: only add the error, do not purge
def validate_og_image_content_type
  return unless og_image.attached?

  allowed_types = %w[image/png image/jpeg image/jpg image/gif image/webp]
  unless allowed_types.include?(og_image.blob.content_type.to_s.downcase)
    errors.add(:og_image, "must be a PNG, JPEG, GIF, or WebP image")
  end
end

# Separate before_save callback to discard the attachment before it is persisted
before_save :discard_invalid_og_image

def discard_invalid_og_image
  return unless og_image.attached?

  allowed_types = %w[image/png image/jpeg image/jpg image/gif image/webp]
  unless allowed_types.include?(og_image.blob.content_type.to_s.downcase)
    og_image.purge
  end
end
```

---

### CR-02: `@blog[:author]` Written Before `update` — Bypasses Strong Params and Creates Unsaved-State Window

**File:** `app/controllers/admin/blogs_controller.rb:27-28`

**Issue:** In the `update` action, the controller writes directly to the model attribute with `@blog[:author] = params.dig(:blog, :author).presence` before calling `@blog.update(blog_params)`. This has two problems:

1. `author` is not in the `permitted` list inside `blog_params` (lines 47-49), yet it is written via raw `params.dig` without any whitelist check. A malicious POST body can supply any value for the author column without going through `permit`. Strong params exists precisely to prevent this.

2. The attribute is mutated on the in-memory object before `update` is called. If `update` fails (validation error), the dirty attribute `@blog[:author]` is still set on the object that gets re-rendered in the edit form — the unsaved value is shown as if it were persisted. This is the same bug pattern in `create` (line 14).

**Fix:** Add `author` to the `permitted` list in `blog_params` so it goes through the normal whitelist, and remove the out-of-band assignment:
```ruby
def blog_params
  permitted = %i[title author author_id published_at category
                 excerpt body featured featured_on_home image og_image
                 meta_title meta_description spacing canonical_url_override]
  permitted << :slug if action_name == 'create'
  params.require(:blog).permit(*permitted, product_ids: [], keywords: [], faq_schema: [:question, :answer])
end

# In create:
def create
  @blog = Blog.new(blog_params)
  # no separate @blog[:author] assignment needed
  ...
end

# In update:
def update
  if @blog.update(blog_params)
  ...
end
```

---

### CR-03: Unescaped `request.original_url` and `@blog.title` in Share Link `href` Attributes — Reflected XSS

**File:** `app/views/blogs/show.html.erb:74-83`

**Issue:** The three share links (Twitter, LinkedIn, Facebook) interpolate `request.original_url` and `@blog.title` directly into ERB expressions inside `href` attributes:

```erb
href="https://twitter.com/intent/tweet?url=<%= request.original_url %>&text=<%= @blog.title %>"
```

ERB's `<%= %>` auto-escapes HTML entities in text nodes and attribute values, so `<` becomes `&lt;`, etc. However, ERB does NOT encode for URL context — it does not percent-encode characters. If a blog title contains `&` or `"` the attribute is malformed. More critically, `request.original_url` is attacker-controlled (it reflects the full request URL including query string). A crafted URL like `/blog/slug?x="><script>alert(1)</script>` would be HTML-escaped by ERB, but a URL with a double-quote character `"` would break out of the `href="..."` attribute context. Rails' `html_escape` converts `"` to `&quot;`, so in practice simple injection is blocked — but the canonical safe pattern for building query-string hrefs is `url_encode` / `CGI.escape` on the dynamic parts, not raw interpolation. As written, a slug or title containing a `#` or `&` will produce a malformed URL, and any future change to the ERB escaping mode (e.g., moving to a JS template) would become a live XSS.

**Fix:**
```erb
<a href="https://twitter.com/intent/tweet?url=<%= CGI.escape(request.original_url) %>&text=<%= CGI.escape(@blog.title) %>"
   target="_blank" rel="noopener noreferrer" ...>
  Twitter
</a>
<a href="https://www.linkedin.com/sharing/share-offsite/?url=<%= CGI.escape(request.original_url) %>"
   target="_blank" rel="noopener noreferrer" ...>
  LinkedIn
</a>
<a href="https://www.facebook.com/sharer/sharer.php?u=<%= CGI.escape(request.original_url) %>"
   target="_blank" rel="noopener noreferrer" ...>
  Facebook
</a>
```

Also add `rel="noopener noreferrer"` to all three external `target="_blank"` links — currently absent, enabling tab-napping.

---

## Warnings

### WR-01: `faq_schema=` Custom Writer Double-Encodes When Given a Pre-Encoded JSON String

**File:** `app/models/blog.rb:53-61`

**Issue:** The custom `faq_schema=` writer JSON-encodes the value when it receives an `Array` or `ActionController::Parameters`. The `parse_faq_schema` before_save callback then parses that JSON string and re-encodes it. However, if `faq_schema=` is called with a plain String (e.g., the already-encoded result of a prior save being assigned back), the writer passes it through to `super` unchanged, and `parse_faq_schema` subsequently parses and re-encodes it. This is correct for that path.

The risk is the interaction with the test in `blog_spec.rb:183-189` which passes a pre-encoded JSON string directly to `Blog.new`. With the current writer this hits the `else` branch and passes the string through, which is then parsed by `parse_faq_schema` — this works. But if an `ActionController::Parameters` object that serializes to JSON string is passed, `Array(value)` on it will produce `[the-params-object]` (an array of one Parameters object), which `.to_json` will serialize incorrectly rather than as an array of hashes. The `is_a?(ActionController::Parameters)` branch should call `value.to_unsafe_h.values` or use `value.permit(:question, :answer)` to safely convert, not `Array(value)`.

**Fix:**
```ruby
def faq_schema=(value)
  if value.is_a?(ActionController::Parameters)
    super(value.values.map(&:to_unsafe_h).to_json)
  elsif value.is_a?(Array)
    super(value.to_json)
  else
    super(value)
  end
end
```

---

### WR-02: `og_image_for` in Public Controller Returns `nil` Without Fallback When `og_image_url` Returns `nil`

**File:** `app/controllers/blogs_controller.rb:33-41`

**Issue:** `og_image_for` calls `blog.og_image_url`, which wraps its URL generation in a `rescue StandardError => nil`. If URL generation raises (e.g., no host configured, a known test-environment condition documented in the model), the method returns `nil`. `og_image_for` does not guard against this nil — it returns `nil` to `@page_og_image`, and `page_og_image` in `ApplicationHelper` falls back to `asset_url("logo.png")` only when `@page_og_image` is blank. `nil` is blank, so the fallback triggers correctly. However, the same nil-return risk exists for the `blog.cover_photo_url` branch (line 38), and it is not documented or tested. The intent clearly is to always return a non-nil URL string, but two out of three branches can silently return nil in degraded environments, breaking og:image in production if storage is misconfigured.

**Fix:** Add explicit nil guards in `og_image_for`:
```ruby
def og_image_for(blog)
  if blog.og_image.attached?
    blog.og_image_url.presence || (blog.image.attached? ? blog.cover_photo_url.presence : nil)
  elsif blog.image.attached?
    blog.cover_photo_url.presence
  end
  # nil return flows to page_og_image helper fallback — acceptable, but document it
end
```

---

### WR-03: Injection Escape Test Assertion in Helper Spec is Too Weak to Prove Safety

**File:** `spec/helpers/application_helper_spec.rb:47-57`

**Issue:** The test "escapes </script> injection attempts in FAQ answer" has a flawed assertion on line 56:
```ruby
expect(output).to match(/Hack|Safe|\\/i)
```
This matches if the output contains `Hack`, `Safe`, OR a literal backslash. The test uses `"Safe?"` as the question, so `Safe` will always match regardless of whether the injection was escaped or not. The assertion cannot distinguish between "injection was escaped" and "output contains the word Safe". Furthermore the regex `\\/` in a `//` regexp literal is just `\/` which is a literal forward slash — it would match the closing tag of the script too. The test passes even if the injection succeeds.

A correct assertion would verify the literal escaped form of the dangerous string appears, or verify the raw injection string does not appear:
```ruby
it "escapes </script> injection attempts in FAQ answer" do
  blog = build(:blog)
  allow(blog).to receive(:faq_pairs).and_return(
    [{ "question" => "Safe?", "answer" => "</script><script>alert(1)</script>" }]
  )

  output = helper.render_faq_schema(blog)

  # The raw injection sequence must not appear in output
  expect(output).not_to include("</script><script>")
  # The escaped form must appear (json_escape turns </ into <\/)
  expect(output).to include('<\\/script>')
end
```

---

### WR-04: Slug Can Be Updated via Strong Params on `update` Action

**File:** `app/controllers/admin/blogs_controller.rb:50`

**Issue:** The strong params method guards slug inclusion with `permitted << :slug if action_name == 'create'`. This correctly prevents slug from being set on update. However, the `blog_params` method is also called during `update`, and a `PATCH` request can submit `blog[slug]` — it will be silently ignored. This is correct behavior. The concern is the inverse: there is no validation or model callback preventing slug changes on update. If a developer later removes the `action_name` guard, all existing blog URLs would break silently. A `validates :slug, on: :update` immutability check in the model would make this invariant explicit and resilient.

This is a quality/defensibility concern rather than an active bug, but it is worth noting because published blogs depend on stable slugs for SEO.

**Fix:** Add a model-level guard:
```ruby
validates :slug, on: :update do
  errors.add(:slug, "cannot be changed after publication") if slug_changed? && slug_was.present?
end
```

---

## Info

### IN-01: `data-faq-row` Attribute on `<template>` Contents Not Scoped — `removeRow` Would Silently No-Op on Rows Added From Template if Attribute Is Removed

**File:** `app/javascript/controllers/faq_builder_controller.js:15`

**Issue:** `removeRow` uses `event.currentTarget.closest('[data-faq-row]')?.remove()`. The optional chaining means if `[data-faq-row]` is not found (e.g., a future template change removes the attribute), the remove silently does nothing. There is no user feedback. This is a fragile coupling between the JS controller and the ERB partial's internal DOM structure.

**Fix:** Add a guard with a console warning for missing DOM structure in development:
```javascript
removeRow(event) {
  event.preventDefault()
  const row = event.currentTarget.closest('[data-faq-row]')
  if (!row) {
    console.warn('faq-builder: removeRow could not find [data-faq-row] ancestor')
    return
  }
  row.remove()
}
```

---

### IN-02: `render_faq_schema` Redundant `respond_to?` Check

**File:** `app/helpers/application_helper.rb:99`

**Issue:** `blog.respond_to?(:faq_pairs) && blog.faq_pairs.any?` — `faq_pairs` is defined on `Blog` and `render_faq_schema` is only called with a `Blog` instance (from `show.html.erb`). The `respond_to?` check adds no real safety and obscures intent. It would silently skip FAQ rendering if `faq_pairs` were accidentally removed from the model rather than raising a clear `NoMethodError`.

**Fix:**
```ruby
def render_faq_schema(blog)
  return nil unless blog.faq_pairs.any?
  # ...
end
```

---

_Reviewed: 2026-05-24_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
