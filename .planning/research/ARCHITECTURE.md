# Architecture Research

**Domain:** Server-rendered blog reading UX (Rails 8 + Hotwire) — auto-generated Table of Contents with admin override
**Researched:** 2026-08-01
**Confidence:** HIGH (codebase facts verified by direct inspection + local Ruby/Nokogiri execution; JS scroll-spy patterns MEDIUM)

---

## Verified Codebase Facts

These drove every recommendation below. All were confirmed by reading files or running code locally — not assumed.

| Fact | Evidence | Why it matters |
|------|----------|----------------|
| `id` is **not** in `Blog::ALLOWED_ATTRIBUTES` | `app/models/blog.rb:8` | Any `id` on a heading is stripped — twice |
| Body is sanitized **twice**: on save and again on render | `blog.rb:130` (`before_save :sanitize_body`) and `app/views/blogs/show.html.erb:76` (`sanitize @blog.body, tags:, attributes:`) | Save-time ID injection is silently undone at render unless the allowlist changes |
| Verified: sanitizer strips `id` unless allowlisted | Ran `Rails::Html::SafeListSanitizer` locally — `<h2 id="intro">` → `<h2>` | Confirms the above is not theoretical |
| `keywords` is real `jsonb`; `faq_schema` is `text` holding a JSON string | `db/schema.rb` blogs table | `jsonb` precedent already exists on this table — no need to repeat the `faq_schema` workaround |
| `Article < Blog` (STI, `type` column) | `app/models/article.rb`, `db/schema.rb` | Migration + model logic auto-applies to both classes |
| Site header is `relative`, **not** sticky/fixed | `app/views/shared/_navigation.html.erb:1` | No global scroll-offset problem; `scroll-margin-top` only needed if the *mobile TOC bar* is made sticky |
| Show page is a single `max-w-4xl mx-auto` column | `show.html.erb:28` | Sidebar requires a wider wrapper — must be conditional to satisfy zero-regression requirement |
| No fragment caching anywhere in `app/views/blogs/` or layouts | grep for `cache ` returned nothing | Any caching added here is greenfield; don't assume an existing cache story |
| `.md` response strips all tags from body | `blogs_controller.rb#sanitized_blog_content` | TOC/anchors must not leak into the llms.txt-facing Markdown output |
| Tiptap `StarterKit` Heading has no `id` attribute configured | `tiptap_editor_controller.js:25` | Any `id` stored in body is **dropped on editor round-trip** — save-time IDs are not actually stable |
| `@tiptap/extension-table-of-contents` is MIT-licensed, v3.29.2 | `npm view` + extracted `LICENSE.md` | Available, but client-side only — rejected below, for reasons |
| `"日本語テスト".parameterize` → `""` | Ran locally with ActiveSupport | Slug generator needs an explicit empty-slug fallback |
| `Nokogiri::HTML(frag)` injects `<!DOCTYPE>…<html><body>` | Ran locally | Must use `Nokogiri::HTML5.fragment` — the widely-copied blog tutorial gets this wrong |
| Parse + inject on a 65 KB / 30-heading body: **2.5 ms** | Benchmarked locally, 200 iterations | Render-time parsing is affordable; caching is an optimization, not a requirement |

---

## Standard Architecture

### System Overview

```
┌───────────────────────────────────────────────────────────────────────┐
│                          ADMIN (authoring)                             │
├───────────────────────────────────────────────────────────────────────┤
│  ┌──────────────────┐   ┌───────────────────┐   ┌──────────────────┐  │
│  │ tiptap_editor    │   │ toc_builder       │   │ Admin::Blogs     │  │
│  │ _controller.js   │   │ _controller.js    │   │ Controller       │  │
│  │ (existing)       │   │ (NEW, mirrors     │   │ (+ strong params)│  │
│  │  writes body     │   │  faq_builder)     │   │                  │  │
│  └────────┬─────────┘   └─────────┬─────────┘   └────────┬─────────┘  │
│           │                       │                      │            │
│           │  _form.html.erb  ─────┴──── _toc_row_fields.html.erb      │
└───────────┼──────────────────────────────────────────────┼────────────┘
            │                                              │
            ▼                                              ▼
┌───────────────────────────────────────────────────────────────────────┐
│                          DOMAIN (Ruby)                                 │
├───────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────┐        ┌──────────────────────────────┐  │
│  │ Blog (ActiveRecord)     │        │ Blog::TableOfContents (PORO) │  │
│  │  body (text, sanitized) │───────▶│  .headings   -> [Heading]    │  │
│  │  toc_enabled  (bool)    │        │  .entries    -> merged TOC   │  │
│  │  toc_overrides (jsonb)  │───────▶│  .body_html  -> body + ids   │  │
│  │  before_save :sanitize  │        │  (pure, deterministic,       │  │
│  └─────────────────────────┘        │   no persistence)            │  │
│           ▲                          └───────────────┬──────────────┘  │
│           │                                          │                 │
│           │ SINGLE SOURCE OF TRUTH for the anchor-ID algorithm         │
└───────────┼──────────────────────────────────────────┼─────────────────┘
            │                                          │
            │                                          ▼
┌───────────┴───────────────────────────────────────────────────────────┐
│                       PUBLIC (reading)                                 │
├───────────────────────────────────────────────────────────────────────┤
│  BlogsHelper                                                           │
│    blog_toc_entries(blog)        blog_body_with_anchors(blog)          │
│           │                                │                           │
│           ▼                                ▼                           │
│  ┌──────────────────────┐      ┌──────────────────────────┐           │
│  │ _table_of_contents   │      │ _article_body            │           │
│  │  .html.erb           │      │  .html.erb               │           │
│  │  <nav> + mobile      │      │  prose + h2/h3 with ids  │           │
│  │  toggle + <ol>       │      │                          │           │
│  └──────────┬───────────┘      └────────────┬─────────────┘           │
│             │                               │                          │
│             └────────── show.html.erb ──────┘                          │
│                    data-controller="toc"                               │
│                          │                                             │
│                          ▼                                             │
│              ┌──────────────────────────┐                              │
│              │ toc_controller.js        │  IntersectionObserver        │
│              │  targets: panel, link,   │  + smooth scroll             │
│              │           toggle, content│  + mobile collapse           │
│              └──────────────────────────┘                              │
└───────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Implementation |
|-----------|----------------|----------------|
| `Blog` (model) | Owns `toc_enabled` flag and raw `toc_overrides` data. **Does not** parse HTML. | 2 new columns, 1 predicate (`toc?`), normalization of `toc_overrides` |
| `Blog::TableOfContents` (PORO) | Extracts headings, generates anchor IDs, merges overrides, returns body HTML with IDs injected. **Pure function of `(body, toc_overrides)`.** | `app/models/blog/table_of_contents.rb`, Nokogiri HTML5 fragment |
| `BlogsHelper` | Thin view-facing adapter; memoizes PORO per request | `app/helpers/blogs_helper.rb` (currently empty) |
| `_table_of_contents.html.erb` | Renders the `<nav>` **once**: mobile toggle button + list | New partial in `app/views/blogs/` |
| `_article_body.html.erb` | Renders `prose` container with anchor-injected body | New partial (extracted from `show.html.erb:75-77`) |
| `show.html.erb` | Layout switch: 1-column (TOC off, byte-identical to today) vs 2-column grid (TOC on) | Modified |
| `toc_controller.js` | Scroll-spy (IntersectionObserver), smooth scroll, mobile collapse | New Stimulus controller |
| `Admin::BlogsController` | Permits `toc_enabled` + nested `toc_overrides` params | Modified `blog_params` |
| `toc_builder_controller.js` | Reorder / relabel / hide rows in admin form | New Stimulus controller, mirrors `faq_builder_controller.js` |

---

## Decision 1: Anchor-ID injection at **render time**, not save time

**Recommendation: render-time injection via a shared PORO. Do not add a `before_save` callback and do not add `id` to `ALLOWED_ATTRIBUTES`.**

This is the single highest-leverage decision in the milestone, and it goes against the pattern in the most-cited Rails TOC tutorial ([Avo](https://avohq.io/blog/dynamic-table-of-contents-rails)), which uses `before_save :add_ids_to_headings`. That approach breaks in this codebase specifically.

### Why save-time fails here

1. **Double sanitization.** Even if a `before_save` callback writes `<h2 id="pricing">`, `show.html.erb:76` sanitizes again on render with the same allowlist and strips it. Verified locally.
2. **Fixing that requires widening the allowlist.** Adding `id` to `ALLOWED_ATTRIBUTES` makes `id` an *admin-controllable* attribute on every allowed tag — a DOM-clobbering surface (`<a id="body">`, `<img id="attributes">` shadowing globals) for zero benefit.
3. **Tiptap drops the IDs anyway.** `StarterKit`'s Heading node defines no `id` attribute, so loading a saved post into the editor and saving it again round-trips the IDs to nothing. Save-time IDs are therefore *not* more stable than derived ones — they only look like they are. Making them genuinely stable requires extending the Heading extension with a custom `id` attribute (`addAttributes` + `parseHTML`/`renderHTML`) — real work, for a marketing blog that rarely edits heading text.
4. **Existing posts need a backfill.** A save-time callback means a data migration rewriting `body` on every historical row — directly at odds with the "zero visual/layout regression on existing posts" requirement, and irreversible if the slug algorithm is later changed.
5. **Two IDs of truth.** The admin override form must show anchors *before* the next save. With save-time injection the admin form either reads stale stored IDs or recomputes them — duplicating the algorithm.

### Why render-time works

- **Sanitize first, inject second.** IDs are generated *after* `sanitize`, so they are machine-generated by construction. An admin cannot author an `id`. This is a strictly better security posture than allowlisting `id`.
- **One algorithm, two consumers.** `Blog::TableOfContents` is called from the public helper *and* the admin form. Identical input → identical output, so the anchors the admin edits are exactly the anchors the reader sees.
- **Self-healing.** Edit the body, the TOC updates. No stale stored derivative, no `parse_faq_schema`-style before_save reconciliation.
- **No migration of `body`.** Historical posts are untouched on disk.
- **Zero cost when off.** Gate the whole thing on `blog.toc_enabled?`; a TOC-off post renders through the existing code path with no Nokogiri parse at all.
- **`.md` output unaffected.** `render_blog_markdown` reads `@blog.body` directly, which never contains injected IDs.

**Cost, stated honestly:** 2.5 ms per render on a 65 KB / 30-heading post (benchmarked); under 1 ms for typical posts. And anchors are a function of heading *text*, so renaming a heading changes its anchor — breaking external deep links and orphaning that heading's override. Mitigation in Decision 2.

### The ID generation contract

Must be deterministic, unique, and non-empty. Verified working locally:

```ruby
# app/models/blog/table_of_contents.rb
HEADING_SELECTOR = "h2, h3".freeze

def fragment
  @fragment ||= begin
    frag = Nokogiri::HTML5.fragment(sanitized_body)   # NOT Nokogiri::HTML — see anti-patterns
    seen = Hash.new(0)
    frag.css(HEADING_SELECTOR).each_with_index do |node, i|
      base = node.text.parameterize.presence || "section-#{i + 1}"  # "日本語" -> "" -> fallback
      seen[base] += 1
      node["id"] = seen[base] > 1 ? "#{base}-#{seen[base]}" : base   # dedupe "Setup", "Setup"
    end
    frag
  end
end
```

Verified output for `<h2>Setup</h2><h2>Setup</h2><h2>日本語</h2><h2><img …></h2>`:
`setup`, `setup-2`, `section-3`, `section-4`.

---

## Decision 2: Overrides in a `jsonb` column — follow `keywords`, not `faq_schema`

**Recommendation: two new columns on `blogs`.**

```ruby
add_column :blogs, :toc_enabled,   :boolean, default: false, null: false
add_column :blogs, :toc_overrides, :jsonb,   default: [],    null: false
```

### Not a separate table

`blog_toc_entries` would be an entity table for something that is not an entity. Overrides have no independent lifecycle, are never queried or joined independently, and are 100% derived-data annotations on headings that live inside `body`. A table forces delete-and-recreate sync logic on every body save — the exact staleness problem render-time extraction was chosen to avoid.

### Not text-holding-JSON like `faq_schema`

`faq_schema` is a `text` column carrying a JSON string, requiring a custom writer (`blog.rb:53-61`), a `before_save :parse_faq_schema` (`blog.rb:105-124`), and a `JSON::ParserError`-rescuing reader (`blog.rb:63-70`) — roughly 30 lines of ceremony to emulate what Postgres does natively. Meanwhile `keywords` on the *same table* is already real `jsonb` with a 2-line normalizer (`blog.rb:101-103`). Copy `keywords`. The `faq_schema` shape is legacy, not the house style.

`jsonb` gives: type fidelity on read, no parse/rescue, no custom accessor, and the option of a GIN index later if TOC data ever needs querying (it won't).

### Shape: ordered array keyed by anchor

```json
[
  { "anchor": "getting-started", "label": "Quick Start", "hidden": false },
  { "anchor": "pricing",         "label": null,          "hidden": true  }
]
```

- **Array order is TOC order.** No `position` integers to keep consistent — reordering is a array reorder. Matches how the existing `_faq_row_fields.html.erb` posts `blog[faq_schema][][question]`; the TOC form posts `blog[toc_overrides][][anchor]` / `[][label]` / `[][hidden]`.
- **`anchor` is the merge key**, not array index — index is meaningless once reordering exists.
- **`label: null`** means "use the extracted heading text." Only store a deviation.
- Strong params: `toc_overrides: [:anchor, :label, :hidden]` — same nested-array shape already used for `faq_schema: [:question, :answer]` at `admin/blogs_controller.rb:53`.

### Merge algorithm (lives in the PORO, not the model)

```
extracted = headings(body)                       # ordered, authoritative set of anchors
overrides = toc_overrides                        # admin intent, ordered

1. Drop overrides whose anchor is no longer in `extracted`   (orphans from renamed headings)
2. Emit in override order, taking label/hidden from override, level from extracted
3. Append any extracted heading not present in overrides, in document order, defaults (visible, extracted label)
4. Filter out hidden: true
```

Consequence: renaming a heading silently reverts that one entry to auto-generated — degradation, not breakage. The admin form always re-renders from step 3's merged list, so the admin sees current reality rather than stale rows. This is why the merge must be shared between admin and public.

### Hierarchy vs. free reordering

H2/H3 nesting comes from `level` in `extracted`, and is used **only for indentation**. Reordering is flat — an admin can move an H3 away from its parent H2 and the indentation will look odd. Recommendation: accept this, don't build tree-constraint validation for a v1 marketing feature. If it becomes a real problem, restrict drag targets to same-level siblings later.

---

## Decision 3: Conditional two-column layout, TOC rendered exactly once

### The layout switch

`show.html.erb:28` is `max-w-4xl mx-auto`. Widening it unconditionally regresses every TOC-off post. Gate it:

```erb
<% toc = blog_toc_entries(@blog) %>
<% show_toc = @blog.toc_enabled? && toc.any? %>

<div class="<%= show_toc ? 'max-w-6xl' : 'max-w-4xl' %> mx-auto px-4 sm:px-6 lg:px-8">
  ...hero, title, image, excerpt (unchanged)...

  <% if show_toc %>
    <div data-controller="toc"
         class="lg:grid lg:grid-cols-[minmax(0,1fr)_16rem] lg:gap-12 lg:items-start">
      <%= render "table_of_contents", entries: toc %>   <%# lg:order-2, sticky %>
      <%= render "article_body", blog: @blog %>         <%# lg:order-1 %>
    </div>
  <% else %>
    <%= render "article_body", blog: @blog %>
  <% end %>
  ...faq, author card, share (unchanged)...
</div>
```

Note `minmax(0,1fr)` on the content column — without it, wide `<pre>`/`<table>` inside `prose` blow out the grid track. `lg:items-start` is required for `position: sticky` to work on the aside (a stretched grid item is full-height and never sticks).

TOC-off path is byte-identical to today's rendering. That is the zero-regression guarantee, enforced structurally rather than by careful CSS.

### Render the TOC **once**

Do not render a mobile partial and a desktop partial. Two renders means duplicate DOM `id`s, two `<nav>` landmarks for screen readers, and a scroll-spy controller whose `linkTargets` query matches both copies and highlights invisible elements.

One `<aside>`, positioned by CSS, with a Stimulus-toggled mobile panel:

```erb
<aside class="lg:order-2 mb-8 lg:mb-0 lg:sticky lg:top-8 lg:self-start lg:max-h-[calc(100vh-4rem)] lg:overflow-y-auto">
  <nav aria-labelledby="toc-heading">
    <button type="button" class="lg:hidden w-full flex justify-between …"
            data-action="toc#toggle"
            data-toc-target="toggle"
            aria-expanded="false" aria-controls="toc-panel">
      <span id="toc-heading">Contents</span>
      <svg …/>
    </button>
    <h2 id="toc-heading-desktop" class="hidden lg:block …">Contents</h2>

    <ol id="toc-panel" data-toc-target="panel" class="hidden lg:block …">
      <% entries.each do |e| %>
        <li class="<%= 'ml-4' if e.level == 3 %>">
          <a href="#<%= e.anchor %>" data-toc-target="link" data-anchor="<%= e.anchor %>"
             data-action="toc#jump"><%= e.label %></a>
        </li>
      <% end %>
    </ol>
  </nav>
</aside>
```

`hidden lg:block` + a Stimulus class toggle beats `<details>`/`<summary>`: `<details>`'s open state is a DOM property, not a CSS-addressable state, so a mobile user who collapses it and then rotates to landscape gets an invisible desktop sidebar. The Stimulus approach also gives correct `aria-expanded` bookkeeping for free.

### Single Stimulus controller on the grid wrapper

`data-controller="toc"` goes on the wrapper enclosing **both** the aside and the article, so the controller can reach headings via a `content` target without Stimulus outlets or global selectors.

```
targets: panel, toggle, link, content
```

- `toggle()` — flips `panel` visibility + `aria-expanded`
- `jump(event)` — `preventDefault`, `scrollIntoView({ behavior, block: "start" })`, close the mobile panel, and `history.replaceState` the hash (so the URL is shareable without a second jump)
- `connect()` — build the IntersectionObserver

---

## Scroll-spy: the pattern that actually works

The naive `scroll` listener from the Avo tutorial fires on every scroll event and forces layout with `getBoundingClientRect()` per heading — jank on long posts. Use IntersectionObserver, with the two known correctness fixes ([tj.ie](https://tj.ie/building-a-table-of-contents-with-the-intersection-observer-api/), [benfrain.com](https://benfrain.com/building-a-table-of-contents-with-active-indicator-using-javascript-intersection-observers/)):

```js
connect() {
  this.headings = [...this.contentTarget.querySelectorAll("h2[id], h3[id]")]
  this.visible = new Set()

  this.observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((e) =>
        e.isIntersecting ? this.visible.add(e.target.id) : this.visible.delete(e.target.id)
      )
      // FIX 1: many headings visible at once -> last in document order wins
      const active = this.headings.filter((h) => this.visible.has(h.id)).at(-1)
      // FIX 2: nothing visible (scrolled past the last heading) -> keep previous
      if (active) this.lastActive = active.id
      this.#highlight(this.lastActive)
    },
    { rootMargin: "0px 0px -66% 0px", threshold: 0 }
  )
  this.headings.forEach((h) => this.observer.observe(h))
}

disconnect() { this.observer?.disconnect() }   // required — Turbo caches and restores pages
```

- **`rootMargin: "0px 0px -66% 0px"`** shrinks the observation band to the top third of the viewport, so "active" tracks reading position rather than "anywhere on screen."
- **`disconnect()` is mandatory.** Turbo Drive is active (`@hotwired/turbo-rails`); without it, observers leak across navigations. The existing `cookie_consent_controller.js` is the local reference for lifecycle discipline.
- **`scroll-margin-top`:** verified *not* needed for the site header (`_navigation.html.erb:1` is `relative`, not sticky). It **is** needed if the mobile "Contents" bar is made sticky — add `scroll-mt-20` to headings inside `prose` via a Tailwind arbitrary variant, not by touching the sanitizer.
- **Reduced motion:** `behavior: matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth"`.

---

## Data Flow

### Public read path (TOC enabled)

```
GET /blog/:slug
     │
     ▼
BlogsController#show ──▶ @blog (body: sanitized HTML, toc_enabled: true, toc_overrides: [...])
     │
     ▼
show.html.erb ──▶ blog_toc_entries(@blog) ──┐
     │                                      │
     │            ┌─────────────────────────▼──────────────────────────┐
     │            │ Blog::TableOfContents.new(@blog)                   │
     │            │                                                    │
     │            │  1. sanitize(body, ALLOWED_TAGS, ALLOWED_ATTRS)    │  ← sanitize FIRST
     │            │  2. Nokogiri::HTML5.fragment(...)                  │
     │            │  3. css("h2,h3") -> parameterize -> dedupe         │  ← inject SECOND
     │            │     -> node["id"] = anchor                         │     (machine-generated,
     │            │  4. extracted = [{anchor, label, level}, ...]      │      never admin input)
     │            │  5. merge(extracted, toc_overrides)                │
     │            │       drop orphans / apply label+hidden / append new│
     │            │                                                    │
     │            │  #entries   -> [Entry]      #body_html -> String   │
     │            └───────┬─────────────────────────────┬──────────────┘
     │                    │                             │
     ▼                    ▼                             ▼
show.html.erb    _table_of_contents.html.erb    _article_body.html.erb
(grid wrapper)   <nav><a href="#anchor">        <div class="prose">
                                                  <h2 id="anchor">
     │                    │                             │
     └────────────────────┴──── data-controller="toc" ──┘
                                        │
                                        ▼
                          IntersectionObserver observes h2[id]/h3[id]
                          -> toggles .active on matching link
                          Click -> preventDefault -> smooth scrollIntoView
```

### Public read path (TOC disabled — the regression guard)

```
GET /blog/:slug ──▶ @blog.toc_enabled? == false
                          │
                          ▼
              render "article_body" only
              sanitize(@blog.body, ...)      ← identical to today's show.html.erb:76
              No Nokogiri. No grid. No Stimulus. max-w-4xl.
```

### Admin write path

```
Admin edit form
     │
     ├─▶ tiptap_editor_controller.js  ──▶ blog[body]        (existing, untouched)
     │
     ├─▶ checkbox                     ──▶ blog[toc_enabled]
     │
     └─▶ toc_builder_controller.js    ──▶ blog[toc_overrides][][anchor]
             (reorder / relabel /              [][label]
              hide rows)                       [][hidden]
                │
                ▼
        Admin::BlogsController#update
          blog_params.permit(..., :toc_enabled, toc_overrides: [:anchor, :label, :hidden])
                │
                ▼
        Blog#save
          before_save :sanitize_body          (existing)
          before_save :normalize_toc_overrides (NEW — reject blank anchors, cast hidden to bool,
                                                nil out labels equal to extracted text)
                │
                ▼
          blogs.toc_overrides (jsonb)
```

Note the asymmetry, and it is deliberate: **overrides never touch `body`.** The body is the authoring surface; overrides are a presentation-layer annotation. That boundary is what makes the merge safe to re-run on every render.

### Admin form render path (why the PORO must be shared)

```
Admin edit form load
     │
     ▼
Blog::TableOfContents.new(@blog).entries    ← SAME call the public page makes
     │
     ▼
_toc_row_fields.html.erb per entry
  hidden field: anchor (locked, not user-editable)
  text field:   label (placeholder = extracted heading text)
  checkbox:     hidden
  drag handle:  reorder
```

If the admin form computed anchors differently from the public page — even slightly — override rows would key on anchors that don't exist in the rendered body and silently do nothing. One PORO, one algorithm.

---

## Recommended Project Structure

```
app/
├── models/
│   ├── blog.rb                         # + toc? predicate, + normalize_toc_overrides
│   └── blog/
│       └── table_of_contents.rb        # NEW — Blog::TableOfContents PORO
│                                       #   Entry = Data.define(:anchor, :label, :level, :hidden)
├── helpers/
│   └── blogs_helper.rb                 # NEW content (currently empty module)
│                                       #   blog_toc_entries(blog), blog_body_with_anchors(blog)
├── controllers/
│   └── admin/blogs_controller.rb       # MODIFIED — blog_params
├── views/
│   ├── blogs/
│   │   ├── show.html.erb               # MODIFIED — conditional grid wrapper
│   │   ├── _table_of_contents.html.erb # NEW
│   │   └── _article_body.html.erb      # NEW (extracted from show.html.erb:75-77)
│   └── admin/blogs/
│       ├── _form.html.erb              # MODIFIED — TOC <details> section
│       └── _toc_row_fields.html.erb    # NEW (mirrors _faq_row_fields.html.erb)
├── javascript/controllers/
│   ├── toc_controller.js               # NEW — scroll-spy + smooth scroll + mobile collapse
│   ├── toc_builder_controller.js       # NEW — admin reorder/hide (mirrors faq_builder)
│   └── index.js                        # MODIFIED — register both
db/migrate/
└── XXXX_add_toc_to_blogs.rb            # NEW — toc_enabled bool, toc_overrides jsonb
spec/
├── models/blog/table_of_contents_spec.rb   # NEW — the highest-value spec file in the milestone
└── ...
```

### Structure Rationale

- **`app/models/blog/table_of_contents.rb`, not `app/services/`.** `app/services/` currently holds `Telegram` — external-integration wrappers. TOC generation is Blog domain logic. Zeitwerk resolves `Blog::TableOfContents` from this path with `blog.rb` as the namespace-defining file — standard Rails 8, no config needed. Nesting also signals STI-safety: it works identically for `Article`.
- **`Data.define` for entries, not Hash.** Ruby 3.4 is available. `entry.anchor` fails loudly on typos; `entry[:anchor]` returns `nil` and renders an empty TOC link. The merge logic is the one place in this feature where a silent `nil` is expensive.
- **`_article_body.html.erb` extracted even though it's three lines.** It is rendered from two branches of the layout conditional. Duplicating the `sanitize` call in both branches is how the TOC-off path eventually drifts from the TOC-on path.
- **Helper as adapter, not logic.** `BlogsHelper` memoizes and delegates. Business logic in helpers is untestable in isolation and unreachable from the admin form.

---

## Architectural Patterns

### Pattern 1: Derive-don't-store for presentation data

**What:** The TOC and anchor IDs are never persisted. Only the *admin's deviations* (`toc_overrides`) and the *toggle* (`toc_enabled`) are stored. Everything else is recomputed from `body` on every render.

**When to use:** When the derived artifact is cheap to compute (verified: 2.5 ms worst case), and its source can change independently.

**Trade-offs:**
- (+) No staleness class of bug. No backfill migration. No `body` rewrite on historical posts.
- (+) The `faq_schema` before_save reconciliation pattern (30 lines in `blog.rb`) is not repeated.
- (−) Per-request CPU. Mitigable with `cache @blog` (`cache_key_with_version` already invalidates on `updated_at`) if a post ever gets large enough to matter. Not needed at current scale.

### Pattern 2: Sanitize-then-augment (never augment-then-sanitize)

**What:** Every HTML transformation happens strictly after `Rails::Html::SafeListSanitizer`, and only ever *adds* machine-generated attributes.

**Why it matters here:** It lets the feature ship without touching `ALLOWED_ATTRIBUTES`, which means no new XSS or DOM-clobbering surface. The invariant that makes the final `.html_safe` honest is: *input was sanitized, and the only mutation was setting `id` to a `parameterize`d string.*

```ruby
def body_html
  return blog.body if blog.body.blank?
  fragment.to_html.html_safe   # fragment was built from sanitize(...) output
end
```

Document this invariant in a comment at the `.html_safe` call site. It is the one place in the feature where a future refactor could introduce a vulnerability, and Brakeman (already in the Gemfile) will flag it — the comment is what lets the next reader confirm the flag is a false positive.

### Pattern 3: Merge-by-stable-key with graceful orphan handling

**What:** Overrides key on `anchor`, and orphaned overrides are dropped silently rather than raising or rendering a dead link.

**Trade-off:** Renaming a heading loses its override. Accepted because the alternative — persisting IDs through the editor to make them rename-proof — requires a custom Tiptap Heading extension *and* widening the sanitizer allowlist. Two structural risks to protect against a rare authoring action with a mild, self-correcting failure mode.

**Flag for a later milestone:** if heading renames turn out to be common in practice, the upgrade path is a custom Tiptap `id` attribute + allowlist entry + save-time backfill. Design the PORO so the ID source is one swappable method (`anchor_for(node, index)`) to keep that path cheap.

---

## Anti-Patterns

### Anti-Pattern 1: `Nokogiri::HTML()` on a fragment

**What people do:** Copy `Nokogiri::HTML(self.content)` from the Avo tutorial.
**Why it's wrong:** Verified locally — `Nokogiri::HTML("<h2>Intro</h2><p>hi</p>").to_html` returns `<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN" …><html><body>…</body></html>`. Serializing that back into the page injects a DOCTYPE and a nested `<html>` mid-document.
**Do this instead:** `Nokogiri::HTML5.fragment(body)` — verified to round-trip `<h2>Intro</h2><p>hi</p>` byte-identically.

*(Same tutorial also contains `heading.parameterize` where `heading` is a Nokogiri node — needs `heading.text.parameterize`. Treat that source as directionally useful, not copy-pasteable.)*

### Anti-Pattern 2: Rendering the TOC partial twice for mobile and desktop

**What people do:** `render "toc_mobile"` above the article and `render "toc_sidebar"` beside it, each with `lg:hidden` / `hidden lg:block`.
**Why it's wrong:** Duplicate `id="toc-panel"`, two `<nav>` landmarks announced to screen readers, and `linkTargets` matching 2× the links — the scroll-spy highlights elements in the hidden copy.
**Do this instead:** One `<aside>`, one `<nav>`. Move it with grid `order` and control the mobile collapse with a Stimulus class toggle.

### Anti-Pattern 3: Adding `id` to `ALLOWED_ATTRIBUTES` to "make anchors work"

**What people do:** The one-line fix — append `id` to `Blog::ALLOWED_ATTRIBUTES` (`blog.rb:8`).
**Why it's wrong:** It makes `id` admin-authorable on all 30+ allowed tags, creating a DOM-clobbering surface, *and* it still doesn't produce stable IDs because Tiptap's Heading node drops unknown attributes on round-trip. Cost incurred, benefit not delivered.
**Do this instead:** Generate IDs after sanitization. The allowlist stays exactly as it is.

### Anti-Pattern 4: A `blog_toc_entries` table

**What people do:** Model TOC entries as rows so they're "properly relational."
**Why it's wrong:** Entries are derived from `body`, so every body save must diff-and-sync the table. That sync is the staleness bug the whole design avoids, reintroduced with extra migration and N+1 risk. No query ever needs these rows independently.
**Do this instead:** `jsonb` column holding only the deviations.

### Anti-Pattern 5: `text` column holding a JSON string

**What people do:** Copy the `faq_schema` shape for consistency.
**Why it's wrong:** It's ~30 lines of custom writer + before_save parser + rescuing reader in `blog.rb` to emulate `jsonb`. `keywords` on the same table already demonstrates the better pattern in 2 lines.
**Do this instead:** `t.jsonb :toc_overrides, default: [], null: false`.

### Anti-Pattern 6: Widening `max-w-4xl` unconditionally

**What people do:** Change `show.html.erb:28` to `max-w-6xl` and let the sidebar column collapse when there's no TOC.
**Why it's wrong:** Every existing TOC-off post gets a wider measure and different line-lengths — a visible regression across the whole blog, violating an explicit requirement.
**Do this instead:** Branch the container class on `show_toc`. Keep the off-path structurally identical to today.

### Anti-Pattern 7: `scroll` event listener scroll-spy

**What people do:** `window.addEventListener("scroll", …)` calling `getBoundingClientRect()` on every heading.
**Why it's wrong:** Forced synchronous layout on every scroll tick. Also, the common `.bind(this)` idiom creates a *new* function reference, so the matching `removeEventListener` in `disconnect()` removes nothing — a real leak under Turbo Drive.
**Do this instead:** IntersectionObserver with an explicit `disconnect()`.

### Anti-Pattern 8: Assuming `parameterize` always yields a slug

**What people do:** `node["id"] = node.text.parameterize`.
**Why it's wrong:** Verified — `"日本語テスト".parameterize == ""`. A heading that is CJK, emoji-only, or an image produces `id=""`. Two such headings produce duplicate empty IDs and the TOC links go nowhere.
**Do this instead:** `.presence || "section-#{index + 1}"`, plus the occurrence-count dedupe suffix.

---

## Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `Blog` ↔ `Blog::TableOfContents` | PORO takes the Blog, reads `body` + `toc_overrides` | One-way. The PORO never writes to the model — keeps it trivially testable and safe to call from views |
| `BlogsHelper` ↔ PORO | Helper instantiates + memoizes per request | Helper contains no logic; both `entries` and `body_html` come from one PORO instance so the fragment is parsed once |
| Admin form ↔ PORO | Admin form calls the **same** `#entries` | Non-negotiable — divergent anchor algorithms produce silently-dead overrides |
| Public view ↔ `toc_controller.js` | `data-controller` on grid wrapper; `data-toc-target` on panel/link/toggle/content | Controller scoped to the wrapper — no `document.querySelector`, works if a page ever renders two articles |
| `toc_controller.js` ↔ headings | Queries `h2[id], h3[id]` within `contentTarget` | Depends on the `id` injection contract. The `[id]` filter is deliberate: skips any heading the PORO didn't process |
| `Blog` ↔ `Article` (STI) | Inherited | Migration on `blogs` covers both; PORO is class-agnostic. Confirm `Article`'s public rendering path if it has its own views |
| Public `.md` format ↔ TOC | None | `render_blog_markdown` reads `@blog.body` (no IDs, never mutated). Verified no leakage into llms.txt-facing output |

---

## Suggested Build Order

Dependency-ordered. Steps 1 and 2 are parallelizable; everything else is serial.

| # | Component | Depends on | Why this position |
|---|-----------|------------|-------------------|
| 1 | `Blog::TableOfContents` PORO + specs | — | Pure Ruby, no UI, no schema. The anchor-ID contract every other component references. Specs must cover: duplicate headings, empty-parameterize fallback, H2/H3 levels, empty body, body with no headings, HTML5-fragment round-trip fidelity |
| 2 | Migration (`toc_enabled`, `toc_overrides`) + `Blog#toc?` + `normalize_toc_overrides` | — | Independent of #1. No backfill, no data rewrite |
| 3 | Public render: `blogs_helper`, `_article_body`, `_table_of_contents`, `show.html.erb` grid | 1, 2 | First demoable vertical slice — auto-TOC works end-to-end with empty overrides (merge no-ops). Validates the layout switch and the zero-regression guarantee before any admin surface exists |
| 4 | `toc_controller.js` + `index.js` registration | 3 | Needs real anchored headings in the DOM to develop against |
| 5 | Admin: strong params, `_form` TOC section, `_toc_row_fields`, `toc_builder_controller.js` | 1, 2, 3 | The override UI must render rows keyed by the *actual* anchors #1 produces, and its effect is only observable once #3 renders them |
| 6 | Reading-UX / typography pass | 3, 4 | Type scale and rhythm depend on the final measure, which differs between the 1-col and 2-col layouts. Doing this before the layout switch means doing it twice |

**Critical ordering constraint:** #5 cannot precede #1. The admin override UI stores `anchor` keys; if those keys aren't produced by the same algorithm the public page uses, every override is a silent no-op and the bug is invisible until someone checks a rendered post.

**Suggested phase boundaries:** (1+2) foundation → (3+4) public reading experience → (5) admin control → (6) polish. Each boundary is independently shippable: after (3+4) the feature works with auto-generated TOC and the toggle flipped in console/rails c; after (5) marketing owns it.

---

## Scaling Considerations

| Scale | Adjustments |
|-------|-------------|
| Current (tens of posts, low traffic) | None. 2.5 ms worst-case parse is noise next to the existing `@related_blogs` queries in `BlogsController#show` |
| Hundreds of posts / meaningful traffic | Wrap the TOC-on branch in `<% cache @blog do %>` — `cache_key_with_version` already invalidates on `updated_at`. `solid_cache` is configured and unused by views today |
| Very long posts (100+ headings) | Cap TOC depth at H2/H3 (already the plan) and consider `lg:max-h-[calc(100vh-4rem)] lg:overflow-y-auto` on the aside — already in the recommended markup |

**First bottleneck:** not the Nokogiri parse — it's the unbounded `IntersectionObserver` callback firing on every entry change if `threshold` is set to an array instead of `0`. Keep it at `0`.

---

## Confidence Assessment

| Claim | Confidence | Basis |
|-------|------------|-------|
| `id` stripped by current allowlist; double sanitization | HIGH | Read `blog.rb:8,130` + `show.html.erb:76`; executed sanitizer locally |
| `parameterize` returns `""` for CJK | HIGH | Executed locally with ActiveSupport |
| `Nokogiri::HTML()` wraps fragments in DOCTYPE/html/body | HIGH | Executed locally, Nokogiri 1.19.2 (lockfile pins 1.18.10 — same behavior) |
| 2.5 ms parse+inject on 65 KB body | HIGH | Benchmarked locally, 200 iterations |
| Site header is `relative`, not sticky | HIGH | Read `_navigation.html.erb:1` |
| `@tiptap/extension-table-of-contents` is MIT | HIGH | `npm view` + extracted `LICENSE.md` from the published tarball (npm metadata says "SEE LICENSE IN LICENSE.md" — misleading; actual file is MIT) |
| Tiptap StarterKit Heading drops unknown `id` attributes on round-trip | MEDIUM | ProseMirror schema semantics + `tiptap_editor_controller.js:25` showing no Heading attribute config. Not empirically tested in this app — **worth a 5-minute manual check before finalizing Decision 1**, though the recommendation holds either way |
| IntersectionObserver last-section / multiple-visible fixes | MEDIUM | Multiple independent write-ups agree (tj.ie, benfrain.com, chriskirknielsen.com); pattern is well-established but not from an official spec source |
| `rootMargin: "0px 0px -66% 0px"` is the right band | LOW | Starting value from community write-ups; tune against the actual reference UX during implementation |
| views4you.com reference behaves as described | LOW | Site returns HTTP 403 to automated fetch (noted in PROJECT.md); relying on the user's description |

---

## Sources

- Codebase (primary, HIGH): `app/models/blog.rb`, `app/views/blogs/show.html.erb`, `app/controllers/admin/blogs_controller.rb`, `app/views/admin/blogs/_form.html.erb`, `app/views/admin/blogs/_faq_row_fields.html.erb`, `app/javascript/controllers/faq_builder_controller.js`, `app/javascript/controllers/tiptap_editor_controller.js`, `app/views/shared/_navigation.html.erb`, `db/schema.rb`, `Gemfile.lock`, `package.json`
- Local execution (HIGH): `Rails::Html::SafeListSanitizer` attribute stripping, `String#parameterize` unicode behavior, `Nokogiri::HTML5.fragment` vs `Nokogiri::HTML`, parse+inject benchmark
- [Tiptap TableOfContents extension docs](https://tiptap.dev/docs/editor/extensions/functionality/table-of-contents) via Context7 `/ueberdosis/tiptap-docs` (HIGH) — `getId`, `generateTocIds`, anchor object shape. Evaluated and rejected in favor of server-side extraction: the public page loads no Tiptap bundle, and client-only TOC would leave existing posts and no-JS/crawler rendering without anchors.
- [Dynamic Table of Contents with Rails and Nokogiri — Avo](https://avohq.io/blog/dynamic-table-of-contents-rails) (MEDIUM) — useful structure, but contains two bugs called out above (`Nokogiri::HTML` on a fragment; `heading.parameterize` on a node) and its `before_save` approach is wrong for this codebase
- [Building a Table of Contents with the Intersection Observer API — tj.ie](https://tj.ie/building-a-table-of-contents-with-the-intersection-observer-api/) (MEDIUM)
- [Building a TOC with active indicator using IntersectionObservers — benfrain.com](https://benfrain.com/building-a-table-of-contents-with-active-indicator-using-javascript-intersection-observers/) (MEDIUM)
- ["Simple" Table of Contents Highlighter — chriskirknielsen.com](https://chriskirknielsen.com/blog/simple-table-of-contents-highlighter/) (MEDIUM)

---
*Architecture research for: blog Table of Contents / reading UX (Rails 8 + Hotwire)*
*Researched: 2026-08-01*
