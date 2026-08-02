---
phase: 01-toc-domain-core-regression-baseline
verified: 2026-08-02T20:09:56Z
status: passed
score: 4/4 must-haves verified
overrides_applied: 0
---

# Phase 01: TOC Domain Core & Regression Baseline Verification Report

**Phase Goal:** The system can derive a stable, uniquely anchored TOC from any post's body HTML, and today's public rendering is frozen under an executable test before anything visual changes
**Verified:** 2026-08-02T20:09:56Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Derivation returns ordered H2/H3 entries only, `toc-` prefixed unique anchors, dedup counter suffix, positional `toc-section-N` fallback for empty-slug headings | ✓ VERIFIED | `app/models/blog/table_of_contents.rb` implements `HEADING_SELECTOR = "h2, h3"`, used-set probe `allocate_anchor`, `base_slug` positional fallback. `spec/models/blog/table_of_contents_spec.rb` (15 examples incl. emoji/CJK/Cyrillic/punctuation cases, both dedup pitfalls) — ran live: `79 examples, 0 failures` across model + PORO + golden-master + toc-request specs |
| 2 | Rendered `/blog/:slug` response body contains matching `id` attributes on exactly H2/H3 headings, injected downstream of the last sanitizer, `Blog::ALLOWED_ATTRIBUTES` unchanged, no `id` in any sanitizer allowlist | ✓ VERIFIED | `app/views/blogs/show.html.erb:76` wraps the unmodified `sanitize(@blog.body, tags: Blog::ALLOWED_TAGS, attributes: Blog::ALLOWED_ATTRIBUTES)` call in `blog_body_with_toc_anchors`. `app/helpers/blogs_helper.rb` guard-clause short-circuits when `toc_enabled?` is false, else calls `Blog::TableOfContents.call(...).to_html.html_safe`. `Blog::ALLOWED_ATTRIBUTES` (app/models/blog.rb:8) contains no `"id"`. `spec/requests/blogs_toc_spec.rb` asserts literal `<h2 id="toc-intro">`, `<h3 id="toc-detail">`, `<h2 id="toc-intro-2">` in `response.body`, and `<h1>`/`<h4>` with no id — ran live and passed |
| 3 | Every post carries `toc_enabled` boolean default false and `toc_overrides` jsonb store, no backfill; existing rows' `body`, `updated_at`, `seo_description`, `.md` export, `api/v1/blogs/show.json` all byte-for-byte unchanged | ✓ VERIFIED | `db/schema.rb:141-142` shows both columns with correct defaults. Migration (`db/migrate/20260802120004_add_toc_fields_to_blogs.rb`) contains only two `add_column` calls, no backfill. Live DB check: `Blog.where(toc_enabled: false).count == Blog.count` → `true`; `Blog.first.toc_overrides` → `{}`. `spec/requests/blogs_toc_spec.rb` asserts `.md` export and JSON API `content_html` exactly equal `blog.reload.body` with no `toc-`/`id=` leakage — ran live and passed |
| 4 | A golden-master request spec captures current HTML of a TOC-off blog show page and passes; a later regression fails CI | ✓ VERIFIED | `spec/requests/blogs_golden_master_spec.rb` + 10 committed baselines under `spec/fixtures/golden_master/`. Ran live: 15/15 passing. **Sensitivity spot-check performed:** injected a single extra space into the `div.prose` wrapper in `show.html.erb` — 10/15 examples failed immediately; reverted, confirmed clean `git diff` and 15/15 green again |

**Score:** 4/4 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `db/migrate/20260802120004_add_toc_fields_to_blogs.rb` | Additive schema change, no backfill | ✓ VERIFIED | Exactly two `add_column` calls, no index/backfill |
| `db/schema.rb` | Both new columns present | ✓ VERIFIED | `t.boolean "toc_enabled", default: false, null: false` / `t.jsonb "toc_overrides", default: {}, null: false` present; index list unchanged |
| `app/controllers/admin/blogs_controller.rb` | `toc_enabled` in permitted params, `toc_overrides` excluded | ✓ VERIFIED | `blog_params` permits `toc_enabled`; grep confirms `toc_overrides` absent from strong params and no reference in public `blogs_controller.rb`/`app/controllers/api` |
| `app/models/blog/table_of_contents.rb` | `Blog::TableOfContents` PORO | ✓ VERIFIED | 76 lines, `Nokogiri::HTML5.fragment`, single parse/traversal, used-set probe, D-08 label sanitize |
| `spec/models/blog/table_of_contents_spec.rb` | Pure unit spec | ✓ VERIFIED | No `create`/`build`/FactoryBot; covers all required cases |
| `app/helpers/blogs_helper.rb` | TOC-off short-circuit + anchor injection | ✓ VERIFIED | Guard clause returns caller's SafeBuffer untouched; `.html_safe` used once, no `raw` |
| `app/views/blogs/show.html.erb` | Injection wired downstream of sanitizer | ✓ VERIFIED | Line 76 wraps `sanitize(...)` inside `blog_body_with_toc_anchors`; wrapper div byte-identical |
| `spec/support/golden_master.rb` | Volatility normalization + compare/regenerate | ✓ VERIFIED | `NORMALIZERS`, `article_region`, `match_golden!` (skip on `UPDATE_GOLDEN`, never a false pass) |
| `spec/requests/blogs_golden_master_spec.rb` | LAYOUT-04 CI gate | ✓ VERIFIED | 15 examples over 5 fixtures, live-run green, sensitivity confirmed by direct byte-injection test |
| `spec/fixtures/golden_master/*.html` | 10 committed baselines | ✓ VERIFIED | Exactly 10 files present, none contain `id="toc-` |
| `spec/requests/blogs_toc_spec.rb` | Rendered-response assertions | ✓ VERIFIED | 10 examples: anchor injection, TOC-off zero-injection, non-mutation of body/.md/JSON/seo_description, Article STI coverage |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `admin/blogs_controller.rb` | `blogs.toc_enabled` | `blog_params` permitted list | ✓ WIRED | `permitted = %i[... toc_enabled]` confirmed by grep |
| `Blog::ALLOWED_ATTRIBUTES` | `blogs.body` | `before_save :sanitize_body` strips `id` | ✓ WIRED | Confirmed constant excludes `"id"`; spec asserts submitted `id="evil"` never persists |
| `blogs/show.html.erb` | `BlogsHelper#blog_body_with_toc_anchors` | wraps existing `sanitize` call | ✓ WIRED | Live code inspection confirms exact wiring |
| `blogs_helper.rb` | `Blog::TableOfContents` | `.call` on already-sanitized string | ✓ WIRED | Confirmed in source |
| `blogs_golden_master_spec.rb` | `spec/fixtures/golden_master/*.html` | `match_golden!` read-and-compare | ✓ WIRED | Live run green; byte-injection sensitivity test confirms real comparison, not a tautology |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full targeted spec suite (models, PORO, golden-master, toc request spec) | `bundle exec rspec spec/models/blog_spec.rb spec/models/blog/table_of_contents_spec.rb spec/requests/blogs_golden_master_spec.rb spec/requests/blogs_toc_spec.rb` | 79 examples, 0 failures | ✓ PASS |
| Full repo suite | `bundle exec rspec` | 152 passed, 5 pending (pre-existing, unrelated) | ✓ PASS |
| Rubocop on all phase-touched files | `bundle exec rubocop <9 files>` | 0 offenses | ✓ PASS |
| Golden-master gate genuinely detects a 1-byte regression | injected extra space into `div.prose` wrapper, ran golden-master spec, reverted | 10/15 failed while injected; 15/15 after revert | ✓ PASS |
| Zero-backfill invariant on live dev DB | `bin/rails runner 'Blog.where(toc_enabled: false).count == Blog.count'` | `true` | ✓ PASS |
| `toc_overrides` default on live dev DB | `bin/rails runner 'Blog.first.toc_overrides'` | `{}` | ✓ PASS |
| Public write-path leak check | `grep -rn "toc_enabled\|toc_overrides" app/controllers/blogs_controller.rb app/controllers/api` | no matches | ✓ PASS |
| No debt markers in phase-touched files | `grep -n TBD\|FIXME\|XXX\|TODO\|HACK\|PLACEHOLDER` across 12 files | no matches | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|--------------|--------|----------|
| TOC-01 | 01-01 | Admin can toggle TOC on/off per post (Blog + Article STI), default OFF | ✓ SATISFIED (data-model half) | `toc_enabled` column defaults false, inherited by `Article` STI, writable only via `Admin::BlogsController` strong params. Note: the visible admin-form checkbox is explicitly Phase 4's success criterion 1 (ADMIN-01) per ROADMAP.md — Phase 1's own success criteria only require the column + write seam, which are both present |
| TOC-02 | 01-02 | TOC entries auto-generate from H2/H3 in sanitized body HTML (H1, H4-H6 excluded) | ✓ SATISFIED | `Blog::TableOfContents` selector `"h2, h3"`; spec proves H1/H4/H6 produce no entries and no ids |
| TOC-03 | 01-02, 01-04 | Stable unique `toc-` anchor per heading, dedup, positional fallback, injected at render time, never added to sanitizer allowlist | ✓ SATISFIED | Anchor allocation algorithm + render-time injection both verified live; `ALLOWED_ATTRIBUTES` unchanged |
| LAYOUT-04 | 01-03, 01-04 | Existing/TOC-off posts render with zero regression, verified by golden-master test | ✓ SATISFIED | 10 baselines, 15 examples, live sensitivity check confirms real byte-level protection |

No orphaned requirements — REQUIREMENTS.md maps exactly TOC-01, TOC-02, TOC-03, LAYOUT-04 to Phase 1, and all four appear in plan frontmatter `requirements:` fields across 01-01 through 01-04.

### Anti-Patterns Found

None. Scanned all 12 phase-touched files (migration, schema, admin controller, blog model spec, PORO, PORO spec, Gemfile, golden-master support module, golden-master spec, blogs helper, show view, toc request spec) for `TBD|FIXME|XXX|TODO|HACK|PLACEHOLDER` and stub-shaped patterns (`return null`, `console.log`-only bodies, hardcoded empty return values reaching render) — zero matches. `raw` appears zero times in `app/`; `.html_safe` appears exactly once, justified by an inline `# SECURITY:` comment naming both enforcing specs.

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|---------------------|--------|
| `blogs/show.html.erb` | anchor-injected HTML | `blog_body_with_toc_anchors(@blog, sanitize(@blog.body, ...))` → `Blog::TableOfContents.call(...)` when `toc_enabled?` true, else the sanitizer's own object | Yes — live request spec confirms real anchors reach `response.body` for TOC-on fixtures and zero anchors for TOC-off fixtures | ✓ FLOWING |
| `blog_spec.rb` TOC column examples | `toc_enabled`/`toc_overrides` | `create(:blog).reload` reads live PostgreSQL row | Yes — confirmed against live dev DB via `bin/rails runner` | ✓ FLOWING |

### Human Verification Required

None. All must-haves are verifiable programmatically (model logic, rendered HTML byte comparisons, DB state) and were independently re-run against the live codebase and live dev database rather than trusting SUMMARY.md narration.

### Gaps Summary

No gaps found. All four ROADMAP success criteria for Phase 1 are independently verified against the live codebase:
- `Blog::TableOfContents` PORO derivation logic was inspected directly and its unit spec (15 examples) plus request spec (10 examples) were re-run live, all green.
- Render-time anchor injection was inspected directly at both the helper and view level, confirmed structurally downstream of the sanitizer, and confirmed live via request spec.
- The `toc_enabled`/`toc_overrides` columns, their defaults, the zero-backfill invariant, and the admin-only write seam were all confirmed against both source and the live dev database.
- The golden-master regression gate was not just observed to pass — it was adversarially tested by injecting a single byte into the protected region and confirming 10/15 examples immediately failed, then reverting and confirming a clean return to green. This is direct proof the gate is a real regression guard, not a tautology.

No admin-form UI toggle exists yet for `toc_enabled` — this is intentional and correctly scoped: ROADMAP.md's Phase 4 (Admin TOC Control) owns "The blog edit form shows a TOC on/off toggle" as its own success criterion. Phase 1's success criteria only require the column and the admin-authenticated write seam (strong params), both of which are present. Not treated as a gap.

---

*Verified: 2026-08-02T20:09:56Z*
*Verifier: Claude (gsd-verifier)*
