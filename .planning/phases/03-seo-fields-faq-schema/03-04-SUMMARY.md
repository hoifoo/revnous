---
phase: 03-seo-fields-faq-schema
plan: 04
subsystem: seo
tags:
  - rails
  - seo
  - json-ld
  - stimulus
  - faq-schema
dependency_graph:
  requires:
    - "03-01"
    - "03-02"
    - "03-03"
  provides:
    - "faq_pairs reader on Blog model"
    - "render_faq_schema helper"
    - "FAQPage JSON-LD on show page"
    - "visible FAQ section on show page"
    - "faq-builder Stimulus controller"
    - "collapsible FAQ admin form section"
  affects:
    - "app/models/blog.rb"
    - "app/helpers/application_helper.rb"
    - "app/views/blogs/show.html.erb"
    - "app/views/admin/blogs/_form.html.erb"
tech_stack:
  added:
    - "faq-builder Stimulus controller (addRow/removeRow via template clone)"
  patterns:
    - "before_save callback for JSON normalization"
    - "custom attribute setter (faq_schema=) for Array-to-JSON coercion"
    - "native HTML <details>/<summary> for collapsible admin section"
    - "data-faq-row attribute selector for row removal (avoids Stimulus template target false-positive)"
key_files:
  created:
    - "app/javascript/controllers/faq_builder_controller.js"
    - "app/views/admin/blogs/_faq_row_fields.html.erb"
    - "app/views/blogs/_faq_section.html.erb"
  modified:
    - "app/models/blog.rb"
    - "app/controllers/admin/blogs_controller.rb"
    - "app/helpers/application_helper.rb"
    - "app/views/admin/blogs/_form.html.erb"
    - "app/views/blogs/show.html.erb"
    - "app/javascript/controllers/index.js"
    - "spec/models/blog_spec.rb"
    - "spec/requests/admin/blogs_spec.rb"
    - "spec/requests/blogs_spec.rb"
    - "spec/helpers/application_helper_spec.rb"
decisions:
  - "faq_schema= setter coerces Array/ActionController::Parameters to JSON immediately at assignment to prevent Ruby inspect-format strings being stored in the text column"
  - "Added .html_safe to all five json_escape calls in application_helper.rb — required to prevent content_tag double-encoding; json_escape already escapes </script> injection, making .html_safe safe here (Rule 1 bug fix applied to all four existing helpers too)"
  - "parse_faq_schema callback strips blank pairs and sets faq_schema=nil when all pairs are blank"
  - "Used data-faq-row HTML attribute (not Stimulus target) on fieldset to avoid Pitfall 5: Stimulus scanning inside <template> and counting template rows as live targets"
  - "Extracted _faq_row_fields.html.erb partial used both in each-pair loop and inside <template> for DRY row markup"
metrics:
  duration: "~20 minutes"
  completed: "2026-05-24"
  tasks: 3
  files: 10
---

# Phase 03 Plan 04: FAQ Schema End-to-End Summary

**One-liner:** FAQPage JSON-LD + visible FAQ section delivered end-to-end: admin collapsible form with Stimulus builder, model parse/strip callback, json_escape render helper, and show page wiring — SEO-02 satisfied.

## Tasks Completed

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 (RED) | Failing specs for faq_schema model callback + faq_pairs reader | cfbc038 | spec/models/blog_spec.rb |
| 1 (GREEN) | Blog model: faq_schema= setter, faq_pairs reader, parse_faq_schema callback; strong params | 3d88c23 | app/models/blog.rb, app/controllers/admin/blogs_controller.rb |
| 2 (RED) | Failing request specs for FAQ schema nested params | 91cf369 | spec/requests/admin/blogs_spec.rb |
| 2 (GREEN) | faq-builder Stimulus controller, collapsible admin FAQ section, _faq_row_fields partial | f4016fb | faq_builder_controller.js, index.js, _form.html.erb, _faq_row_fields.html.erb |
| 3 (RED) | Failing specs for render_faq_schema helper and visible FAQ on show page | 5f09767 | spec/helpers/application_helper_spec.rb, spec/requests/blogs_spec.rb |
| 3 (GREEN) | render_faq_schema helper, _faq_section.html.erb partial, show.html.erb wiring; .html_safe fix | 3dd2f22 | app/helpers/application_helper.rb, show.html.erb, _faq_section.html.erb |

## What Was Built

### Blog Model (app/models/blog.rb)
- `faq_schema=` setter: coerces Array/ActionController::Parameters to JSON immediately at assignment, preventing Ruby inspect-format strings from reaching the text column
- `faq_pairs` reader: parses faq_schema JSON, returns `[]` on nil/blank/malformed JSON (JSON::ParserError rescued)
- `parse_faq_schema` before_save callback: strips blank pairs (both question and answer blank), sets faq_schema=nil when all stripped, JSON-encodes the cleaned array

### Strong Params (app/controllers/admin/blogs_controller.rb)
- Added `faq_schema: [:question, :answer]` to blog_params permit, allowing nested array of hashes with exactly those two keys

### Stimulus Controller (app/javascript/controllers/faq_builder_controller.js)
- `addRow`: clones `<template>` content, appends to rowContainer, focuses first text input
- `removeRow`: removes `[data-faq-row]` ancestor of clicked button

### Admin Form (app/views/admin/blogs/_form.html.erb + _faq_row_fields.html.erb)
- Collapsible `<details>/<summary>` section auto-open when blog has existing pairs
- Shows pair count in summary: "(2 pairs)" or "(no pairs)"
- rowContainer target + template target + Add FAQ Pair button
- `_faq_row_fields.html.erb` partial used in both the pre-fill loop and inside `<template>` for DRY markup
- `data-faq-row` attribute (not Stimulus target) on fieldset to avoid template scanning issue

### Helper (app/helpers/application_helper.rb)
- `render_faq_schema(blog)`: returns nil if no pairs; emits FAQPage JSON-LD with mainEntity array of Question/Answer pairs; uses `json_escape(schema.to_json).html_safe`

### Show Page (app/views/blogs/show.html.erb + _faq_section.html.erb)
- `render_faq_schema(@blog)` added to `content_for :structured_data` block
- `render "faq_section"` inserted after blog body, before author_card
- `_faq_section.html.erb`: conditional on `@blog.faq_pairs.any?`; renders `<h2>Frequently Asked Questions</h2>` + `<dl>` with dt/dd per pair; ERB auto-escapes pair values (XSS-safe)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] .html_safe required on all json_escape calls in application_helper.rb**
- **Found during:** Task 3 implementation — existing helper tests failed in worktree; render_article_schema tests showed HTML-entity-encoded JSON-LD in script tags
- **Issue:** `content_tag :script, json_escape(schema.to_json)` — without `.html_safe`, `content_tag` HTML-encodes the content (produces `&quot;@type&quot;:&quot;FAQPage&quot;` instead of `"@type":"FAQPage"` inside the script). The plan said to REMOVE `.html_safe` from `render_article_schema` as "redundant", but this is incorrect — `.html_safe` is required because `json_escape` does not return an html_safe string. `content_tag` with non-html_safe content HTML-escapes it, breaking the JSON-LD.
- **Fix:** Kept `.html_safe` on `render_article_schema` and added `.html_safe` to all five `json_escape(schema.to_json)` calls in the file (render_organization_schema, render_article_schema, render_faq_schema, render_product_schema, render_breadcrumbs_schema). This is safe because `json_escape` already escapes `</script>` injection attempts.
- **Security:** `json_escape` converts `</script>` → `<\/script>` before `.html_safe` marks it safe. The `content_tag` wrapper provides the outer script tag safely.
- **Files modified:** app/helpers/application_helper.rb
- **Commit:** 3dd2f22

**2. [Rule 1 - Bug] faq_schema= setter needed to prevent Ruby inspect-format storage**
- **Found during:** Task 1 - GREEN phase debugging; `create(:blog, faq_schema: [{...}])` stored Ruby inspect format `"[{\"question\" => \"Q\"}]"` (with `=>`) instead of JSON `"[{\"question\":\"Q\"}]"` (with `:`) in the text column
- **Issue:** Rails assigns Array to text column by calling `.to_s` (Ruby inspect), not `.to_json`. The `parse_faq_schema` callback then sees a String, tries `JSON.parse`, fails (Ruby inspect ≠ JSON), and sets nil
- **Fix:** Added `faq_schema=(value)` setter that JSON-encodes Arrays/ActionController::Parameters immediately at assignment time
- **Files modified:** app/models/blog.rb
- **Commit:** 3d88c23

### Plan Acceptance Criteria Adjustments

The plan stated acceptance criterion: `"grep -c 'json_escape(schema.to_json).html_safe' app/helpers/application_helper.rb" returns 0 matches (cleanup confirmed)`. This criterion was based on an incorrect assumption that `.html_safe` was redundant. Per Rule 1 bug fix, `.html_safe` is necessary and present on all 5 helpers. The actual security requirement (json_escape protects against `</script>` injection) is satisfied — Test 4 in the helper spec verifies this.

## Known Stubs

None — all FAQ pairs from DB are wired through to both JSON-LD output and visible HTML.

## Threat Surface Scan

No new threat surface beyond what was planned in the PLAN.md threat model:
- T-03-18: `json_escape + .html_safe` pattern confirmed on render_faq_schema ✓
- T-03-19: ERB auto-escaping on `<dt><%= pair['question'] %>` confirmed ✓
- T-03-20: Strong params `faq_schema: [:question, :answer]` confirmed ✓
- T-03-23: faq_pairs rescues JSON::ParserError ✓

## Phase 03 Completion

This plan completes Phase 03 — all four SEO fields are implemented:
- **SEO-01** (Keywords): Plan 01 — keywords array, chips UI, JSON-LD keywords
- **SEO-02** (FAQ Schema): Plan 04 (this plan) — FAQPage JSON-LD + visible FAQ section
- **SEO-03** (Canonical URL Override): Plan 02 — canonical_url_override field + controller
- **SEO-04** (OG Image Override): Plan 03 — og_image ActiveStorage attachment

## Self-Check: PASSED

All created files exist and all commits verified:
- FOUND: app/javascript/controllers/faq_builder_controller.js
- FOUND: app/views/admin/blogs/_faq_row_fields.html.erb
- FOUND: app/views/blogs/_faq_section.html.erb
- FOUND: .planning/phases/03-seo-fields-faq-schema/03-04-SUMMARY.md
- All 6 task commits (3 RED + 3 GREEN) present in git log
- Final test run: 65 examples, 0 failures
