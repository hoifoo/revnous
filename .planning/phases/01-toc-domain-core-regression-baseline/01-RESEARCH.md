# Phase 1: TOC Domain Core & Regression Baseline - Research

**Researched:** 2026-08-02
**Domain:** Rails 8 server-side HTML post-processing (Nokogiri), slug generation, Rails migrations, characterization/golden-master request specs
**Confidence:** HIGH — nearly every claim below was verified by executing code against this repo's actual bundle (`bin/rails runner`, `bundle exec rspec`), not from training data.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**TOC Scope & Anchor Contract (locked in PROJECT.md / ROADMAP.md — carried forward, not re-discussed)**
- **D-01:** Only H2/H3 headings become TOC entries; H1 and H4–H6 are excluded (TOC-02). Legacy posts with only H1 content produce an empty TOC until rewritten — accepted, feature is opt-in.
- **D-02:** Every entry's anchor is `toc-` prefixed, unique within the post; duplicate headings dedupe with a counter suffix; headings that slugify to empty (emoji-only, CJK-only, punctuation-only) fall back to a positional `toc-section-N` anchor (TOC-03).
- **D-03:** Anchor `id`s are injected at render time, downstream of the last sanitizer pass (`app/views/blogs/show.html.erb`'s `sanitize @blog.body, tags: Blog::ALLOWED_TAGS, attributes: Blog::ALLOWED_ATTRIBUTES`). `Blog::ALLOWED_ATTRIBUTES` stays unchanged — `id` is never added to the sanitizer allowlist. This avoids a `body` backfill migration and avoids opening a DOM-clobbering surface via stored `id` attributes.
- **D-04:** Anchors are derived, not persisted/stable — if a heading's text changes later, its anchor changes too. Persisted rename-stable anchor mapping is explicitly deferred to v2 (TOCV2-03).
- **D-05:** `toc_enabled` defaults to `false`; `toc_overrides` is a `jsonb` column keyed by anchor (follows the `keywords` column jsonb precedent, not the `faq_schema` text-holding-JSON pattern). No backfill migration — existing rows must be byte-for-byte unchanged (`body`, `updated_at`, `seo_description`, `.md` export, `api/v1/blogs/show.json`).
- **D-06:** `Article < Blog` (STI) is in scope automatically — no special-casing needed.
- **D-07:** The golden-master spec is a request spec (not a system/visual test), capturing HTML of a TOC-off `/blog/:slug` response (LAYOUT-04).

**TOC Label Formatting**
- **D-08:** TOC sidebar entry labels preserve inline formatting from the heading (e.g., a heading `Getting <code>Started</code> Fast` produces a label that keeps the `<code>` styling), not plain-text-only extraction. The PORO's entry label field must carry sanitized inline markup (a safe subset — e.g. `code`, `em`, `strong` — consistent with `Blog::ALLOWED_TAGS`), not a plain string. Downstream (Phase 2) renders this label; Phase 1 just needs the data shape to support it.

**Golden-Master Baseline Scope**
- **D-09:** The golden-master spec uses a curated fixture set of 3–5 posts, not a single fixture and not a live sample of real published posts. Fixtures must cover: images, tables, an FAQ section, code blocks, and a minimal/near-empty body. Goal: catch regressions across the real markup surface (`Blog::ALLOWED_TAGS`) without coupling the spec to mutable seed/dev-DB data.

**Orphaned H3 Handling**
- **D-10:** An H3 that appears before any H2 in the body (no parent section) is still included in the TOC, flat — every H2/H3 in document order gets an entry regardless of nesting validity. No silent dropping of headings the author wrote. (This matches TOC-02's plain "H2/H3 headings" scope — no hierarchy-validity filter.)

### Claude's Discretion

- PORO class name/location, internal API shape (return value: array of value objects/structs vs hashes).
- HTML parsing library choice (Nokogiri is already available transitively via `Rails::Html::SafeListSanitizer`).
- Exact slugification algorithm (parameterize-based vs custom) and collision-suffix format (e.g. `toc-heading-2` vs `toc-heading--2`), as long as it satisfies D-02's uniqueness/dedup/fallback contract.
- Where in the render pipeline anchor injection happens (helper vs view concern) — must land after the existing sanitizer call per D-03.
- `toc_overrides` jsonb default value and whether an index on `toc_enabled` is warranted.
- Migration structure/order (single migration vs two).
- How to verify the noted blocker: "Tiptap StarterKit Heading dropping unknown `id` attributes on round-trip is unverified (MEDIUM confidence)" — quick manual/spec check during this phase, per STATE.md Blockers/Concerns.

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within Phase 1 scope. (Multi-page posts, gem extraction, and broader nav/discovery UX remain deferred at the project level per PROJECT.md Out of Scope — not raised again here.)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TOC-01 | Admin can toggle Table of Contents on/off per post (Blog and Article STI subtype), default OFF | Migration Patterns section — `add_column :blogs, :toc_enabled, :boolean, default: false, null: false` follows the verified in-repo `spacing`/`featured_on_home` precedent. **Phase 1 delivers the data-model half only**; the admin form control is ADMIN-01 / Phase 4 (per CONTEXT.md Phase Boundary). Strong-params addition in `Admin::BlogsController#blog_params` is the seam. |
| TOC-02 | TOC entries auto-generate from H2/H3 headings in the sanitized `body` HTML (H1, H4-H6 not included) | Pattern 1 (Parse-once fragment pipeline) — `fragment.css("h2, h3")` returns document-order H2/H3 only; verified against a mixed H1–H6 body in this repo's bundle. Also satisfies D-10 (orphaned H3s included, flat). |
| TOC-03 | Every listed heading gets a stable, unique anchor `id` (`toc-` prefixed, deduplicated on collision, safe positional fallback for headings that slugify to empty), injected at render time after sanitization — never added to the sanitizer's attribute allowlist | Pattern 2 (Anchor uniqueness via used-set probing) + Pitfall 2 (naive counter produces duplicates — **verified reproduction**) + Pitfall 1 (must use `Nokogiri::HTML5`, not HTML4, to preserve byte-fidelity downstream of the view sanitizer — **verified**). Verified that `parameterize` returns `""` for emoji / CJK / Cyrillic / punctuation-only text. |
| LAYOUT-04 | Existing published posts (and any post with TOC off) render with zero visual/layout regression, verified with a golden-master test | Pattern 4 (Two-layer golden master) + Pitfall 5 (four **verified** volatility sources in this app's response body: Propshaft asset digest, JSON-LD ISO timestamps, related-blogs ordering, `data-providers` JSON). Plus the TOC-off short-circuit (Pattern 3) which makes byte-identity structurally guaranteed rather than merely tested. |
</phase_requirements>

## Summary

This phase needs almost no new technology. Everything required — Nokogiri (1.18.10), `Rails::HTML5::SafeListSanitizer` (rails-html-sanitizer 1.6.2), `ActiveSupport::Inflector#parameterize`, jsonb columns, rspec-rails 7.1.1 — is already resolved in `Gemfile.lock` and exercised by this codebase today. **Zero new gems and zero new npm packages are recommended.** The entire risk surface is in getting three subtle details right, all of which were verified empirically in this repo during research.

**Detail 1 — the two sanitizer passes in this app use different HTML parsers, and only one of them round-trips byte-identically.** `Blog#sanitize_body` calls `Rails::Html::SafeListSanitizer.new`, which resolves to `Rails::HTML4::SafeListSanitizer` (libxml2). The view helper `sanitize` in `show.html.erb:76` resolves to `Rails::HTML5::SafeListSanitizer` (gumbo), because `config.load_defaults 8.0` sets `config.action_view.sanitizer_vendor = Rails::HTML::Sanitizer.best_supported_vendor`. These two produce *different* output for entity-bearing content (`&nbsp;` survives as an entity through HTML5, but is decoded to a literal U+00A0 by HTML4). Since D-03 places anchor injection *downstream of the view sanitizer*, the injection step must parse with `Nokogiri::HTML5.fragment` — verified byte-identical round-trip across an 11-case corpus spanning every tag in `Blog::ALLOWED_TAGS`. `Nokogiri::HTML4::DocumentFragment.parse` fails that round-trip on entities and images. Choosing the wrong parser silently corrupts existing posts and breaks LAYOUT-04.

**Detail 2 — the obvious dedup algorithm is broken.** A `Hash.new(0)` counter keyed on the slug base produces duplicate anchors in a reproducible real-world case (headings `Getting Started`, `Getting Started`, `Getting Started 2` → `toc-getting-started-2` twice). Verified failing. The correct algorithm keeps a set of *already-issued final anchors* and probes upward until free.

**Detail 3 — a naive full-page golden master will be flaky and will produce false failures during Phase 2.** The `/blog/:slug` response contains a Propshaft asset digest (`/assets/application-a812b469.css`) that changes on every Tailwind rebuild, ISO-8601 timestamps in JSON-LD derived from `published_at`/`updated_at`, a related-articles block whose contents depend on which other posts exist, and a cookie-consent `data-providers` JSON blob read from `config/analytics_providers.json`. All four were observed in an actual test-env response during research.

**Primary recommendation:** Add a `Blog::TableOfContents` PORO that takes an already-view-sanitized HTML string, parses it **once** with `Nokogiri::HTML5.fragment`, and returns both the entry list *and* the id-injected HTML from that single parse — then short-circuit and return the original `SafeBuffer` untouched when `toc_enabled` is false, so TOC-off byte-identity is structural, not merely asserted.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Derive ordered H2/H3 entries + anchors from body HTML | Domain (PORO under `app/models/blog/`) | — | Pure function of an HTML string; no DB, no request, no view. Must be unit-testable without a request cycle. Belongs to the `Blog` domain, not to a helper. |
| Inject `id=` into rendered headings | Frontend Server (view helper, `BlogsHelper`) | Domain (reuses the PORO's parse) | D-03 pins this downstream of the view `sanitize` call. It is a *rendering* concern — the value never reaches the DB or the JSON API. `app/helpers/blogs_helper.rb` is currently empty and is the natural home. |
| `toc_enabled` / `toc_overrides` persistence | Database / Storage | Domain (`Blog` model) | Plain ActiveRecord columns; STI (`Article < Blog`) inherits them for free. |
| Sanitization of body HTML | Domain (`Blog#sanitize_body`) + Frontend Server (view `sanitize`) | — | **Unchanged this phase.** Both passes stay exactly as they are; anchor injection is a *third*, separate step. Do not merge or refactor these. |
| Zero-regression guarantee for TOC-off pages | Test tier (request spec) | Frontend Server (short-circuit) | LAYOUT-04 is a CI gate. The short-circuit in the helper is the mechanism; the request spec is the proof. |
| TOC-off short-circuit decision | Frontend Server (view/helper) | — | `@blog.toc_enabled?` gates the entire injection path. Not a model concern — a TOC-off blog still has derivable entries (Phase 4 admin preview will need them). |
| Anchor scroll targets / sidebar / scroll-spy | **Out of scope** (Phases 2–3) | — | Browser/client tier. Explicitly excluded by CONTEXT.md Phase Boundary. |

## Project Constraints (from CLAUDE.md)

Extracted directives the planner must honor:

| Directive | Source | Impact on this phase |
|-----------|--------|----------------------|
| Rails/Stimulus/esbuild only — no React/Vue | CLAUDE.md Constraints | No JS at all is needed in Phase 1. Do not add any. |
| TOC strictly opt-in, default off; existing posts render identically | CLAUDE.md Constraints | Drives the short-circuit design (Pattern 3) and LAYOUT-04. |
| No new editor storage format; TOC reads existing sanitized `body` column | CLAUDE.md Constraints | No `body` migration, no ActionText change, no new column for content. |
| Scope discipline — gem extraction and multi-page posts are parked | CLAUDE.md Constraints | Do not generalize the PORO into an engine/gem shape. Keep it `Blog`-specific. |
| Rubocop `rails-omakase` style | CLAUDE.md Code Style, `.rubocop.yml` | 2-space indent; run `bundle exec rubocop` on new files. |
| Brakeman is in the dev/test bundle | CLAUDE.md Key Dependencies | Any `.html_safe` / `raw` call added will be flagged. See Security Domain below for the required handling. |
| Models: `before_save` callbacks for normalization; private methods grouped at bottom | CLAUDE.md Conventions | `toc_overrides` normalization (if added) follows the `normalize_keywords` shape. |
| Controllers: strong params via a private `*_params` method | CLAUDE.md Conventions | `toc_enabled` / `toc_overrides` permitting lands in `Admin::BlogsController#blog_params`. |
| FactoryBot + `let` blocks + RSpec; no explicit teardown | CLAUDE.md Testing Conventions | Golden-master fixtures should be FactoryBot-built, not Rails fixtures. |
| **GSD Workflow Enforcement** — no direct repo edits outside a GSD workflow | CLAUDE.md | Applies to execution, not to this research. |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Nokogiri | 1.18.10 | Parse the view-sanitized HTML fragment; select H2/H3; set `id` attributes; re-serialize | Already resolved in `Gemfile.lock` (transitively, via `loofah` → `rails-html-sanitizer`). `Nokogiri::HTML5` is present and functional — verified `defined?(Nokogiri::HTML5) # => "constant"` under `bin/rails runner`. [VERIFIED: `bin/rails runner` in this repo] |
| `Nokogiri::HTML5.fragment` | (Nokogiri 1.18.10) | The **specific** parse entry point for injection | Only parser verified to round-trip this app's view-sanitizer output byte-for-byte. See Pitfall 1. [VERIFIED: 11-case corpus executed in this repo] |
| `ActiveSupport::Inflector#parameterize` | Rails 8.0.3 | Slugify heading text into the anchor base | Already the repo's slug convention — `Blog#generate_slug` uses `title.parameterize`. Consistency beats novelty. [VERIFIED: `app/models/blog.rb:88`] |
| `Rails::HTML5::SafeListSanitizer` (via view `sanitize` helper) | rails-html-sanitizer 1.6.2 | Existing sanitization — **unchanged** | Already in place at `show.html.erb:76`. Phase 1 adds nothing to it. [VERIFIED: `ActionView::Base.safe_list_sanitizer # => #<Rails::HTML5::SafeListSanitizer>`] |
| rspec-rails | 7.1.1 | Request spec for the golden master | Repo's existing test framework; `spec/requests/blogs_spec.rb` already contains passing `type: :request` blog show specs. [VERIFIED: `bundle exec rspec spec/requests/blogs_spec.rb` → 11 passed] |
| factory_bot_rails | 6.5.1 | Golden-master fixture posts | `spec/factories/blogs.rb` already exists with a `:blog` factory. [VERIFIED: file read] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| PostgreSQL `jsonb` | pg 1.6.2 / PG server | `toc_overrides` storage | Follows the verified in-repo precedent: `t.jsonb "keywords", default: [], null: false`. [VERIFIED: `db/schema.rb`] |
| `ActiveSupport::SafeBuffer` / `#html_safe` | Rails 8.0.3 | Return the injected HTML to the view without double-escaping | Required because Nokogiri's `to_html` returns a plain `String`. See Security Domain for the Brakeman handling. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `Nokogiri::HTML5.fragment` | `Nokogiri::HTML4::DocumentFragment.parse` | **Rejected.** Verified to *not* round-trip this app's view-sanitizer output — it decodes `&nbsp;`/`&mdash;` to literal characters, changing bytes on every entity-bearing post. Directly violates LAYOUT-04. |
| `Nokogiri::HTML5.fragment` | Regex `gsub` over `<h2...>` / `<h3...>` | **Rejected.** Classic HTML-with-regex failure: breaks on attributes, on `<h2>` text containing `>`, and on nested inline tags. Also can't extract `inner_html` for D-08 labels. |
| `parameterize` | `stringex` gem's `to_url` (adds transliteration for Cyrillic/Greek) | **Rejected for v1.** Adds a gem to solve a case D-02 already handles via the `toc-section-N` fallback. Would also make anchors diverge from the repo's existing `title.parameterize` slug convention. Revisit only if non-Latin posts become common. |
| Hand-rolled golden master | `rspec-snapshot` (2.2.0) / `approvals` (0.1.7) gems | **Rejected.** Both exist on rubygems.org [VERIFIED: `gem list -r`], but neither solves this phase's actual hard part (volatility normalization — Pitfall 5), and both add a dependency for ~25 lines of comparison logic. Also both are `[ASSUMED]` by this research's provenance rule — discovered from ecosystem knowledge, not official Rails docs. |
| Adding `gem "nokogiri"` to `Gemfile` | Relying on the transitive resolution | Either is defensible. `require "nokogiri"` and `Nokogiri::HTML5` already work without a Gemfile change [VERIFIED: probe scripts ran successfully]. Declaring it explicitly documents the direct dependency and pins it against a future `rails-html-sanitizer` that drops it. **Recommendation: declare it**, since this phase makes Nokogiri a first-class application dependency rather than an implementation detail of a gem. |
| Injecting `id` in `Blog#sanitize_body` (persisted) | — | **Rejected by D-03/CONTEXT.md.** Would require a `body` backfill (violating D-05's byte-identity requirement), would change `seo_description`, `.md` export, and `api/v1/blogs/show.json`, and would add `id` to the sanitizer allowlist (DOM-clobbering surface). |

**Installation:**

```bash
# Nothing required. Optionally, to declare the now-direct dependency:
#   Gemfile:  gem "nokogiri"
#   then:     bundle install    # resolves to the already-locked 1.18.10, no lockfile churn expected
```

**Version verification performed:**

```
Nokogiri::VERSION                    => 1.18.10          [VERIFIED: bundle exec ruby]
Rails::HTML::Sanitizer VERSION       => 1.6.2            [VERIFIED: bundle exec ruby]
Rails                                => 8.0.3            [VERIFIED: Gemfile.lock]
loofah                               => 2.24.1           [VERIFIED: Gemfile.lock]
rspec-rails                          => 7.1.1            [VERIFIED: Gemfile.lock]
capybara                             => 3.40.0           [VERIFIED: Gemfile.lock]
factory_bot_rails                    => 6.5.1            [VERIFIED: Gemfile.lock]
```

## Package Legitimacy Audit

**This phase installs no external packages.** No npm packages, no new gems required. The only optional change is promoting `nokogiri` from a transitive to a declared dependency — the same already-locked, already-installed version.

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| nokogiri (1.18.10) | rubygems | 17+ yrs | ~1B total | github.com/sparklemotion/nokogiri | n/a (already in `Gemfile.lock`, installed, and loaded by Rails itself) | Approved — already present, optional Gemfile declaration only |

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

*slopcheck was not run because no package is being newly introduced from any registry. Nokogiri is already resolved in the committed `Gemfile.lock` and is loaded on every boot as a dependency of `rails-html-sanitizer` — its legitimacy is established by the existing, working application, not by a registry lookup.*

## Architecture Patterns

### System Architecture Diagram

```
                              ADMIN WRITE PATH (unchanged this phase)
  Admin form ──> Admin::BlogsController#update ──> Blog#save
                                                     │
                                        before_save :sanitize_body
                                        Rails::HTML4::SafeListSanitizer
                                        (ALLOWED_TAGS / ALLOWED_ATTRIBUTES)
                                        ── strips `id` — VERIFIED ──
                                                     │
                                                     ▼
                                          blogs.body (text column)
                                          ── never contains id= ──
                                                     │
        ┌────────────────────────────────────────────┼────────────────────────────────┐
        │                                            │                                │
        ▼                                            ▼                                ▼
  api/v1/blogs/show.json                     BlogsController#show                BlogsController
  json.content_html @blog.body                    format.html                    format.md
  ── UNCHANGED ──                                     │                          strip_tags(@blog.body)
                                                      │                          ── UNCHANGED ──
                                                      ▼
                                        app/views/blogs/show.html.erb:76
                                        sanitize @blog.body,
                                          tags: Blog::ALLOWED_TAGS,
                                          attributes: Blog::ALLOWED_ATTRIBUTES
                                        │  (Rails::HTML5::SafeListSanitizer —
                                        │   set by load_defaults 8.0)
                                        │
                                        ▼  SafeBuffer, entity-preserving
                              ┌─────────────────────────────┐
                              │  NEW: toc_anchored(...)     │
                              │  helper                     │
                              │                             │
                              │  @blog.toc_enabled? ────No──┼──> return input UNCHANGED
                              │        │                    │     (byte-identity is structural)
                              │       Yes                   │
                              │        ▼                    │
                              │  Nokogiri::HTML5.fragment   │
                              │        │                    │
                              │        ▼                    │
                              │  Blog::TableOfContents      │
                              │   .call(fragment)           │
                              │   ├─ css("h2, h3")          │
                              │   ├─ slugify + dedupe       │
                              │   ├─ node["id"] = anchor    │  ◄── mutates fragment in place
                              │   └─ collect Entry structs  │      (level, anchor, label_html, text)
                              │        │                    │
                              │        ▼                    │
                              │  fragment.to_html           │
                              │    .html_safe               │
                              └─────────────────────────────┘
                                        │              │
                        rendered <h2 id="toc-...">     └──> entries (unused in Phase 1;
                        into the response HTML                consumed by Phase 2 sidebar
                                                              and Phase 4 admin UI)
```

**Key property the diagram encodes:** the `.md` export, the JSON API, and `seo_description` all branch off `@blog.body` *upstream* of the injection point, so D-05's byte-identity requirement holds by construction, not by test.

### Recommended Project Structure

```
app/
├── models/
│   ├── blog.rb                          # + toc_enabled / toc_overrides awareness (minimal)
│   └── blog/
│       └── table_of_contents.rb         # NEW — PORO, Zeitwerk resolves as Blog::TableOfContents
├── helpers/
│   └── blogs_helper.rb                  # NEW body — currently `module BlogsHelper; end` (empty)
└── views/
    └── blogs/
        └── show.html.erb                # line 76 — wrap the existing sanitize call

db/migrate/
└── 2026XXXXXXXXXX_add_toc_fields_to_blogs.rb   # NEW — one migration, two add_column calls

spec/
├── models/
│   └── blog/
│       └── table_of_contents_spec.rb    # NEW — pure unit tests, no DB, no request
├── requests/
│   ├── blogs_spec.rb                    # existing — leave alone
│   └── blogs_golden_master_spec.rb      # NEW — LAYOUT-04
├── fixtures/
│   └── golden_master/                   # NEW — committed .html baselines
│       ├── images_post.html
│       ├── tables_post.html
│       ├── faq_post.html
│       ├── code_post.html
│       └── minimal_post.html
└── support/
    └── golden_master.rb                 # NEW — helper: normalize + compare + UPDATE_GOLDEN write
```

Note: `app/models/blog/table_of_contents.rb` works with Zeitwerk because `Blog` is a class in `app/models/blog.rb`; Rails autoloads the nested directory as namespaced constants under it. This is the standard Rails 8 pattern for model-adjacent POROs and keeps the class out of a bare `app/services/` grab bag.

### Pattern 1: Parse once, return both outputs

**What:** The PORO receives (or builds) a single `Nokogiri::HTML5::DocumentFragment`, mutates heading nodes in place, and exposes both the entry list and the mutated fragment. The caller serializes.

**When to use:** Always. Parsing twice (once to extract entries, once to inject ids) risks the two passes disagreeing on anchor assignment and doubles the parse cost on every page view.

**Example:**

```ruby
# app/models/blog/table_of_contents.rb
# Verified working against this repo's bundle (bin/rails runner, 2026-08-02).
class Blog
  class TableOfContents
    HEADING_SELECTOR = "h2, h3".freeze
    ANCHOR_PREFIX    = "toc-".freeze
    MAX_SLUG_LENGTH  = 80

    # Inline tags permitted inside a TOC entry label (D-08).
    # Deliberately a strict subset of Blog::ALLOWED_TAGS.
    LABEL_TAGS       = %w[strong em code a br].freeze
    LABEL_ATTRIBUTES = %w[href].freeze

    Entry = Struct.new(:level, :anchor, :label_html, :text, keyword_init: true)

    attr_reader :fragment, :entries

    # sanitized_html: output of the view-level `sanitize` helper (already a
    # SafeBuffer). MUST be parsed with HTML5 to preserve byte-fidelity — see
    # Pitfall 1.
    def self.call(sanitized_html)
      new(Nokogiri::HTML5.fragment(sanitized_html.to_s)).tap(&:derive!)
    end

    def initialize(fragment)
      @fragment = fragment
      @entries  = []
    end

    def derive!
      used = {}

      fragment.css(HEADING_SELECTOR).each_with_index do |node, index|
        anchor = allocate_anchor(base_slug(node, index), used)
        node["id"] = anchor

        entries << Entry.new(
          level:      node.name[1].to_i,
          anchor:     anchor,
          label_html: sanitized_label(node),
          text:       node.text.strip
        )
      end

      self
    end

    def to_html = fragment.to_html

    private

    def base_slug(node, index)
      slug = node.text.parameterize
      return "section-#{index + 1}" if slug.blank?   # D-02 positional fallback

      slug.first(MAX_SLUG_LENGTH).sub(/-\z/, "")
    end

    # See Pitfall 2: a plain Hash.new(0) counter produces DUPLICATE anchors.
    def allocate_anchor(base, used)
      candidate = "#{ANCHOR_PREFIX}#{base}"
      counter   = 1

      while used.key?(candidate)
        counter += 1
        candidate = "#{ANCHOR_PREFIX}#{base}-#{counter}"
      end

      used[candidate] = true
      candidate
    end

    def sanitized_label(node)
      ActionController::Base.helpers.sanitize(
        node.inner_html, tags: LABEL_TAGS, attributes: LABEL_ATTRIBUTES
      )
    end
  end
end
```

Verified output for a mixed body (H1 + H2/H3 + H4 + duplicates + emoji + CJK + accents):

```
L2 toc-getting-started-fast     label="Getting <code>Started</code> Fast"   # D-08 preserved
L3 toc-orphan-after             label="Orphan-after"                        # D-10: orphan H3 kept
L2 toc-getting-started          label="Getting Started"
L2 toc-getting-started-2        label="Getting Started"                     # D-02 dedup
L2 toc-getting-started-fast-2   label="Getting Started Fast"
L2 toc-section-6                label="🚀"                                  # D-02 fallback
L2 toc-section-7                label="日本語"                              # D-02 fallback
L3 toc-section-8                label="!!!"                                 # D-02 fallback
L2 toc-cafe-creme               label="Café &amp; Crème"
# H1 and H4 correctly received no id and no entry.
```

### Pattern 2: Anchor uniqueness via a used-set probe, not a per-base counter

**What:** Track *issued final anchors*, not base-slug occurrence counts. On collision, increment and re-probe until free.

**When to use:** Always. See Pitfall 2 for the verified failure of the alternative.

### Pattern 3: Short-circuit when TOC is off — make byte-identity structural

**What:** When `toc_enabled` is false, return the sanitizer's `SafeBuffer` untouched. Never parse, never re-serialize.

**When to use:** Always. This is what turns LAYOUT-04 from "we hope the round-trip is lossless" into "the string is literally the same object."

**Example:**

```ruby
# app/helpers/blogs_helper.rb  (file currently contains only `module BlogsHelper\nend`)
module BlogsHelper
  # Renders a blog body with TOC anchor ids injected, when the post opts in.
  #
  # SECURITY: `sanitized_html` is already the output of the view-level
  # `sanitize` helper (Rails::HTML5::SafeListSanitizer, Blog::ALLOWED_TAGS /
  # Blog::ALLOWED_ATTRIBUTES). This method only ADDS `id` attributes to h2/h3
  # nodes with values derived from Nokogiri-escaped slugs — it never
  # reintroduces user markup and never widens the allowlist. `html_safe` is
  # therefore justified. See spec/requests/blogs_golden_master_spec.rb.
  def blog_body_with_toc_anchors(blog, sanitized_html)
    return sanitized_html unless blog.toc_enabled?

    Blog::TableOfContents.call(sanitized_html).to_html.html_safe
  end
end
```

```erb
<%# app/views/blogs/show.html.erb — replaces line 76. Note the existing %>
<%# sanitize call is preserved verbatim; injection wraps it. %>
<%= blog_body_with_toc_anchors(
      @blog,
      sanitize(@blog.body, tags: Blog::ALLOWED_TAGS, attributes: Blog::ALLOWED_ATTRIBUTES)
    ) %>
```

### Pattern 4: Two-layer golden master with explicit volatility normalization

**What:** Layer A snapshots only the article content region byte-for-byte. Layer B snapshots the full page with volatile substrings scrubbed.

**When to use:** LAYOUT-04. Layer A is the tight regression gate on what this feature actually touches; Layer B catches wrapper/layout regressions from Phase 2 without failing every time Tailwind rebuilds.

**Example:**

```ruby
# spec/support/golden_master.rb
module GoldenMaster
  DIR = Rails.root.join("spec/fixtures/golden_master")

  # Verified volatility sources in this app's /blog/:slug response (2026-08-02):
  #   1. Propshaft asset digest      /assets/application-a812b469.css
  #   2. ISO-8601 timestamps in JSON-LD  2026-08-01T11:26:07...
  #   3. absolute host in share/canonical URLs
  NORMALIZERS = [
    [ %r{/assets/([\w\-]+?)-[0-9a-f]{8,}\.(css|js)}, '/assets/\1-DIGEST.\2' ],
    [ /\d{4}-\d{2}-\d{2}T[\d:]{8}(?:\.\d+)?(?:Z|[+\-]\d{2}:\d{2})?/, "TIMESTAMP" ],
    [ %r{http://www\.example\.com}, "HOST" ]
  ].freeze

  def normalize_html(html)
    NORMALIZERS.reduce(html.dup) { |acc, (re, sub)| acc.gsub(re, sub) }
  end

  # Layer A: article content region only — no asset digests, no timestamps.
  def article_region(html)
    Nokogiri::HTML5(html).at_css("div.prose").to_html
  end

  def match_golden!(name, actual)
    path = DIR.join("#{name}.html")

    if ENV["UPDATE_GOLDEN"]
      FileUtils.mkdir_p(DIR)
      path.write(actual)
      skip "golden master #{name} regenerated — rerun without UPDATE_GOLDEN"
    end

    raise "Missing golden master #{path}. Run with UPDATE_GOLDEN=1." unless path.exist?

    expect(actual).to eq(path.read)
  end
end

RSpec.configure { |c| c.include GoldenMaster, type: :request }
```

```ruby
# spec/requests/blogs_golden_master_spec.rb
require "rails_helper"

RSpec.describe "Blog show golden master (LAYOUT-04)", type: :request do
  # Timestamps MUST be absolute, not relative — `1.day.ago` changes the
  # JSON-LD datePublished on every run. Distinct values also pin the
  # related-articles ordering (published scope orders by published_at DESC).
  BASE_TIME = Time.utc(2026, 1, 15, 10, 0, 0)

  FIXTURES = {
    "images_post"  => '<h2>Gallery</h2><figure><img src="/a.png" alt="A&nbsp;B" width="640"><figcaption>Cap &mdash; here</figcaption></figure><p>After</p>',
    "tables_post"  => '<h2>Data</h2><table><colgroup><col width="50"></colgroup><thead><tr><th scope="col">A &amp; B</th></tr></thead><tbody><tr><td rowspan="2">x</td></tr></tbody><tfoot><tr><td>f</td></tr></tfoot></table>',
    "code_post"    => "<h2>Usage</h2><pre><code>a &lt; b &amp;&amp; c &gt; d\n  indent\n</code></pre><p>inline <code>x = 1</code></p>",
    "faq_post"     => "<h2>Overview</h2><p>Intro &hellip; text.</p><h3>Detail</h3><p>More.</p>",
    "minimal_post" => "<p>Just a sentence.</p>"
  }.freeze

  before do
    FIXTURES.each_with_index do |(slug, body), i|
      attrs = { slug: slug, title: slug.titleize, body: body,
                published_at: BASE_TIME - i.days, toc_enabled: false }
      # faq_post also exercises the FAQ section + FAQPage JSON-LD branch (D-09)
      blog = create(:blog, **attrs)
      blog.update_column(:faq_schema, '[{"question":"Q?","answer":"A."}]') if slug == "faq_post"
    end
  end

  FIXTURES.each_key do |slug|
    describe "GET /blog/#{slug} with toc_enabled: false" do
      before { get blog_path(slug) }

      it "renders the article region byte-for-byte identically to the baseline" do
        expect(response).to have_http_status(:ok)
        match_golden!("#{slug}.article", article_region(response.body))
      end

      it "renders the full page identically to the baseline (volatility normalized)" do
        match_golden!("#{slug}.page", normalize_html(response.body))
      end

      it "emits no toc- anchor ids at all" do
        expect(response.body).not_to include("id=\"toc-")
      end
    end
  end
end
```

### Anti-Patterns to Avoid

- **Adding `id` to `Blog::ALLOWED_ATTRIBUTES`** — explicitly forbidden by D-03. Beyond violating the decision, it lets an author persist arbitrary `id` values into `body`, which is a DOM-clobbering vector (a persisted `<h2 id="body">` shadows `document.body` in older engines and can break Phase 3's scroll-spy `getElementById` lookups). Also would require a body backfill, breaking D-05.
- **Injecting ids inside `Blog#sanitize_body`** — persists them, changing `body`, `seo_description`, `.md` export, and `api/v1/blogs/show.json`. Directly violates D-05's byte-identity requirement.
- **Reusing `Rails::Html::SafeListSanitizer` for the injection parse** — that constant is the HTML4 variant (see Pitfall 1); it is the wrong parser for content produced by the HTML5 view sanitizer.
- **Calling `sanitize` a third time after injection** — would strip the `id` you just added (it's not in `ALLOWED_ATTRIBUTES`). The whole point of D-03 is that injection is the *last* transformation.
- **Deriving entries from `@blog.body` (the raw column) while injecting into the view-sanitized string** — the two strings differ (HTML4 vs HTML5 output — verified). Anchors would be assigned against one DOM and injected into another. Always derive from the same fragment you inject into.
- **`raw` instead of `.html_safe`** — functionally similar here but `raw` reads as "trust arbitrary input" to reviewers and Brakeman. `.html_safe` on a string you just produced from a sanitized fragment, with an adjacent justification comment, is the clearer signal.
- **Backfilling `toc_enabled` in the migration** — `add_column` with `default: false, null: false` already gives every existing row `false` without an `UPDATE`; Rails 8 / PG 11+ use a non-rewriting default. Writing an explicit `Blog.update_all` would bump `updated_at` if done via ActiveRecord and violates D-05.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Finding H2/H3 in HTML | Regex over `<h[23][^>]*>` | `Nokogiri::HTML5.fragment(...).css("h2, h3")` | Regex breaks on attributes, on `>` inside attribute values, on nested inline tags, and can't give you `inner_html` for D-08 labels. |
| Re-serializing HTML after mutation | String splicing / `gsub` at offsets | `fragment.to_html` | Verified byte-identical for this app's sanitizer output; string splicing silently corrupts on multi-byte characters (this repo's posts contain emoji and CJK in headings per the test corpus). |
| Slug generation | Custom `downcase.gsub(/\W+/, "-")` | `String#parameterize` | Handles Latin-1/Latin-Extended transliteration (`Café` → `cafe`), collapses runs, strips leading/trailing separators — all verified. And it matches the repo's existing `Blog#generate_slug`. |
| Anchor uniqueness | `Hash.new(0)` occurrence counter | Used-set probe loop (Pattern 2) | The counter approach produces **verified duplicate anchors**. See Pitfall 2. |
| HTML sanitization | Any new sanitizer config | The two existing passes, unchanged | They already work and are already tested. Phase 1 adds a *third*, non-sanitizing step. |
| Golden-master comparison + regeneration | An approval-testing gem | ~25 lines in `spec/support/golden_master.rb` | The gems don't solve volatility normalization (the actual hard part here), and a new dependency for file-read-and-compare is not warranted. |
| Boolean/jsonb column defaults | Data migration / backfill script | `add_column ..., default:, null: false` | PG 11+ and Rails 8 apply column defaults to existing rows without a table rewrite or an `UPDATE`, so `updated_at` is untouched — exactly what D-05 requires. |

**Key insight:** The single highest-value thing this phase can do is *not add anything to the sanitization pipeline*. Every regression risk in LAYOUT-04 traces to touching that pipeline. Injection is a strictly additive, downstream, gated step — and when the gate is closed (TOC off), it is a no-op that returns the identical object.

## Common Pitfalls

### Pitfall 1: Using the wrong Nokogiri parser — silent byte-level corruption of every entity-bearing post

**What goes wrong:** You parse the view-sanitized HTML with `Nokogiri::HTML4::DocumentFragment.parse` (or with `Rails::Html::SafeListSanitizer`'s implicit HTML4 parser) and re-serialize. Entities like `&nbsp;`, `&mdash;`, `&hellip;`, `&copy;`, `&rsquo;` are decoded to literal characters. The page still *looks* right in a browser, but the response bytes changed — LAYOUT-04's golden master fails, or worse, passes because the baseline was captured after the bug was introduced.

**Why it happens:** This app has **two sanitizer passes using two different parsers**, which is genuinely surprising:

```
Blog#sanitize_body → Rails::Html::SafeListSanitizer
                   → Rails::HTML4::SafeListSanitizer     [VERIFIED: bin/rails runner]

show.html.erb:76   → view `sanitize` helper
                   → ActionView::Base.sanitizer_vendor
                   → Rails::HTML5::Sanitizer
                   → Rails::HTML5::SafeListSanitizer     [VERIFIED: bin/rails runner]
```

`Rails::HTML::SafeListSanitizer` points at the HTML4 variant for backward compatibility [CITED: github.com/rails/rails-html-sanitizer README], while `config.load_defaults 8.0` (this app, `config/application.rb:12`) sets `config.action_view.sanitizer_vendor = Rails::HTML::Sanitizer.best_supported_vendor` [CITED: guides.rubyonrails.org/configuring.html, "Default Values for Target Version 7.1"], which resolves to the HTML5 vendor on CRuby.

Verified demonstration:

```
input  (raw)          "<h2>A&nbsp;B</h2>..."
model  (HTML4)        "<h2>A B</h2>..."          # literal U+00A0
view   (HTML5)        "<h2>A&nbsp;B</h2>..."     # entity restored
model == view         false

Nokogiri::HTML5 round-trip of view output  → identical
Nokogiri::HTML4 round-trip of view output  → NOT identical  ("A B")
```

Corpus test across all of `Blog::ALLOWED_TAGS` (tables/colgroup/tfoot, pre+code with escaped `<`/`&`, figure+img+figcaption, entity soup, nested lists+blockquote, all heading levels, emoji/CJK/Cyrillic, stray `<td>`, stray `<li>`, empty `<p>`, minimal text):

| Case | `HTML5` round-trip identical? | `HTML4` round-trip identical? |
|------|------------------------------|-------------------------------|
| tables | ✓ | ✓ |
| code | ✓ | ✓ |
| images | ✓ | ✗ |
| entities | ✓ | ✗ |
| lists | ✓ | ✓ |
| headings | ✓ | ✓ |
| unicode | ✓ | ✓ |
| stray_td | ✓ | ✓ |
| stray_li | ✓ | ✓ |
| empty | ✓ | ✓ |
| minimal | ✓ | ✓ |

**How to avoid:** Use `Nokogiri::HTML5.fragment` in the PORO, and add a unit spec that asserts round-trip byte-identity for an entity-heavy body *before* the injection logic runs.

**Warning signs:** A golden-master diff showing only whitespace/character changes around `&nbsp;` or em-dashes. A spec that passes locally but fails after a `db:seed` with real content.

### Pitfall 2: The obvious dedup counter produces duplicate anchors — violating TOC-03 outright

**What goes wrong:** You use `seen = Hash.new(0); seen[base] += 1; anchor = "toc-#{base}#{seen[base] > 1 ? "-#{seen[base]}" : ''}"`. For the heading sequence `Getting Started`, `Getting Started`, `Getting Started 2`, this yields:

```
naive : ["toc-getting-started", "toc-getting-started-2", "toc-getting-started-2", ...]
         unique = FALSE                    ^^^^^^^^^^^^^^^^^^^^^^^ collision
```

A duplicate `id` in the document means every TOC link past the first points at the wrong section (browsers resolve `#id` to the *first* match), and Phase 3's `IntersectionObserver` scroll-spy will highlight the wrong entry. The same bug hits the positional fallback: `Section 5` (a real heading) collides with `toc-section-5` (a fallback anchor).

**Why it happens:** The counter tracks *base slugs seen*, not *anchors issued*. A heading whose natural slug happens to equal an already-issued suffixed anchor is invisible to it.

**How to avoid:** Pattern 2 — probe against the set of issued anchors:

```
robust: ["toc-getting-started", "toc-getting-started-2", "toc-getting-started-2-2",
         "toc-section-5", "toc-section-5-2"]
         unique = TRUE
```

[VERIFIED: both algorithms executed side by side in this repo, 2026-08-02]

**Warning signs:** A spec that only tests "two identical headings" will pass with the broken algorithm. The test case that catches it is *a heading whose text already ends in the collision suffix*.

### Pitfall 3: `parameterize` returns empty for far more than emoji and CJK

**What goes wrong:** The fallback path (`toc-section-N`) is treated as a rare edge case and gets one token test. In reality it fires for **every non-Latin script**:

```
"🚀🚀🚀"        -> ""     (emoji)
"日本語のみ"     -> ""     (CJK)
"Привет мир"    -> ""     (Cyrillic)   ← not in D-02's example list
"!!!???"        -> ""     (punctuation)
"Café & Crème"  -> "cafe-creme"        (Latin-1 transliterated — works)
"Ünicode Ätest" -> "unicode-atest"     (Latin Extended — works)
"C++ vs C#"     -> "c-vs-c"            ← note: lossy, "C++" and "C#" both vanish
```

[VERIFIED: `bundle exec ruby` with activesupport 8.0.3]

Greek, Arabic, Hebrew, Thai, Hindi and Korean will all hit the fallback too. `parameterize` → `transliterate` only maps Latin-1 Supplement / Latin Extended-A to ASCII.

**Why it happens:** `ActiveSupport::Inflector.transliterate` uses an ASCII approximation table scoped to Latin scripts; everything else is replaced and then stripped.

**How to avoid:** Treat `toc-section-N` as a first-class code path, not an edge case. Spec it for at least emoji, CJK, Cyrillic, and punctuation-only. Note that `"C++ vs C#"` and `"C vs C"` slugify identically — which is exactly why Pitfall 2's robust dedup matters.

**Warning signs:** A post in a non-Latin language whose entire TOC reads `Section 1, Section 2, Section 3` in the anchors (labels are still correct — D-08 keeps the original markup — so this is cosmetically invisible in the UI and only surfaces in URLs).

### Pitfall 4: Two truncation-related collisions

**What goes wrong:** Heading text is unbounded, so slugs are too — a 60-word heading produced a **299-character** slug in testing [VERIFIED]. If you then truncate to a fixed length, two long headings sharing a prefix collide.

**How to avoid:** Truncate the *base* (recommended `MAX_SLUG_LENGTH = 80`) and then run uniqueness allocation on the truncated value — never the reverse. Also strip a trailing `-` left behind by truncation (`slug.first(80).sub(/-\z/, "")`), otherwise you get `toc-word-word-`.

**Also note:** `<h2>A<br>B</h2>` yields `node.text == "AB"` (slug `ab`), not `"A B"`. If separated words matter, normalize `<br>` to a space before calling `.text`. Low impact; document the behavior rather than over-engineering.

**Warning signs:** Anchors ending in `-`. Two long headings both mapping to `toc-the-complete-guide-to-...`.

### Pitfall 5: A naive full-page golden master is flaky and will false-fail through Phases 2–3

**What goes wrong:** `expect(response.body).to eq(File.read(golden))` on the full page. Four verified volatility sources in this app's actual `/blog/:slug` test-env response:

1. **Propshaft asset digest** — `<link rel="stylesheet" href="/assets/application-a812b469.css">`. Changes on *every* Tailwind rebuild. Phase 2 and 3 both change CSS, so this alone would break the gate on work that is supposed to be safe. [VERIFIED: observed in a test-env response]
2. **ISO-8601 timestamps in JSON-LD** — `2026-08-01T11:26:07` from `published_at` / `updated_at`. Fixtures built with `1.day.ago` produce a different value on every run. [VERIFIED]
3. **Related-articles block** — `BlogsController#show` falls back to `Blog.published.where.not(id: @blog.id).limit(3)`. With 3–5 golden-master fixtures in the same DB, the block's contents and order depend on `published_at` ordering; ties are nondeterministic. Observed links: `["/blog/gm-probe-2", "/blog/blog-post-1", "/blog/blog-post-2", "/blog/blog-post-3"]`. [VERIFIED]
4. **Cookie-consent `data-providers` JSON** — rendered from `config/analytics_providers.json`, which per the project's own memory notes is expected to change when providers are added. [VERIFIED: present in response; config file is the documented source]

Note that **CSRF tokens are *not* a source of flakiness in the test environment** — `csrf_meta_tags` renders empty there (forgery protection off), and two back-to-back requests in one process produced byte-identical bodies. [VERIFIED] But don't rely on that if the spec ever runs with `allow_forgery_protection = true`.

**How to avoid:** Pattern 4 — Layer A (byte-exact on `div.prose`) + Layer B (normalized full page). Pin fixture timestamps to absolute `Time.utc(...)` values, spaced apart so `published_at DESC` ordering is total. Do **not** attach Active Storage images to golden-master fixtures — blob keys are random per run; D-09's "images" requirement means `<img>` tags *inside the body HTML*, which is what actually flows through the sanitize/inject path.

**Warning signs:** A golden master that fails immediately after `yarn build:css` with no Ruby change. Intermittent failures that flip based on spec execution order.

### Pitfall 6: `Nokogiri#to_html` returns a raw String — forgetting `.html_safe` renders escaped markup on the page

**What goes wrong:** The helper returns `fragment.to_html` (a plain `String`), ERB HTML-escapes it, and the reader sees literal `<h2 id="toc-intro">Intro</h2>` text on the page. Highly visible, caught immediately by the golden master — but only if a TOC-*on* spec exists. The TOC-off short-circuit path returns a `SafeBuffer` and hides the bug.

**How to avoid:** Include at least one `toc_enabled: true` request spec asserting `response.body` contains `<h2 id="toc-` (unescaped) — success criterion #2 requires exactly this ("the rendered `/blog/:slug` response body — not just the model attribute").

### Pitfall 7 (resolved): the Tiptap `id` round-trip blocker is moot by construction

STATE.md flags: *"Tiptap StarterKit Heading dropping unknown `id` attributes on round-trip is unverified (MEDIUM confidence)."*

**This concern does not apply under D-03.** Anchor ids are never persisted, so the Tiptap editor never loads a body containing them. Verified upstream guarantee:

```
Rails::Html::SafeListSanitizer.new.sanitize('<h2 id="evil">X</h2><div id="d">y</div>',
                                            tags: Blog::ALLOWED_TAGS,
                                            attributes: Blog::ALLOWED_ATTRIBUTES)
=> "<h2>X</h2>y"          # id stripped by the model's before_save — VERIFIED
```

`Blog#sanitize_body` strips `id` on every save because `id ∉ Blog::ALLOWED_ATTRIBUTES`. Even if an admin pasted HTML with ids, or Tiptap emitted them, they never reach the column.

**Recommended discharge for this phase** (cheap, no browser needed): a model spec asserting `create(:blog, body: '<h2 id="x">T</h2>').reload.body` excludes `id=`. That converts the MEDIUM-confidence blocker into a HIGH-confidence, permanently-enforced invariant. `Article` should get the same assertion to cover the STI path (D-06).

## Code Examples

### Migration (TOC-01 + D-05)

```ruby
# db/migrate/2026XXXXXXXXXX_add_toc_fields_to_blogs.rb
# Style matches db/migrate/20260522000001_add_seo_fields_to_blogs.rb (this repo).
class AddTocFieldsToBlogs < ActiveRecord::Migration[8.0]
  def change
    add_column :blogs, :toc_enabled,   :boolean, default: false, null: false
    add_column :blogs, :toc_overrides, :jsonb,   default: {},    null: false
  end
end
```

Notes:
- `default: false, null: false` mirrors the verified in-repo precedents `t.boolean "featured_on_home", default: false, null: false` and `t.string "spacing", default: "normal", null: false`.
- `default: {}` (object, keyed by anchor per ADMIN-02) rather than `[]` — `keywords` uses `[]` because it's a list; `toc_overrides` is a map. Both follow the same jsonb-with-non-null-default pattern.
- **No backfill.** `add_column` with a constant default does not rewrite the table and does not touch `updated_at` (PG 11+ / Rails 8). This is what satisfies D-05.
- One migration, not two — both columns share a single concern and a single `add_column` batch is atomic.
- **No index on `toc_enabled` recommended.** It is only ever read on an already-loaded single record in `show`; there is no `where(toc_enabled: true)` query in v1. Adding one is unused write cost. (Revisit if Phase 4 adds an admin filter.)

### Strong params seam (Phase 4 will use it; adding the key now is harmless)

```ruby
# app/controllers/admin/blogs_controller.rb — blog_params
permitted = %i[title author_id published_at category
               excerpt body featured featured_on_home image og_image
               meta_title meta_description spacing canonical_url_override
               toc_enabled]
```

Whether to add this in Phase 1 or defer to Phase 4 (ADMIN-01) is a planner call. Adding the scalar `toc_enabled` now is zero-risk and makes the column reachable from a console/spec-driven toggle; `toc_overrides` (a nested structure) should wait for Phase 4 where its shape is decided.

### PORO unit spec skeleton

```ruby
# spec/models/blog/table_of_contents_spec.rb
require "rails_helper"

RSpec.describe Blog::TableOfContents do
  # Helper mirrors the exact production path: view-level sanitize, HTML5 vendor.
  def rendered(raw)
    ActionController::Base.helpers.sanitize(
      raw, tags: Blog::ALLOWED_TAGS, attributes: Blog::ALLOWED_ATTRIBUTES
    )
  end

  def toc(raw) = described_class.call(rendered(raw))

  describe "heading scope (TOC-02, D-01, D-10)" do
    it "includes only h2 and h3, in document order, including orphan h3s" do
      result = toc("<h3>Orphan</h3><h1>T</h1><h2>A</h2><h4>D</h4><h3>B</h3><h6>Z</h6>")
      expect(result.entries.map { [ _1.level, _1.text ] })
        .to eq([ [ 3, "Orphan" ], [ 2, "A" ], [ 3, "B" ] ])
    end

    it "leaves h1 and h4-h6 without ids" do
      html = toc("<h1>T</h1><h2>A</h2><h4>D</h4>").to_html
      expect(html).to include('<h2 id="toc-a">')
      expect(html).to include("<h1>T</h1>").and include("<h4>D</h4>")
    end
  end

  describe "anchor contract (TOC-03, D-02)" do
    it "prefixes every anchor with toc-" do
      expect(toc("<h2>A</h2><h3>B</h3>").entries.map(&:anchor)).to all(start_with("toc-"))
    end

    it "dedupes identical headings with a counter suffix" do
      expect(toc("<h2>Intro</h2><h2>Intro</h2>").entries.map(&:anchor))
        .to eq(%w[toc-intro toc-intro-2])
    end

    # PITFALL 2 — this is the case a naive counter fails.
    it "stays unique when a heading's own slug matches an issued suffix" do
      anchors = toc("<h2>Intro</h2><h2>Intro</h2><h2>Intro 2</h2>").entries.map(&:anchor)
      expect(anchors.uniq.size).to eq(3)
    end

    # PITFALL 2 — fallback anchors must also participate in uniqueness.
    it "stays unique when a real heading collides with a positional fallback" do
      anchors = toc("<h2>x</h2><h2>Section 2</h2><h2>🚀</h2>").entries.map(&:anchor)
      expect(anchors.uniq.size).to eq(3)
    end

    # PITFALL 3 — all four empty-slug classes.
    %w[🚀 日本語 Привет !!!].each_with_index do |text, i|
      it "falls back to a positional anchor for #{text.inspect}" do
        expect(toc("<h2>#{text}</h2>").entries.first.anchor).to eq("toc-section-1")
      end
    end
  end

  describe "labels (D-08)" do
    it "preserves allowed inline markup in the label" do
      expect(toc("<h2>Getting <code>Started</code></h2>").entries.first.label_html)
        .to eq("Getting <code>Started</code>")
    end

    it "keeps plain text available separately" do
      expect(toc("<h2>Getting <code>Started</code></h2>").entries.first.text)
        .to eq("Getting Started")
    end
  end

  describe "byte fidelity (PITFALL 1, LAYOUT-04)" do
    it "round-trips entity-bearing markup unchanged when no headings are present" do
      input = rendered("<p>&nbsp;&amp;&mdash;&hellip;&copy;</p><figure><img src=\"/a.png\" alt=\"A&nbsp;B\"></figure>")
      expect(described_class.call(input).to_html).to eq(input.to_s)
    end
  end
end
```

### Request spec asserting the *rendered response* carries the ids (success criterion #2)

```ruby
# append to spec/requests/blogs_spec.rb, or a new spec/requests/blogs_toc_spec.rb
describe "TOC anchor injection on show" do
  let(:body) { "<h1>Skipped</h1><h2>Intro</h2><p>x</p><h3>Detail</h3><h4>Skipped</h4><h2>Intro</h2>" }

  it "injects unique toc- ids into the rendered h2/h3 when toc_enabled" do
    blog = create(:blog, slug: "toc-on", body: body, toc_enabled: true, published_at: 1.day.ago)
    get blog_path(blog.slug)

    expect(response.body).to include('<h2 id="toc-intro">')
    expect(response.body).to include('<h3 id="toc-detail">')
    expect(response.body).to include('<h2 id="toc-intro-2">')
    expect(response.body).to include("<h1>Skipped</h1>")   # untouched
    expect(response.body).to include("<h4>Skipped</h4>")   # untouched
  end

  it "emits no ids when toc_enabled is false" do
    blog = create(:blog, slug: "toc-off", body: body, toc_enabled: false, published_at: 1.day.ago)
    get blog_path(blog.slug)

    expect(response.body).not_to include('id="toc-')
  end

  it "never persists ids to the body column, and leaves the JSON API untouched" do
    blog = create(:blog, slug: "toc-persist", body: body, toc_enabled: true, published_at: 1.day.ago)
    get blog_path(blog.slug)

    expect(blog.reload.body).not_to include("id=")
  end
end
```

## Runtime State Inventory

This phase is additive (new columns, new PORO, new specs), not a rename/refactor/migration. Categories are answered explicitly rather than omitted, because D-05 makes "what else stores or derives from `body`?" a first-class correctness question.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | `blogs.body` (text) — read by `Blog#seo_description` (`strip_tags(body).truncate(160)`), `BlogsController#sanitized_blog_content` (`.md` export), and `api/v1/blogs/show.json.jbuilder` (`json.content_html @blog.body`). **All three branch off `body` upstream of the injection point** — verified by reading the actual code paths. | **None.** Byte-identity holds by construction. Recommend one spec each asserting `.md` and `show.json` output is unchanged for a `toc_enabled: true` post, to lock the invariant. |
| Live service config | None. No n8n/Datadog/Cloudflare/Tailscale surface in this repo. `config/analytics_providers.json` is in git and is not affected by this phase (but is a golden-master volatility source — see Pitfall 5). | None. |
| OS-registered state | None — verified: no Task Scheduler / launchd / pm2 / systemd artifacts in the repo; deployment is Kamal (Docker) + optional Capistrano. | None. |
| Secrets/env vars | None. `figaro` / `.env` hold Telegram + ALTCHA + DB credentials; no TOC-related keys. Verified via `.env.example` reference in CLAUDE.md and `config/` grep. | None. |
| Build artifacts | `app/assets/builds/application.css` and `application.js` are esbuild/Tailwind outputs. Phase 1 adds **no** CSS or JS, so no rebuild is required. Note: the Propshaft digest of these files is a golden-master volatility source (Pitfall 5). | None for Phase 1. Phase 2/3 will change these — hence Layer B normalization. |

**Additionally verified for D-05 byte-identity:** `add_column` with a constant default on PG 11+ does not rewrite rows and does not touch `updated_at`. No `Blog.update_all`, no data migration, no seed change.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `Rails::Html::WhiteListSanitizer` | `Rails::Html::SafeListSanitizer`, further split into `Rails::HTML4::*` / `Rails::HTML5::*` | rails-html-sanitizer 1.4 → 1.6 | This repo already uses the current name. The HTML4/HTML5 split is the source of Pitfall 1. [CITED: github.com/rails/rails-html-sanitizer] |
| Rails apps sanitize with libxml2 (HTML4) | Rails 7.1+ defaults `config.action_view.sanitizer_vendor = Rails::HTML::Sanitizer.best_supported_vendor` → HTML5/gumbo on CRuby | Rails 7.1 | The *view* helper in this app is HTML5; the *model* callback is still HTML4. Do not assume they agree. [CITED: guides.rubyonrails.org/configuring.html] |
| Client-side JS TOC generation (`tocbot`, `tocify`) | Server-side derivation + progressive enhancement | ongoing | Already the project's locked position (REQUIREMENTS.md Out of Scope: "Client-side JS-only TOC generation"). No JS library research needed. |
| `:target` / manual `scroll-into-view` | `IntersectionObserver` + `scroll-margin-top` | — | Phase 3 concern, not Phase 1. Noted only so the planner doesn't pull it forward. |

**Deprecated/outdated:**
- `Rails::Html::WhiteListSanitizer` — renamed; do not reintroduce.
- `Nokogiri::HTML` (bare) as an alias — prefer explicit `Nokogiri::HTML5` / `Nokogiri::HTML4` so the parser choice is legible at the call site. This is the whole lesson of Pitfall 1.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Ruby | everything | ✓ | 3.4.2 | — |
| Rails | everything | ✓ | 8.0.3 | — |
| Nokogiri (with HTML5/gumbo) | TOC derivation + injection | ✓ | 1.18.10, `defined?(Nokogiri::HTML5) == "constant"` | none needed |
| rails-html-sanitizer | existing sanitize passes | ✓ | 1.6.2 | — |
| PostgreSQL (jsonb) | `toc_overrides` | ✓ | test + dev DBs functional (`bundle exec rspec` connects and passes) | — |
| rspec-rails | all specs | ✓ | 7.1.1 — `bundle exec rspec spec/requests/blogs_spec.rb` → 11 passed | — |
| factory_bot_rails | golden-master fixtures | ✓ | 6.5.1, `:blog` factory exists | — |
| database_cleaner-active_record | spec isolation | ✓ | 2.2.2, configured in `rails_helper.rb` | — |
| Node/esbuild/Tailwind | — | ✓ | not needed this phase | — |
| Capybara / Selenium | — | ✓ 3.40.0 / 4.36.0 installed, but **`spec/system` does not exist** | request specs only (D-07) | Not needed — LAYOUT-04 is explicitly a request spec |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** none.

**Deployment note:** `Gemfile.lock` includes `nokogiri (1.18.10-x86_64-linux-gnu)` and `-aarch64-linux-gnu`, both precompiled native gems that bundle gumbo. `Nokogiri::HTML5` will be available in the `ruby:3.4.2-slim` Docker image. No JRuby platform in the lockfile, so the `Rails::HTML::Sanitizer.html5_support?` guard is unnecessary here.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Public read path; `toc_enabled` write is behind `Admin::BaseController` (existing, unchanged). |
| V3 Session Management | no | No session interaction. |
| V4 Access Control | yes (indirect) | `toc_enabled` / `toc_overrides` must only be settable through `Admin::BlogsController#blog_params` (Devise + admin flag). Do **not** expose them via any public controller or the JSON API write path. |
| V5 Input Validation & Output Encoding | **yes — primary** | Two existing `Rails::HTML*::SafeListSanitizer` passes with `Blog::ALLOWED_TAGS` / `ALLOWED_ATTRIBUTES`, **both unchanged**. New: TOC entry labels get a *narrower* sanitize (`LABEL_TAGS = %w[strong em code a br]`). Anchor values are Nokogiri-escaped on `node["id"] = ...` and are already `parameterize` output (`[a-z0-9-]` only). |
| V6 Cryptography | no | No secrets, no hashing, no tokens. |
| V13 API & Web Service | yes (negative requirement) | `api/v1/blogs/show.json` must be byte-for-byte unchanged (D-05). Add a spec asserting `content_html` equals `blog.body` for a `toc_enabled: true` post. |

### Known Threat Patterns for Rails 8 + server-rendered HTML

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Stored XSS via admin-authored `body` | Tampering / Elevation | Existing `before_save :sanitize_body` + view-level `sanitize`. **Unchanged.** Anchor injection adds no author-controlled markup — only `id` values from `parameterize` output. |
| `html_safe` reintroducing unsanitized content | Tampering | The `.html_safe` call operates on `Nokogiri::HTML5.fragment(already_sanitized).to_html`. The input is the sanitizer's own output; the only mutation is `node["id"] = <slug>`. Brakeman will flag this — see below. |
| DOM clobbering via attacker-controlled `id` | Tampering | Mitigated by D-03: `id` is never in `ALLOWED_ATTRIBUTES`, so it can never be persisted from author input (**verified**: model sanitizer strips `id="evil"`). Injected ids are always `toc-`-prefixed and slug-constrained, so they cannot shadow `document.body`, `document.forms`, etc. This is a genuine security benefit of the locked design, not just a convenience. |
| Duplicate `id` breaking anchor navigation | (availability/correctness) | Pattern 2's uniqueness guarantee. Not strictly a security issue but a correctness invariant worth asserting. |
| jsonb injection via `toc_overrides` | Tampering | ActiveRecord's jsonb type casts and parameterizes — no string interpolation into SQL. Phase 4 must still validate the override *shape* (keys must match known anchors, values must be strings) before rendering. Out of scope for Phase 1, but the planner should note it so Phase 4 doesn't assume the column is trusted. |
| Regex-based normalization in the golden-master helper | (test-only) | Test-code only; no request-path exposure. |

### Brakeman handling (required — brakeman 7.1.0 is in this repo's dev/test bundle)

Brakeman will raise a **Cross-Site Scripting / "unescaped model attribute"** style warning on the `.html_safe` call in `BlogsHelper`. Handle it deliberately, not by disabling the scanner:

1. Keep the justification comment adjacent to the call (as in Pattern 3) so a reviewer sees *why* it is safe.
2. If the repo adopts a `config/brakeman.ignore`, add the fingerprint with the same justification text. **Note: no `config/brakeman.yml` or ignore file exists in this repo today** [VERIFIED], so the planner should decide whether to introduce one or accept the warning in CI output.
3. Run `bundle exec brakeman` as a verification step in the phase plan and record the before/after warning counts, so a *new* unrelated warning isn't masked.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `add_column` with a constant default on PG 11+/Rails 8 does not rewrite the table and does not touch `updated_at`. | Migration / Runtime State Inventory | Low. If wrong, existing rows' `updated_at` changes, violating D-05. **Cheap discharge:** the plan should include a spec that snapshots `Blog.pluck(:id, :updated_at)` before and after `db:migrate` on a seeded DB, or simply asserts `updated_at` on a pre-existing record is unchanged. This is the one assumption in this document that materially affects a locked decision. |
| A2 | `rspec-snapshot` (2.2.0) and `approvals` (0.1.7) exist on rubygems.org with those versions. | Alternatives Considered | None — both are recommended *against*. Discovered via `gem list -r` (registry existence only), so tagged `[ASSUMED]` per the package-provenance rule. Neither is being installed. |
| A3 | `parameterize` fails to transliterate Greek, Arabic, Hebrew, Thai, Hindi, and Korean (extrapolated from verified Cyrillic/CJK/emoji results). | Pitfall 3 | Very low. Only affects how many fallback test cases are written. Verified cases (emoji, CJK, Cyrillic, punctuation) are sufficient to prove the code path. |
| A4 | Zeitwerk resolves `app/models/blog/table_of_contents.rb` as `Blog::TableOfContents` given `Blog` is defined in `app/models/blog.rb`. | Project Structure | Low. Standard Rails 8 autoloading. If it misbehaves, move the file to `app/services/` or `lib/` — trivial fix, caught by the first spec run. |
| A5 | Adding `gem "nokogiri"` to the `Gemfile` resolves to the already-locked 1.18.10 with no lockfile churn. | Installation | Low. If `bundle install` produces unexpected lockfile changes, skip the declaration — Nokogiri is already loadable without it (verified). |
| A6 | Brakeman 7.1.0 will flag the `.html_safe` call in `BlogsHelper`. | Security Domain | Low. If it doesn't flag it, nothing breaks; the justification comment remains valuable. |

Everything not listed here is `[VERIFIED]` by execution against this repo's bundle on 2026-08-02, or `[CITED]` to the linked official source.

## Open Questions

1. **Should `toc_enabled` be added to `Admin::BlogsController#blog_params` in Phase 1 or deferred to Phase 4?**
   - What we know: ADMIN-01 (the form control) is Phase 4. The column itself is Phase 1 (TOC-01). Permitting the param is a one-word change with no UI.
   - What's unclear: whether the phase boundary in CONTEXT.md ("Explicitly NOT this phase: ... admin override UI") is meant to exclude the strong-param key too.
   - Recommendation: **Add `toc_enabled` to strong params in Phase 1.** It costs one word, is invisible without a form field, and makes the column reachable from specs/console for the TOC-on request specs this phase already needs. Leave `toc_overrides` entirely to Phase 4 where its shape is decided.

2. **Should the golden-master fixtures live in `spec/fixtures/golden_master/` or be regenerated in-memory?**
   - What we know: committed baseline files are the standard characterization-test approach and give a readable git diff when something changes — which is exactly the signal LAYOUT-04 wants.
   - What's unclear: whether the team wants ~5 committed HTML files (a few KB each for Layer A, ~40KB each for Layer B full pages) in the repo.
   - Recommendation: commit both layers. Layer A files are small. If Layer B's size is objectionable, commit only Layer A byte-exact and reduce Layer B to a structural assertion set (heading count, wrapper classes, absence of `id="toc-`). Provide `UPDATE_GOLDEN=1` regeneration and document it in the spec header.

3. **Does the `faq_post` golden-master fixture need real `faq_schema` data?**
   - What we know: D-09 requires an FAQ-section post. `spec/requests/blogs_spec.rb` sets it via `blog.update_column(:faq_schema, ...)` (bypassing `parse_faq_schema`). The `_faq_section.html.erb` partial and `render_faq_schema` both branch on `faq_pairs`.
   - Recommendation: yes — use the existing `update_column` idiom so the FAQ partial and the FAQPage JSON-LD both render, giving the golden master coverage of that branch. `update_column` also avoids touching `updated_at`, keeping the JSON-LD `dateModified` pinned.

4. **`MAX_SLUG_LENGTH` value?**
   - What we know: unbounded slugs reach 299 characters (verified). 80 is a common convention.
   - Recommendation: 80. Marked as Claude's discretion in CONTEXT.md; any bounded value works because Pattern 2 handles the resulting collisions.

## Sources

### Primary (HIGH confidence)

- **Direct execution against this repository's bundle** (2026-08-02) — `bin/rails runner` and `bundle exec ruby` probes verifying: Nokogiri 1.18.10 + `Nokogiri::HTML5` availability; `Rails::HTML::SafeListSanitizer` → HTML4; `ActionView::Base.sanitizer_vendor` → `Rails::HTML5::Sanitizer`; HTML4-vs-HTML5 sanitizer output divergence on entities; 11-case byte-fidelity round-trip corpus across `Blog::ALLOWED_TAGS`; `parameterize` behavior on emoji/CJK/Cyrillic/punctuation/Latin-Extended; naive-vs-robust anchor dedup collision reproduction; model sanitizer stripping `id`; 299-char slug from a long heading.
- **Direct execution of request specs** (2026-08-02) — `bundle exec rspec` probes verifying: two identical requests produce byte-identical bodies in test env; CSRF renders empty in test; Propshaft asset digest present (`/assets/application-a812b469.css`); ISO-8601 timestamps in JSON-LD; related-articles link set varies with fixture population; `div.prose` region contents.
- **Codebase reads** — `app/models/blog.rb`, `app/models/article.rb`, `app/controllers/blogs_controller.rb`, `app/controllers/admin/blogs_controller.rb`, `app/views/blogs/show.html.erb`, `app/views/api/v1/blogs/show.json.jbuilder`, `app/helpers/blogs_helper.rb`, `db/schema.rb`, `db/migrate/2026*`, `spec/rails_helper.rb`, `spec/requests/blogs_spec.rb`, `spec/models/blog_spec.rb`, `spec/factories/blogs.rb`, `Gemfile`, `Gemfile.lock`, `package.json`, `config/application.rb`, `.rspec`, `.planning/config.json`.
- [github.com/rails/rails-html-sanitizer](https://github.com/rails/rails-html-sanitizer) — HTML4/HTML5 variants; `Rails::HTML::SafeListSanitizer` aliases the HTML4 variant for backward compatibility; HTML5 unsupported on JRuby.
- [guides.rubyonrails.org/configuring.html](https://guides.rubyonrails.org/configuring.html) — `config.action_view.sanitizer_vendor` = `Rails::HTML::Sanitizer.best_supported_vendor`, listed under Default Values for Target Version 7.1.

### Secondary (MEDIUM confidence)

- `gem list -r rspec-snapshot approvals` — confirms both gems exist on rubygems.org (registry existence only; both are recommended against).

### Tertiary (LOW confidence)

- Extrapolation of `parameterize` transliteration failure to Greek/Arabic/Hebrew/Thai/Hindi/Korean (A3) — inferred from the verified Cyrillic and CJK results plus knowledge of the Latin-scoped `transliterate` table. Not directly tested.
- Brakeman's specific warning class for the `.html_safe` call (A6) — not executed during research.

## Metadata

**Confidence breakdown:**

- Standard stack: **HIGH** — every version confirmed in `Gemfile.lock` and loaded at runtime in this repo; zero new dependencies.
- Architecture: **HIGH** — the injection point, the sanitize call site, the `.md`/JSON/`seo_description` branch points, and the empty `BlogsHelper` were all read directly from source.
- Pitfalls 1–3, 5, 7: **HIGH** — each reproduced by executing code against this repo, with recorded outputs.
- Pitfall 4 (truncation): **HIGH** for the 299-char observation; **MEDIUM** for the recommended 80-char bound (a judgment call, explicitly Claude's discretion per CONTEXT.md).
- Pitfall 6: **MEDIUM** — `Nokogiri#to_html` returning a plain String is certain; the exact rendering symptom is standard Rails behavior, not separately executed.
- Migration no-backfill semantics (A1): **MEDIUM** — the single claim in this document that touches a locked decision without direct verification. The plan should discharge it with a `updated_at` snapshot check.
- Security: **HIGH** for the `id`-stripping verification and the sanitizer allowlist analysis; **MEDIUM** for the predicted Brakeman warning.

**Research date:** 2026-08-02
**Valid until:** 2026-09-01 (30 days — Rails 8.0.x, Nokogiri 1.18.x, and rails-html-sanitizer 1.6.x are all stable; the findings are anchored to this repo's pinned lockfile, so they only go stale on a deliberate `bundle update`)
