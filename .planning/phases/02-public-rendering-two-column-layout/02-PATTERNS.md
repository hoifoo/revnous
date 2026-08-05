# Phase 2: Public Rendering & Two-Column Layout - Pattern Map

**Mapped:** 2026-08-02
**Files analyzed:** 7 (2 new, 5 modified)
**Analogs found:** 7 / 7

## File Classification

| New/Modified File | New/Mod | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|---------|------|-----------|----------------|---------------|
| `app/helpers/blogs_helper.rb` | modified | helper (view-layer transform) | transform | itself (lines 1-14) + `app/helpers/application_helper.rb` | exact |
| `app/views/blogs/_toc_sidebar.html.erb` | **new** | view partial (component) | request-response | `app/views/case_studies/show.html.erb` lines 40-60 | exact (data flow) / role-match (partial vs inline) |
| `app/views/blogs/show.html.erb` | modified | view template | request-response | itself (lines 28, 75-80) | exact |
| `app/models/blog/table_of_contents.rb` | modified (optional) | model PORO | transform | itself (lines 35-53) | exact |
| `app/assets/stylesheets/application.tailwind.css` | modified (append) | config / stylesheet | static asset | itself, `.prose-paragraph-relaxed p` (lines 21-23) | exact |
| `spec/requests/blogs_toc_spec.rb` | modified | test (request spec) | request-response | itself (lines 1-106) | exact |
| `spec/helpers/blogs_helper_spec.rb` | **new** (optional) | test (helper spec) | transform | `spec/helpers/application_helper_spec.rb` | exact |

---

## Pattern Assignments

### `app/helpers/blogs_helper.rb` (helper, transform) — MODIFIED

**Analog:** itself. The entire current file is the pattern to extend, not replace.

**Current full contents** (lines 1-14) — the `# SECURITY:` comment convention, the guard clause, and the `.html_safe` placement are all load-bearing conventions that must survive the refactor to a value object:

```ruby
module BlogsHelper
  # SECURITY: sanitized_html is already the output of the view-level
  # `sanitize` helper using Blog::ALLOWED_TAGS/ALLOWED_ATTRIBUTES. The only
  # mutation applied here is adding `id` attributes to h2/h3 nodes, where the
  # id value is `parameterize` output constrained to [a-z0-9-] and always
  # `toc-` prefixed. No author markup is reintroduced and no allowlist is
  # widened. Enforced by spec/requests/blogs_toc_spec.rb and
  # spec/requests/blogs_golden_master_spec.rb.
  def blog_body_with_toc_anchors(blog, sanitized_html)
    return sanitized_html unless blog.toc_enabled?

    Blog::TableOfContents.call(sanitized_html).to_html.html_safe
  end
end
```

**Three conventions to carry forward:**
1. **`# SECURITY:` block comment above the method** that touches sanitized HTML. RESEARCH Security Domain requires extending this comment to also cover permalink injection (Brakeman flags `.html_safe`).
2. **Guard clause / early return** (`return X unless blog.toc_enabled?`) — matches the project-wide convention in CLAUDE.md. The new `< MIN_TOC_ENTRIES` suppression is a second guard in the same style.
3. **`.html_safe` applied only to `to_html` output of a fragment derived from already-sanitized input** — never to raw author content.

**Private-methods-at-bottom pattern** — copy from `app/helpers/application_helper.rb` lines 210-240:

```ruby
  private

  def image_object_schema(url, caption: nil)
    return nil if url.blank?
    node = { "@type" => "ImageObject", "url" => url, "contentUrl" => url }
    node["caption"] = caption if caption.present?
    node
  end

  def seo_metadata
    @seo_metadata ||= SeoMetadatum.find_by(page_identifier: controller_path_identifier)
  end
end
```

`visible_toc_entries` and `decorate_permalinks!` go below a `private` keyword at the bottom of the module, matching this shape (CLAUDE.md: "Private methods are grouped at the bottom of the class after `private`").

**Struct value-object pattern** — the *only* `Struct.new` precedent in `app/` is `app/models/blog/table_of_contents.rb:18`:

```ruby
Entry = Struct.new(:level, :anchor, :label_html, :text, keyword_init: true)
```

Copy this exact form (`keyword_init: true`) for the `ArticleContent` value object. Do not invent a different value-object idiom (no `Data.define`, no OpenStruct, no plain Hash) — `keyword_init: true` Struct is the established house style.

**Note:** there is **no existing `ActiveModel::Type::Boolean` usage anywhere in `app/` or `lib/`** (verified by grep). RESEARCH Pitfall 6 introduces it as a new idiom for casting the jsonb `hidden` flag. It has no analog — planner should follow RESEARCH Example 1 verbatim.

---

### `app/views/blogs/_toc_sidebar.html.erb` (view partial, request-response) — NEW

**Primary analog:** `app/views/case_studies/show.html.erb` lines 38-63 — the only sticky sidebar + multi-column anchor nav in the codebase, and it is a near-exact data-flow match (in-page anchor links in a sticky sidebar beside a main content column).

**Core two-column + sticky sidebar pattern** (lines 38-63):

```erb
<div class="bg-gray-50 py-16">
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
    <div class="grid grid-cols-1 lg:grid-cols-4 gap-12">
      <!-- Sidebar Navigation -->
      <div class="lg:col-span-1">
        <div class="sticky top-8">
          <nav class="space-y-2">
            <a href="#overview" class="block px-4 py-2 text-gray-900 font-medium hover:bg-white rounded-md transition">Overview</a>
            <a href="#challenge" class="block px-4 py-2 text-gray-700 hover:bg-white hover:text-gray-900 rounded-md transition">Challenge</a>
            <a href="#solution" class="block px-4 py-2 text-gray-700 hover:bg-white hover:text-gray-900 rounded-md transition">Solution</a>
            <a href="#results" class="block px-4 py-2 text-gray-700 hover:bg-white hover:text-gray-900 rounded-md transition">Results</a>
          </nav>
          ...
        </div>
      </div>

      <!-- Main Content Area -->
      <div class="lg:col-span-3">
```

**What to copy verbatim:**
- `sticky top-8` — confirms D-07's 32px offset is already the site's established sticky offset. Do not invent a different value.
- Plain `<a href="#anchor">` with `block` + `transition` + hover color change — zero JS, exactly what Phase 2 promises.
- `<nav>` wrapping the anchor list.
- `gap-12` (48px) grid gap — matches UI-SPEC's `lg:gap-12` `2xl` token exactly.

**CRITICAL — what this analog does DIFFERENTLY, and why the differences are deliberate:**

| Analog does | Phase 2 must do | Why |
|-------------|-----------------|-----|
| `lg:grid-cols-4` + `lg:col-span-1`/`lg:col-span-3` (proportional) | `lg:grid-cols-[minmax(0,1fr)_16rem]` (fixed 256px track) | D-04 fixed width; RESEARCH Pitfall 2 (`1fr` blows out on `<pre>`/`<table>`) |
| Sidebar **first** in DOM, renders **left** | Sidebar **first** in DOM, renders **right** via `lg:col-start-2 lg:row-start-1` | D-01 (right) + UI-SPEC DOM-order/WCAG 1.3.2 (TOC before article for screen readers) |
| `<nav class="space-y-2">` — **no `aria-label`** | `<nav aria-label="Table of contents">` — exact string, sentence case | A11Y-01 |
| Sidebar has a card (`bg-black ... rounded-lg` CTA at line 52) | **No surface at all** — no bg, no border, no shadow | UI-SPEC Visual Hierarchy: sidebar is secondary, gets no card treatment |
| Flat `<a>` siblings | `<ol role="list">` → `<li>` → `<a>` | UI-SPEC Component Inventory; `role="list"` because `list-none` drops semantics in Safari/VoiceOver |
| Renders at all widths (`grid-cols-1` fallback stacks) | `hidden lg:block` — nothing below 1024px | D-02/D-03: no mobile markup in Phase 2 at all |

**IMPORTANT — the sticky mechanic this analog already solves.** Note line 42-43: the *grid item* is `<div class="lg:col-span-1">` and the **sticky element is a child** (`<div class="sticky top-8">`). This is the "equivalent alternative" named in RESEARCH Pitfall 1 — it sidesteps the `align-items: stretch` trap without needing `self-start`, because the stretched grid item is the containing block and the child is free to travel. If the planner instead makes the grid item *itself* sticky (RESEARCH Pattern 3's `lg:self-start lg:sticky lg:top-8` on one element), `lg:self-start` is **mandatory**. Either shape works; the existing codebase precedent is the child-div shape.

**Secondary analog — blogs partial structure:** `app/views/blogs/_faq_section.html.erb` (full file, 11 lines):

```erb
<% if @blog.faq_pairs.any? %>
  <section class="mb-16" aria-labelledby="faq-heading">
    <h2 id="faq-heading" class="text-3xl font-bold text-gray-900 mb-6">Frequently Asked Questions</h2>
    <dl class="space-y-6">
      <% @blog.faq_pairs.each do |pair| %>
        <dt class="text-lg font-semibold text-gray-900"><%= pair['question'] %></dt>
        <dd class="mt-2 text-gray-700"><%= pair['answer'] %></dd>
      <% end %>
    </dl>
  </section>
<% end %>
```

Copy: the self-guarding `<% if ... .any? %>` wrapper, the semantic-list-with-`space-y-*` iteration shape, 2-space ERB indent.

**Deliberate divergence:** this analog uses `aria-labelledby` pointing at a visible `<h2>`. The TOC sidebar must use **`aria-label="Table of contents"`** instead, because UI-SPEC locks the visible label as a `<p>`, not a heading (a sibling `<h2>Table of Contents</h2>` would pollute the very heading outline the TOC describes). Do not copy `aria-labelledby` here.

**Link styling analog** — `app/views/blogs/_author_card.html.erb` lines 35-40, the `link_to`-with-block + brand-color pattern:

```erb
<%= link_to @blog.author.linkedin_url,
      target: "_blank",
      rel: "noopener noreferrer",
      class: "text-sm text-pink-600 hover:text-pink-700 font-medium inline-flex items-center gap-1" do %>
  LinkedIn
<% end %>
```

Also `_author_card.html.erb` line 23 is the exact analog for the sidebar's visible label typography (a non-heading `<p>` uppercase eyebrow):

```erb
<p class="text-xs font-semibold text-gray-400 uppercase tracking-wide mb-1">Written by</p>
```

The TOC label follows this shape at UI-SPEC's declared size/color: `text-sm font-semibold uppercase tracking-wide text-gray-900 mb-4`.

And `_author_card.html.erb` line 14 is the precedent for `aria-hidden` on a decorative inner span — exactly the permalink glyph shape:

```erb
<span class="text-base font-semibold text-gray-500" aria-hidden="true">
```

**Partial-render-with-locals convention** — the codebase passes locals as trailing keyword args, never a `locals:` hash (grep for `locals:` in `app/views/` returns **zero** matches). Copy from `app/views/admin/blogs/_form.html.erb:142`:

```erb
<%= render "faq_row_fields", pair: pair %>
```

So: `<%= render "blogs/toc_sidebar", entries: article.toc_entries %>`.

---

### `app/views/blogs/show.html.erb` (view template, request-response) — MODIFIED

**Analog:** itself. This is a byte-fidelity-constrained edit — the existing lines ARE the contract.

**The exact lines that must survive unmoved and unindented** (lines 74-80):

```erb
    <!-- Content -->
    <div class="prose prose-lg max-w-none mb-16 <%= 'prose-paragraph-relaxed' if @blog.spacing == 'relaxed' %>">
      <%= blog_body_with_toc_anchors(
            @blog,
            sanitize(@blog.body, tags: Blog::ALLOWED_TAGS, attributes: Blog::ALLOWED_ATTRIBUTES)
          ) %>
    </div>
```

**The container line that branches** (line 28):

```erb
  <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
```

**The frozen bytes these must still produce when TOC is off** — dumped fresh with `od -c` from `spec/fixtures/golden_master/minimal_post.article.html`:

```
<div class="prose prose-lg max-w-none mb-16 ">\n      <p>Just a sentence.</p>\n    </div>
                                          ^ trailing space, from the empty `spacing` conditional
```

Confirmed byte layout: `class` attribute ends with a **space before the closing quote**; inner content opens with `\n` + 6 spaces; closes with `\n` + 4 spaces.

**Byte-safe edit technique (RESEARCH Pattern 1 — the LAYOUT-03 enabler):** wrap with ERB lines containing *only* an ERB tag. Rails compiles with Erubi `trim: true`, so a standalone `<% %>` line emits zero bytes when its branch is skipped. Insert branch-conditional class *segments* inline rather than rewriting the attribute:

```erb
class="prose prose-lg <%= article.toc? ? '…' : 'max-w-none' %> mb-16 <%= 'prose-paragraph-relaxed' if @blog.spacing == 'relaxed' %>"
```

**Existing brand-link precedent already in this file** (line 31) — reuse `pink-600`/`pink-700`, introduce no new accent:

```erb
<%= link_to blogs_path, class: "text-pink-600 hover:text-pink-700 font-medium text-sm" do %>
  ← Back to Blog
<% end %>
```

**Existing standalone-`<% %>`-line precedent already in this file** (lines 105 + 152) — proves the technique is already used here, wrapping a whole block at column 0:

```erb
<% if @related_blogs.any? %>
<div class="bg-gray-50 py-16">
  ...
</div>
<% end %>
```

**Anti-patterns for this file (from RESEARCH):** do not re-indent the `div.prose` block, do not extract it into a partial, do not use `capture`, do not regenerate golden fixtures with `UPDATE_GOLDEN=1`, do not touch `_navigation.html.erb` / `_footer.html.erb` / `layouts/application.html.erb` / `_faq_section` / `_author_card` / `_notice_banner` (all appear in every `*.page.html` baseline).

---

### `app/models/blog/table_of_contents.rb` (model PORO, transform) — MODIFIED (optional)

**Analog:** itself. If the planner puts `decorate_permalinks!` on the PORO rather than in the helper, copy the existing traversal shape.

**Existing traversal + entry-capture ordering** (lines 35-53) — note that `entries <<` happens **inside** the loop; RESEARCH Pitfall 5 requires permalink injection to be a **separate pass after `derive!` returns**, never inside this block:

```ruby
def derive!
  used = {}

  fragment.css(HEADING_SELECTOR).each_with_index do |node, index|
    anchor = allocate_anchor(base_slug(node, index), used)
    node["id"] = anchor

    entries << Entry.new(
      level: node.name[1].to_i,
      anchor: anchor,
      label_html: sanitized_label(node),
      text: node.text.strip
    )
  end

  self
end

def to_html = fragment.to_html
```

**Constants + private-methods-at-bottom shape** (lines 9-20, 55-86) — a new `decorate_permalinks!` follows this file's structure: frozen constants at top, `attr_reader`, public mutator returning `self`, `private` section at the bottom.

```ruby
HEADING_SELECTOR = "h2, h3".freeze
ANCHOR_PREFIX = "toc-".freeze
MAX_SLUG_LENGTH = 80

LABEL_TAGS = %w[strong em code a br].freeze
LABEL_ATTRIBUTES = %w[href].freeze

Entry = Struct.new(:level, :anchor, :label_html, :text, keyword_init: true)

attr_reader :fragment, :entries
```

**Sanitizer-call pattern for the sidebar's Pitfall-4 fix** (lines 82-86) — copy this exact form (`ActionController::Base.helpers.sanitize` with explicit `tags:`/`attributes:`) when re-sanitizing `entry.label_html` in the partial:

```ruby
def sanitized_label(node)
  ActionController::Base.helpers.sanitize(
    node.inner_html, tags: LABEL_TAGS, attributes: LABEL_ATTRIBUTES
  )
end
```

Note `LABEL_TAGS` includes `a` (line 15) — this is Pitfall 4's root cause. **Do not narrow `LABEL_TAGS`** (Phase 1 contract D-08); re-sanitize at the render site instead.

---

### `app/assets/stylesheets/application.tailwind.css` (stylesheet) — MODIFIED (append)

**Analog:** itself, line 21-23 — the narrow custom-CSS exception precedent that authorizes the permalink hover-reveal as a legitimate third exception:

```css
.prose-paragraph-relaxed p {
  margin-bottom: 2em;
}
```

**Import/plugin header this appends after** (lines 1-3) — rules written after `@import "tailwindcss"` sit outside Tailwind's cascade layers and reliably beat the typography plugin's zero-specificity `:where()` base styles:

```css
@import "tailwindcss";
@import "../../../node_modules/@metamorfosilab/cookies-consent/dist/index.css";
@plugin "@tailwindcss/typography";
```

**Style conventions observed across the file:** plain kebab-case class selectors, 2-space indent, lowercase hex colors written literally (`#db2777` at line 63, `#6b7280` at line 88 — these are exactly pink-600 and gray-500, so the permalink CSS is colour-consistent with existing custom rules), `@apply` used only where a utility genuinely helps.

The permalink block goes at the end of the file, following RESEARCH Code Example 5's shape (`opacity: 0` at rest, parent-hover + `:focus-visible` reveal, `prefers-reduced-motion` escape hatch).

---

### `spec/requests/blogs_toc_spec.rb` (request spec) — MODIFIED

**Analog:** itself. Extend this file rather than starting a new one.

**Describe-block + fixture structure** (lines 1-23) — one shared `body_html` `let` exercising every branch, then `describe` per behaviour with a scoped `let(:blog)`:

```ruby
require 'rails_helper'

RSpec.describe "Blog TOC anchor injection", type: :request do
  # Exercises every branch at once: H1 (untouched), H2 "Intro" (twice, to
  # force the dedup suffix), a paragraph, H3 "Detail", and H4 (untouched).
  let(:body_html) do
    "<h1>Title</h1><h2>Intro</h2><p>Some paragraph text.</p>" \
      "<h3>Detail</h3><h4>Sub</h4><h2>Intro</h2>"
  end

  describe "rendered response (TOC-03, success criterion #2)" do
    let(:blog) do
      create(:blog, slug: "anchor-on-post", body: body_html, toc_enabled: true,
                    published_at: 1.day.ago)
    end

    it "injects unescaped, unique toc- anchors on H2/H3 in document order" do
      get blog_path(blog.slug)

      expect(response.body).to include('<h2 id="toc-intro">')
      expect(response.body).to include('<h3 id="toc-detail">')
      expect(response.body).to include('<h2 id="toc-intro-2">')
    end
  end
```

**Copy these three conventions:**
1. **Requirement ID in the `describe` string** — `"rendered response (TOC-03, success criterion #2)"`, `"TOC-off short-circuit (LAYOUT-04)"`. New blocks should read e.g. `"sidebar suppression threshold (TOC-04, D-12)"`, `"nav landmark (A11Y-01)"`, `"heading permalinks (INTX-04)"`.
2. **Raw-string `include` assertions against `response.body`**, not Capybara matchers — there is no system-spec infra.
3. **Counting assertion idiom** (line 35) for "exactly N, no stray injection":
   ```ruby
   expect(response.body.scan('id="toc-').length).to eq(3)
   ```
   Reuse this shape for entry counts: `expect(response.body.scan('class="toc-permalink"').length).to eq(3)`.

**Existing assertions that MUST stay green** (lines 20-22, 101-103) — permalink injection must not alter the heading's opening tag:

```ruby
expect(response.body).to include('<h2 id="toc-intro">')
```

**Persistence/API regression guard already present** (lines 59-90) — the `.md` export and `/api/v1/blogs/:slug` `content_html` byte-equality checks. Permalink injection mutates the in-memory fragment only; these must not need changes.

**Golden-master gate to run after every view edit** — `spec/requests/blogs_golden_master_spec.rb` lines 49-66, and `spec/support/golden_master.rb` lines 43-48:

```ruby
def article_region(html)
  node = Nokogiri::HTML5(html).at_css("div.prose")
  raise "GoldenMaster#article_region: no div.prose found — the article region markup is missing or its selector changed" if node.nil?

  node.to_html
end
```

Note the selector is `div.prose` with **zero normalization** on Layer A. Any change to that element's attribute string or inner whitespace fails.

---

### `spec/helpers/blogs_helper_spec.rb` (helper spec, transform) — NEW (optional)

**Analog:** `spec/helpers/application_helper_spec.rb` — the only helper-spec precedent (2 files in `spec/helpers/`).

**File header + describe shape** (lines 1-19):

```ruby
require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe "#page_keywords" do
    it "returns nil when @page_keywords is nil" do
      helper.instance_variable_set(:@page_keywords, nil)
      expect(helper.page_keywords).to be_nil
    end

    it "returns comma-joined string when @page_keywords has values" do
      helper.instance_variable_set(:@page_keywords, [ "seo", "marketing", "b2b" ])
      expect(helper.page_keywords).to eq("seo, marketing, b2b")
    end
  end
```

**Copy:** `RSpec.describe <HelperModule>, type: :helper`, the `helper.<method>` call convention, `describe "#method_name"` blocks, `build(:blog)` / `create(:blog)` factories, and `allow(blog).to receive(:...)` stubbing for jsonb-derived values (lines 34-37) — directly reusable for stubbing `toc_overrides`:

```ruby
blog = build(:blog)
allow(blog).to receive(:faq_pairs).and_return(
  [ { "question" => "Q1", "answer" => "A1" }, { "question" => "Q2", "answer" => "A2" } ]
)
```

---

## Shared Patterns

### Security comment convention
**Source:** `app/helpers/blogs_helper.rb` lines 2-8
**Apply to:** every helper/PORO method that produces `.html_safe` output or mutates sanitized HTML

```ruby
  # SECURITY: sanitized_html is already the output of the view-level
  # `sanitize` helper using Blog::ALLOWED_TAGS/ALLOWED_ATTRIBUTES. The only
  # mutation applied here is adding `id` attributes to h2/h3 nodes, where the
  # id value is `parameterize` output constrained to [a-z0-9-] and always
  # `toc-` prefixed. No author markup is reintroduced and no allowlist is
  # widened. Enforced by spec/requests/blogs_toc_spec.rb and
  # spec/requests/blogs_golden_master_spec.rb.
```

Brakeman flags `.html_safe`; this in-line argument is how the project has chosen to answer it. Extend the comment to cover permalink `<a>` injection.

### Guard clause / early return
**Source:** `app/helpers/blogs_helper.rb:10`, `app/models/blog/table_of_contents.rb:59`
**Apply to:** helper branch logic (TOC-off short-circuit, `< 3 entries` suppression)

```ruby
return sanitized_html unless blog.toc_enabled?
return "section-#{index + 1}" if slug.blank? # D-02 positional fallback
```

### Private methods at bottom
**Source:** `app/helpers/application_helper.rb:210`, `app/models/blog/table_of_contents.rb:55`
**Apply to:** all Ruby edits in this phase (CLAUDE.md convention)

### Brand accent color
**Source:** `app/views/blogs/show.html.erb:31`, `app/views/blogs/_author_card.html.erb:38`
**Apply to:** TOC entry hover/focus, permalink hover/focus — nothing else

```erb
class: "text-pink-600 hover:text-pink-700 font-medium text-sm"
```

UI-SPEC narrows this for the sidebar: gray at rest, `pink-600` on hover/focus only.

### Sticky offset
**Source:** `app/views/case_studies/show.html.erb:43`
**Apply to:** TOC sidebar sticky positioning

```erb
<div class="sticky top-8">
```

`top-8` is already the site's sticky offset — D-07 matches existing precedent, not a new value.

### Partial render with trailing keyword locals
**Source:** `app/views/admin/blogs/_form.html.erb:142`, `app/views/admin/blogs/edit.html.erb:7`
**Apply to:** the `_toc_sidebar` render call. Zero uses of `locals:` hash syntax exist in `app/views/`.

```erb
<%= render "faq_row_fields", pair: pair %>
<%= render "form", blog: @blog %>
```

### Keyword-init Struct value objects
**Source:** `app/models/blog/table_of_contents.rb:18` (the only `Struct.new` in `app/`)
**Apply to:** the new `ArticleContent` value object

```ruby
Entry = Struct.new(:level, :anchor, :label_html, :text, keyword_init: true)
```

### Explicit-allowlist sanitizer call
**Source:** `app/models/blog/table_of_contents.rb:82-86`
**Apply to:** re-sanitizing `entry.label_html` inside the sidebar link (Pitfall 4 nested-`<a>` fix)

```ruby
ActionController::Base.helpers.sanitize(
  node.inner_html, tags: LABEL_TAGS, attributes: LABEL_ATTRIBUTES
)
```

### Requirement-ID-tagged spec describes
**Source:** `spec/requests/blogs_toc_spec.rb:11,39,59,92`
**Apply to:** all new spec blocks

```ruby
describe "rendered response (TOC-03, success criterion #2)" do
describe "TOC-off short-circuit (LAYOUT-04)" do
describe "persistence and upstream consumers are untouched (D-05, ASVS V13)" do
describe "STI coverage (D-06)" do
```

---

## No Analog Found

| Concern | Role | Data Flow | Reason |
|---------|------|-----------|--------|
| `ActiveModel::Type::Boolean.new.cast(...)` for jsonb flag | helper | transform | Zero occurrences in `app/` or `lib/` (verified by grep). New idiom — follow RESEARCH Example 1 / Pitfall 6 |
| Arbitrary-value Tailwind grid track (`grid-cols-[minmax(0,1fr)_16rem]`) | view | — | Zero `grid-cols-[` occurrences in `app/views/` (verified by grep). All existing grids use named `grid-cols-N` + `col-span-N`. New syntax — follow RESEARCH Pattern 3 / UI-SPEC |
| `prose-h2:` / `prose-h3:` element modifiers | view | — | Zero occurrences; the codebase only uses bare `prose prose-lg` and one custom `.prose-paragraph-relaxed`. New idiom — follow RESEARCH Pattern 4 |
| `hidden lg:block` responsive-hide on a layout region | view | — | No precedent for hiding a whole content region by breakpoint. Trivial, but note it is new |
| System/browser specs for sticky + hover behavior | test | — | `spec/system/` does not exist; Capybara + Selenium installed but unconfigured. Use the manual QA checklist per UI-SPEC Verification Notes |

---

## Metadata

**Analog search scope:** `app/views/` (blogs, case_studies, admin, shared, kaminari), `app/helpers/`, `app/models/blog/`, `app/assets/stylesheets/`, `spec/requests/`, `spec/helpers/`, `spec/support/`, `spec/fixtures/golden_master/`
**Files scanned:** 14 read in full or targeted; 6 grep sweeps (aria-label, sticky, `grid-cols-[`, `render` locals, `Struct.new`, `ActiveModel::Type::Boolean`)
**Byte-fidelity verification:** `od -c spec/fixtures/golden_master/minimal_post.article.html` re-run in this session — trailing space in the `class` attribute confirmed
**Pattern extraction date:** 2026-08-02
