# Stack Research

**Domain:** Server-rendered Rails blog — auto-generated Table of Contents, heading anchors, scroll-spy, sticky/collapsible TOC UI
**Researched:** 2026-08-01
**Confidence:** HIGH (server-side verified empirically against this repo's actual gem versions; client-side verified against MDN/caniuse)

## Headline Recommendation

**Add zero new npm packages and zero new gems.** Everything this feature needs is already in the dependency tree: Nokogiri (transitive via `loofah`/`rails-html-sanitizer`), Stimulus 3.2.2, native `IntersectionObserver`, native `<details>`, and Tailwind v4 utilities.

The whole feature is: **one Ruby service object + one jsonb column + one boolean column + one Stimulus controller + one ERB partial.**

The single most important architectural decision: **generate heading `id`s server-side, *after* sanitization, from machine-derived slugs — never allow `id` through the sanitizer allowlist.**

---

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **Nokogiri** (`Nokogiri::HTML5.fragment`) | 1.18.10 locked (1.19.4 current) | Parse sanitized `blogs.body`, extract `h2`/`h3`, inject anchor `id`s, re-serialize | Already in `Gemfile.lock` as a transitive dep of `loofah`. `Nokogiri::HTML5` uses the gumbo parser, matching browser HTML5 tree construction — so the DOM the server builds IDs against is the same DOM the browser will build. Regex/`gsub` heading extraction is not an option on author-supplied HTML. Verified present and working on this repo: `defined?(Nokogiri::HTML5) # => true` on CRuby 3.4.2. |
| **`Rails::HTML5::SafeListSanitizer`** | rails-html-sanitizer 1.6.2 locked (1.7.1 current) | Existing `Blog#sanitize_body` allowlist enforcement | Already a dependency. See "Sanitization pipeline" below — the allowlist must stay as-is (no `id`), and IDs get injected *downstream* of it. **Note:** the model currently calls `Rails::Html::SafeListSanitizer`, which I verified resolves to `Rails::HTML4::SafeListSanitizer` (libxml2 parser), while `config.load_defaults 8.0` makes the *view* `sanitize` helper use the HTML5 vendor. See "Version Compatibility" for the mismatch. |
| **PostgreSQL `jsonb` column** | PG (existing) | Store the derived TOC entry list + admin overrides (`toc_entries`) | `blogs.keywords` is already `jsonb, default: [], null: false` — the pattern is proven in this schema. jsonb gives you a stable, queryable, order-preserving array of `{id, level, text, label, hidden}` hashes without a second table or a `blog_toc_entries` model. Avoids the `faq_schema` mistake of storing JSON in a `text` column and re-parsing with `JSON.parse` rescue blocks. |
| **Stimulus** | `@hotwired/stimulus` 3.2.2 (latest — already installed) | `toc_controller.js`: scroll-spy, smooth-scroll on click, active-item state, mobile dropdown state | Project constraint is Rails/Stimulus/esbuild. 3.2.2 is the current published latest (verified on npm 2026-08-01), so no upgrade needed. Follow the existing `faq_builder_controller.js` house style (thin, targets-based, no external deps). |
| **`IntersectionObserver`** | Native browser API (Baseline, universal) | Scroll-spy active-section detection | Runs intersection checks off the main thread; no scroll-event throttling, no `getBoundingClientRect()` layout thrash per frame. The standard 2025/2026 answer. Baseline-available in every browser this site targets. |
| **`<details>` / `<summary>`** | Native HTML | Mobile "Contents" collapsible dropdown | Zero JS, keyboard-accessible and screen-reader-announced by default, and the open/closed state is CSS-targetable via `details[open]` / `details:not([open])`. Ship the dropdown as `<details>` and use CSS to present it as a plain sticky list at `md:`+ widths. A hand-rolled Stimulus toggle re-implements focus, `aria-expanded`, and Escape handling for no gain. |
| **Tailwind CSS v4** | 4.1.14 locked (4.3.3 current) | Sticky sidebar layout, scroll offset, active-item styling | `scroll-mt-*` (maps to `scroll-margin-top`) on headings is the correct fix for "anchor lands under the sticky header." `sticky top-24 self-start max-h-[calc(100dvh-8rem)] overflow-y-auto overscroll-contain` is the sidebar recipe. No config change needed. |
| **`@tailwindcss/typography`** | 0.5.19 locked (0.5.20 current) | Existing `.prose` article body styling | Already applied to the body wrapper in `app/views/blogs/show.html.erb`. Heading `scroll-mt` must be applied via a `prose` modifier (`prose-headings:scroll-mt-24`) or a plain CSS rule in `application.tailwind.css` alongside the existing `.prose-paragraph-relaxed` rule — the typography plugin's generated heading styles will otherwise win on specificity for margins but not for `scroll-margin-top`. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `ActiveSupport::Inflector#parameterize` | Rails 8.0.3 (built in) | Slugify heading text into anchor ids | Always. Already used by `Blog#generate_slug`. **Must be wrapped** — see "Slug generation" below; it returns `""` for CJK and emoji headings (empirically verified in this repo). |
| Rails fragment caching (`cache` helper / `Rails.cache`) | Rails 8.0.3 + `solid_cache` 1.0.7 (installed) | Cache the anchor-injected body HTML if you compute at render time | Only if you choose render-time injection over save-time persistence. Benchmarked cost is small (see below) but a 30-heading/100 KB post still burns ~3 ms of CPU per request for no reason. |
| `Nokogiri::HTML5.fragment` (not `HTML4`) | 1.18.10 | The parse call itself | Always for this feature. HTML4/libxml2 will silently restructure some author markup differently from the browser, which can desync server-generated ids from the client DOM. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| esbuild | Bundles the new `toc_controller.js` | 0.25.10 locked (0.28.1 current). No config change — `app/javascript/controllers/*` is already in the bundle graph via `controllers/index.js`. |
| `bin/rails stimulus:manifest:update` | Registers the new controller | `controllers/index.js` is auto-generated and carries that header comment. Run it rather than hand-editing. |
| RSpec + Capybara + selenium-webdriver | Test TOC generation (unit) and scroll-spy (system) | 7.1.1 / 3.40.0 / 4.36.0 installed. Unit-test the slug/dedupe/override-merge logic hard; system-test only the smoke path (TOC renders, click scrolls, `aria-current` moves) — scroll-spy timing is flaky in headless. |
| Brakeman 7.1.0 | Verify the `raw`/`html_safe` call introduced by anchor injection | It **will** flag the new unescaped output. Budget for either a justified inline comment or restructuring so the sanitize-then-inject order is provable. |

## Installation

```bash
# Core — nothing to install. Everything is already in Gemfile.lock / package.json.

# OPTIONAL: promote Nokogiri from transitive to explicit dependency.
# Recommended, because this feature makes Nokogiri a direct, load-bearing
# dependency of application code rather than an implementation detail of loofah.
#   Gemfile:  gem "nokogiri", "~> 1.18"
bundle install

# OPTIONAL, unrelated to this feature: pick up current patch versions
#   nokogiri 1.18.10 -> 1.19.4, rails-html-sanitizer 1.6.2 -> 1.7.1, loofah 2.24.1 -> 2.25.2
# Not required. 1.6.2 already contains the Dec-2024 XSS fixes; 1.7.x only adds
# Rails::HTML::Sanitizer.allowed_uri?. Do this as separate maintenance, not inside this milestone.
bundle update nokogiri rails-html-sanitizer loofah

# npm: nothing. No TOC library, no scroll-spy library, no stimulus-use.
```

---

## The Sanitization Pipeline (the load-bearing decision)

**Confidence: HIGH — empirically verified against this repo's installed gems.**

Current state, verified by running the actual `Blog::ALLOWED_TAGS`/`ALLOWED_ATTRIBUTES` through `Rails::Html::SafeListSanitizer`:

```
input:  <h2 id="evil" onclick="alert(1)">Hello World</h2>
output: <h2>Hello World</h2>
```

The existing sanitizer already strips author-supplied `id`. **Keep it that way.**

### Do NOT add `id` to `Blog::ALLOWED_ATTRIBUTES`

Allowing `id` through the allowlist means a marketing-team author (or anyone who compromises an admin account) controls arbitrary DOM ids on a public page. That is a live **DOM clobbering** vector: attacker-chosen ids shadow properties on `window` and `document` (`id="body"`, duplicate ids forming an `HTMLCollection`, etc.), which turns "harmless attribute" into an XSS primitive when combined with any script that reads a global by name. This is exactly why DOMPurify ships `SANITIZE_DOM` on by default and why the WICG Sanitizer API explicitly does *not* claim DOM-clobbering protection unless configured to drop `id`/`name`. Don't reopen that door for a cosmetic feature.

### Correct order of operations

```
1. Author submits HTML from Tiptap
2. Blog#sanitize_body            → allowlist enforced, ALL author ids destroyed
3. TocGenerator parses the *sanitized* string with Nokogiri::HTML5.fragment
4. Inject id="toc-<machine-slug>" on each h2/h3
5. Serialize → this string is safe to render without re-sanitizing
```

Because step 4 runs on already-sanitized markup and writes values from a slug function whose output character class is `[a-z0-9-]` plus a fixed `toc-` prefix, no author-controlled string ever reaches an `id`. The `toc-` prefix additionally namespaces the ids away from any global/DOM property name, closing the clobbering vector by construction.

### CRITICAL: the show view currently strips ids

`app/views/blogs/show.html.erb` line ~78 re-sanitizes at render time:

```erb
<%= sanitize @blog.body, tags: Blog::ALLOWED_TAGS, attributes: Blog::ALLOWED_ATTRIBUTES %>
```

`ALLOWED_ATTRIBUTES` has no `id`, so **any anchor ids persisted into `body` will be silently deleted at render.** Whichever generation strategy you pick, this line must change. Two safe shapes:

- **Preferred (render-time injection):** `<%= raw toc_anchored_body(@blog) %>` where the helper does `sanitize(...)` → Nokogiri inject → return. Sanitization still happens; the injection just happens *after* it, inside the helper. The only unescaped output is a string this helper produced.
- **Acceptable (save-time persistence):** store the anchored HTML in a derived `body_html` column, and render it with an explicit second allowlist that adds `id`: `sanitize @blog.body_html, tags: Blog::ALLOWED_TAGS, attributes: Blog::ALLOWED_ATTRIBUTES + %w[id]`. This keeps a sanitize call in the view but reintroduces a (narrow) window where a stored id would pass through — safe only because `body_html` is machine-generated and never author-writable. Guard the column so it is not in `blog_params`.

Do **not** simply change `Blog::ALLOWED_ATTRIBUTES` — that constant is used by both the model's save-time pass and the view, so widening it widens the author-controlled surface too.

## Slug generation (verified edge cases)

`ActiveSupport::Inflector#parameterize` alone is not sufficient. Verified output on this repo:

| Heading text | `parameterize` result | Needed handling |
|---|---|---|
| `Hello <em>World</em> &amp; Friends!` | `hello-world-friends` | fine (use `node.text`, not `node.inner_html`) |
| `Ünïcödé — Ünïcödé` | `unicode-unicode` | fine (transliterates) |
| `日本語` | `""` | **blank → must fall back to `section-<index>`** |
| `🎉` | `""` | **blank → must fall back to `section-<index>`** |
| two identical `Hello World` headings | `hello-world` twice | **must dedupe with a `-2`, `-3` counter** |

Required slug function contract:

1. `heading.text.to_s.parameterize`
2. if blank → `"section-#{one_based_index}"`
3. dedupe against a `Hash.new(0)` seen-counter → append `-2`, `-3`, …
4. prefix `toc-`
5. truncate to a sane max (e.g. 80 chars) before the dedupe suffix

Duplicate ids are not just an aesthetic problem — they are the classic DOM-clobbering ingredient (duplicate ids coerce a property into an `HTMLCollection`), and they break `IntersectionObserver` → TOC-link mapping. Dedupe is mandatory, not nice-to-have.

## Generation timing: save-time persistence vs render-time

Benchmarked on this machine (Ruby 3.4.2, Nokogiri 1.18.10), a ~99 KB body with 30 `h2`s, full parse + id injection + serialize:

| Parser | Cost per render |
|---|---|
| `Nokogiri::HTML4.fragment` | 1.89 ms |
| `Nokogiri::HTML5.fragment` | 3.27 ms |

**Recommendation: persist at save time.** Not primarily for the 3 ms — for correctness of the admin-override feature.

The override requirement (relabel / reorder / hide individual entries) needs a **stable identity** to attach an override to. If the TOC is derived fresh on every render, there is nothing durable to key overrides against. Persist:

| Column | Type | Purpose |
|---|---|---|
| `toc_enabled` | `boolean, default: false, null: false` | Per-post opt-in. Default `false` satisfies the "zero regression on existing posts" constraint at the schema level, which is stronger than doing it in a view conditional. |
| `toc_entries` | `jsonb, default: [], null: false` | Ordered array of `{"id","level","text","label","hidden","position"}`. `text` = auto-extracted heading text (source of truth for detecting drift); `label` = admin override, `nil` means "use `text`". |
| `body_html` (optional) | `text` | Anchored body. Skip this and inject at render if you'd rather not carry a derived content column; then wrap the render in a fragment cache keyed on `[blog, blog.updated_at]`. |

Regenerate `toc_entries` in a `before_save` that runs **after** `sanitize_body` (Rails runs same-type callbacks in declaration order — declare it below the existing `before_save :sanitize_body`), merging by anchor id so existing overrides survive a body edit. Known and acceptable limitation to surface in the admin UI: **renaming a heading changes its slug and orphans its override.** Show orphaned overrides in the admin form rather than silently dropping them.

## Client-side approach

### Scroll-spy: `IntersectionObserver`, not scroll events

```
new IntersectionObserver(callback, { rootMargin: "0px 0px -66% 0px", threshold: 0 })
```

The negative bottom `rootMargin` shrinks the observation band to the top third of the viewport, so a heading becomes "active" once it has scrolled into the reading zone rather than the instant it peeks in from the bottom. Track intersecting headings in a `Set` and activate the **last** (lowest in document order) one; when the set empties (reader is mid-section, no heading on screen), keep the previously active entry rather than clearing — otherwise the highlight flickers off between headings.

Note that the most-cited Rails-specific writeup on this ([avohq.io](https://avohq.io/blog/dynamic-table-of-contents-rails)) uses **scroll event listeners**, not `IntersectionObserver`. Don't copy that part. Also note that post's `heading.parameterize` is calling `parameterize` on a Nokogiri node, not on its text, and it does no dedupe and no blank fallback — treat it as a shape reference, not a source.

### Smooth scroll + anchor offset

- Handle the click in the Stimulus controller: `target.scrollIntoView({ behavior: prefersReducedMotion ? "auto" : "smooth", block: "start" })`, then `history.pushState(null, "", "#" + id)` so the URL is shareable without a second jump.
- **Do not** set a global `html { scroll-behavior: smooth }`. It hijacks Turbo Drive's scroll restoration on every navigation and ignores motion preferences unless separately gated. Scoping the behavior to the click handler keeps the blast radius at one feature.
- Gate on `window.matchMedia("(prefers-reduced-motion: reduce)")` — WCAG 2.3.3 territory, and cheap.
- Offset the landing position with `scroll-margin-top` on the headings (Tailwind `scroll-mt-24`), **not** by fudging `scrollTo` math. `scroll-margin-top` also fixes direct deep-link loads (`/blog/foo#toc-bar`) and browser find-in-page, which JS offset math does not.
- After scrolling, move focus to the heading (`tabindex="-1"` + `.focus({ preventScroll: true })`) so keyboard and screen-reader users actually land in the section instead of keeping focus in the TOC.

### Accessibility

- Wrap in `<nav aria-label="Table of contents">` containing a real `<ul>/<li>` of `<a href="#toc-...">`. Screen readers then announce item count and list semantics. There is already a `<nav>` on the page, so the `aria-label` is required to disambiguate landmarks.
- Mark the active entry with `aria-current="location"` (the correct token for "current position within a page"), not `aria-current="true"`.
- Active state must not be colour-only — pair the accent colour with a left border/weight change.
- Use `<details>/<summary>` for the mobile disclosure. Caveat from the accessibility literature: if you remove the default `::marker` disclosure triangle, VoiceOver/JAWS/NVDA become inconsistent about announcing expanded/collapsed state — so if you restyle the marker away, add an explicit visual+`aria`-backed indicator.

### Turbo lifecycle

`observer.disconnect()` **must** be called in the Stimulus controller's `disconnect()`, along with removal of any listener attached outside `this.element` (e.g. a `matchMedia` change listener). Turbo Drive snapshots the DOM at `turbo:before-cache` — *before* `disconnect()` runs — so also strip transient active-state classes in a `beforeCache` hook if you don't want a stale highlight flashing on cached back-navigation. Every scroll-spy implementation that skips this leaks an observer per visit.

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Server-side Nokogiri extraction | Client-side DOM parsing in the Stimulus controller (`this.articleTarget.querySelectorAll("h2, h3")`) | Only if the TOC were purely automatic with no admin override, no SEO/no-JS requirement, and no deep-link stability requirement. **None of those hold here** — admin override needs a persisted entry list, and heading anchors need to exist in the served HTML for `/blog/foo#toc-bar` links and crawler-visible in-page anchors. |
| `Nokogiri::HTML5.fragment` | `Nokogiri::HTML4.fragment` | If you measure the 1.4 ms delta as material at your traffic (you won't) *and* your body HTML is simple enough that HTML4 and HTML5 tree construction can't diverge. Not worth the risk of server/client DOM desync. |
| Nokogiri | Nokolexbor (4.7× faster parse, 1352× faster CSS selectors) | Genuinely faster, but it's an additional native extension to build into the `ruby:3.4.2-slim` Dockerfile for a 3 ms/save operation. Revisit only if TOC generation ever moves to a hot render path over thousands of posts. |
| jsonb `toc_entries` column | Separate `blog_toc_entries` table with a real model | If TOC entries ever need their own validations, per-entry timestamps, or to be queried/joined across posts (e.g. "find all posts with a section about X"). Not in scope. |
| `<details>/<summary>` for mobile | Stimulus-toggled div with `aria-expanded` | If the design requires an animated max-height transition that `::details-content` can't yet deliver consistently across the browser matrix. Accept the extra a11y wiring cost if so. |
| `IntersectionObserver` | CSS `scroll-target-group: auto` + `:target-current` | This is genuinely the "2026 native answer" and needs literally two lines of CSS — but it's **Chromium-only** (Chrome/Edge 140+), Firefox and Safari have zero support, and caniuse puts global coverage at **66.39%**. It is a legitimate *progressive enhancement* on top of the IntersectionObserver implementation, but shipping both means two active code paths that must agree. **Recommendation: don't ship it in this milestone.** Note it as a future simplification once it reaches Baseline. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| **tocbot** (4.36.8, ~989K weekly downloads) | Actively maintained and popular, but architecturally wrong here: it builds the TOC *from the rendered DOM on the client*, which makes the admin override (relabel/reorder/hide) impossible to express, produces no TOC in the served HTML, and adds a bundle for logic that is ~60 lines. | Server-generated `toc_entries` + a ~70-line Stimulus controller. |
| Any other client-side TOC lib (`tocjs`, `toc.js`, jQuery plugins) | Same structural problem as tocbot, plus most are unmaintained and several assume jQuery. | Same as above. |
| **`stimulus-use`'s `useIntersection`** (0.53.0) | Instantiates one `IntersectionObserver` per element and is designed for "is *this* controller's element visible" — the inverse of what scroll-spy needs (one observer, N targets, ordering-aware callback). Adds a dependency to save ~6 lines. | Instantiate `IntersectionObserver` directly in the controller. |
| **`scroll` event + throttle/debounce** (incl. `lodash.throttle`) | Forces `getBoundingClientRect()` per tick on the main thread during the exact moment the user is scrolling; causes jank on long posts and burns battery. This is what the pre-2019 tutorials (and the avohq.io Rails post) do. | `IntersectionObserver`. |
| **Adding `id` to `Blog::ALLOWED_ATTRIBUTES`** | Hands arbitrary DOM ids to content authors → DOM clobbering / XSS primitive, and duplicate-id hazards. Also widens the surface for *every* consumer of that constant, not just the TOC. | Machine-generate `toc-`-prefixed ids downstream of the sanitizer. |
| **Regex / `String#gsub` heading extraction** | Cannot handle nested inline markup (`<h2>Hello <em>World</em></h2>`), entities, attribute ordering, or malformed-but-valid HTML. Classic. | `Nokogiri::HTML5.fragment` + `.css("h2, h3")`. |
| **Global `html { scroll-behavior: smooth }`** | Overrides Turbo Drive scroll restoration on every navigation site-wide and ignores `prefers-reduced-motion` unless separately gated. | Per-click `scrollIntoView({behavior})` in the controller, motion-preference aware. |
| **JS-computed scroll offset for the sticky header** | Breaks on direct deep-link page loads and on browser find-in-page, both of which scroll without going through your handler. | `scroll-margin-top` (`scroll-mt-24`) on the headings. |
| **ViewComponent** for the TOC partial | The avohq.io reference uses it, but this repo has zero ViewComponent usage — everything is plain ERB partials (`_author_card`, `_faq_section`). Adding a gem + a new rendering convention for one partial is unearned scope. | `app/views/blogs/_table_of_contents.html.erb`. |
| **`scroll-target-group` / `:target-current` as the primary mechanism** | 66.39% global support, Chromium-only, not Baseline. Firefox 152 has it behind a flag; it's an Interop 2026 priority but hasn't landed. | `IntersectionObserver`. Revisit post-Baseline. |
| **Changing how `body` is stored** | Out of scope per PROJECT.md constraints, and unnecessary — a derived column or a render-time helper both leave `body` untouched. | Derived `body_html`/`toc_entries`, or render-time injection + fragment cache. |

## Stack Patterns by Variant

**If you want the smallest schema footprint:**
- Add only `toc_enabled:boolean` and `toc_entries:jsonb`; inject anchors at render time in a `BlogsHelper#toc_anchored_body(blog)` that does `sanitize` → Nokogiri → `raw`.
- Wrap the article body render in `<% cache [@blog, "anchored-body"] do %>` (solid_cache is already configured).
- Because: 3.27 ms/render is real but trivially cacheable, and you avoid a derived-content column that can drift out of sync with `body`.

**If you want maximum render-path simplicity:**
- Also add `body_html:text`, populated in `before_save` after `sanitize_body`; render it directly.
- Because: the show view becomes a single `sanitize` call with `+ %w[id]`, no helper, no cache key to reason about. Cost: a derived column you must remember to backfill (migration + `Blog.find_each(&:save!)`) and keep out of `blog_params`.

**If the marketing team ever asks for `h4` in the TOC:**
- The generator should read the heading selector from a constant (`TOC_HEADING_LEVELS = %w[h2 h3]`), not hardcode `.css("h2, h3")`. Cheap to do up front, annoying to retrofit once overrides are persisted against a fixed level set.

**If a post has zero (or one) `h2`/`h3` headings:**
- Suppress the TOC even when `toc_enabled` is true, and suppress the sidebar column so the article reverts to the current full-width `max-w-4xl` layout. This is the main "zero visual regression" trap — a two-column grid with an empty sidebar changes the article's measure and reflows every post.

## Version Compatibility

| Package | Locked | Current | Notes |
|---------|--------|---------|-------|
| `nokogiri` | 1.18.10 | 1.19.4 (2026-06-18) | 1.18.10 is fine. `Nokogiri::HTML5` verified available. CRuby-only — irrelevant here (CRuby 3.4.2 on `ruby:3.4.2-slim`), but would break on JRuby. |
| `rails-html-sanitizer` | 1.6.2 | 1.7.1 (2026-07-16) | 1.6.2 already includes the Dec-2024 XSS fixes (pruned SVG/MathML, `noscript`/`mglyph`/`malignmark` non-allowlistable). 1.7.0 only adds `Rails::HTML::Sanitizer.allowed_uri?` and raises the loofah floor to `~> 2.25`. **No upgrade required for this feature.** |
| `loofah` | 2.24.1 | 2.25.2 (2026-07-15) | Upgrading is coupled to rails-html-sanitizer 1.7.x. |
| `rails` | 8.0.3 | 8.1.3.1 | Irrelevant to this feature. |
| `@hotwired/stimulus` | 3.2.2 | **3.2.2** | Already latest. No action. |
| `@hotwired/turbo-rails` | 8.0.18 | 8.0.23 | Patch drift only. `turbo:before-cache` semantics unchanged. |
| `tailwindcss` / `@tailwindcss/cli` | 4.1.14 | 4.3.3 | `scroll-mt-*`, `sticky`, `overscroll-contain`, `dvh` units all present in 4.1.x. No upgrade needed. |
| `@tailwindcss/typography` | 0.5.19 | 0.5.20 | Patch. No upgrade needed. |
| `esbuild` | 0.25.10 | 0.28.1 | No new syntax introduced. No upgrade needed. |

### ⚠ Parser vendor mismatch (pre-existing, worth a decision)

Verified on this repo:

- `Blog#sanitize_body` calls `Rails::Html::SafeListSanitizer`, which resolves to **`Rails::HTML4::SafeListSanitizer`** (libxml2 parser).
- `config.load_defaults 8.0` makes the view-level `sanitize` helper use the **HTML5** vendor.

So `blogs.body` is currently sanitized under HTML4 tree-construction rules at save and re-sanitized under HTML5 rules at render. For most well-formed Tiptap output these agree, but they are not guaranteed to. Since this milestone touches both sides of that pipeline:

- **Minimum:** use `Nokogiri::HTML5.fragment` for id injection so the ids are computed against the same DOM the browser builds. (Confidence: HIGH.)
- **Optional cleanup:** switch the model to `Rails::HTML5::SafeListSanitizer` (available in the locked 1.6.2) so save-time and render-time agree. **This can change the stored HTML of existing posts on their next save** — verify against real content before committing, and treat it as its own scoped change with its own tests, not a drive-by inside the TOC work. (Confidence: MEDIUM — the direction is clearly right; the blast radius on existing content is unmeasured.)

## Sources

**Verified empirically in this repo (HIGH confidence):**
- `bundle exec ruby` probe against `Blog::ALLOWED_TAGS`/`ALLOWED_ATTRIBUTES` — confirmed author `id`/`onclick` are stripped; confirmed `Rails::Html::SafeListSanitizer == Rails::HTML4::SafeListSanitizer`; confirmed `Rails::HTML5::SafeListSanitizer` is available; confirmed `Nokogiri::HTML5` is available.
- Slug edge-case probe — confirmed `parameterize` returns `""` for `日本語` and `🎉`, and duplicate headings collide.
- Nokogiri benchmark (99 KB / 30 headings, 200 iterations) — HTML4 1.89 ms, HTML5 3.27 ms per parse+inject+serialize.
- `db/schema.rb` — `blogs.keywords` is already `jsonb, default: [], null: false`.
- `app/views/blogs/show.html.erb` — render-time `sanitize` call that strips `id`.
- `config/application.rb:12` — `config.load_defaults 8.0`.

**Version data (HIGH confidence, fetched 2026-08-01):**
- rubygems.org API — nokogiri 1.19.4, rails-html-sanitizer 1.7.1, loofah 2.25.2, rails 8.1.3.1
- npm registry — `@hotwired/stimulus` 3.2.2, `tailwindcss` 4.3.3, `@tailwindcss/typography` 0.5.20, `esbuild` 0.28.1, `tocbot` 4.36.8 (989,434 weekly downloads), `stimulus-use` 0.53.0

**Official documentation (HIGH confidence):**
- https://github.com/rails/rails-html-sanitizer — README (Rails::Html → Rails::HTML → HTML4 aliasing, custom tags/attributes, prune vs strip) and CHANGELOG (1.6.1 security fixes, 1.6.2 frozen-array fix, 1.7.0 `allowed_uri?`)
- https://developer.mozilla.org/en-US/docs/Web/CSS/scroll-target-group — property semantics, `:target-current`, "not Baseline / limited availability"
- https://caniuse.com/mdn-css_properties_scroll-target-group — 66.39% global; Chrome/Edge 140+; no Firefox, no Safari
- https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/details — disclosure semantics, `details[open]` styling, `::marker`
- https://developer.mozilla.org/en-US/docs/Web/API/IntersectionObserver/disconnect — cleanup contract
- Context7 `/sparklemotion/nokogiri` — fragment parsing and attribute-mutation APIs

**Community / pattern references (MEDIUM confidence — corroborated across ≥2 sources):**
- https://css-tricks.com/table-of-contents-with-intersectionobserver/ — the canonical IntersectionObserver TOC pattern
- https://benfrain.com/building-a-table-of-contents-with-active-indicator-using-javascript-intersection-observers/ — `rootMargin` cropping, last-intersecting-wins, between-sections fallback
- https://chriskirknielsen.com/blog/simple-table-of-contents-highlighter/ — negative bottom `rootMargin` rationale
- https://avohq.io/blog/dynamic-table-of-contents-rails — the closest Rails+Nokogiri+Stimulus reference. **Shape reference only**: it uses scroll events (not IntersectionObserver), calls `parameterize` on a Nokogiri node rather than its text, does no dedupe, and does no blank-slug fallback.
- https://cheatsheetseries.owasp.org/cheatsheets/DOM_Clobbering_Prevention_Cheat_Sheet.html — DOM clobbering via `id`/`name`; strip `id` from user content
- https://wicg.github.io/sanitizer-api/ — Sanitizer API does not protect against DOM clobbering by default
- https://tink.uk/using-the-aria-current-attribute/ — `aria-current="location"` for in-page position
- https://www.betterstimulus.com/turbo/teardown.html — `turbo:before-cache` fires before `disconnect()`
- https://una.im/scroll-target-group/ and https://rolandfranke.nl/frontend-stories/scroll-spy-with-pure-css/ — CSS-only scroll-spy, progressive-enhancement framing

**LOW confidence / unresolved:**
- The exact visual/interaction details of the views4you.com reference pattern. PROJECT.md already notes the site 403s automated fetches; I did not attempt to bypass that. Verify visually during implementation if precise details matter.
- Firefox's `scroll-target-group` timeline (reported as flagged-in-stable at 152 / Interop 2026 priority, single-source). Doesn't affect the recommendation — the advice is "don't ship it yet" either way.

---
*Stack research for: server-rendered Rails 8 blog TOC / scroll-spy / anchor generation*
*Researched: 2026-08-01*
