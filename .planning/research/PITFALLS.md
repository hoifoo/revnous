# Pitfalls Research

**Domain:** Table of Contents / anchor navigation / scroll-spy retrofitted onto an existing Rails CMS storing pre-sanitized HTML
**Researched:** 2026-08-01
**Confidence:** HIGH for codebase-specific findings (verified empirically against this repo and its dev database), MEDIUM-HIGH for browser/CSS behaviour (verified against multiple community + spec sources)

> **How this was verified.** Findings marked *[VERIFIED IN REPO]* were reproduced by running the project's own sanitizer, `parameterize`, and a Nokogiri audit against the dev database. They are not inferred. Findings marked *[WEB]* come from community/spec sources and should be re-confirmed in-browser during implementation.

---

## Critical Pitfalls

### Pitfall 1: The render-time `sanitize` call silently deletes every heading `id`

**What goes wrong:**
You implement heading-ID injection, the model looks right, the HTML in the console has `id="overview"` on every `<h2>` — and the public page renders headings with no `id` at all. Every TOC link becomes a dead `#anchor`, scroll-spy finds zero targets, and the failure is silent (no error, no warning).

**Why it happens:**
This app sanitizes the body **twice**, at two different layers, and both use an allowlist that omits `id`:

1. `Blog#sanitize_body` (`before_save`) — `Rails::Html::SafeListSanitizer.new.sanitize(body, tags: ALLOWED_TAGS, attributes: ALLOWED_ATTRIBUTES)`
2. `app/views/blogs/show.html.erb:76` — `<%= sanitize @blog.body, tags: Blog::ALLOWED_TAGS, attributes: Blog::ALLOWED_ATTRIBUTES %>`

`Blog::ALLOWED_ATTRIBUTES` is `%w[href target rel src alt width height colspan rowspan scope]` — no `id`.

*[VERIFIED IN REPO]* Running the project's exact allowlist through the sanitizer:

```
input:                   <h2 id="intro">Intro</h2><h3 id="a">A</h3>
WITH PROJECT ALLOWLIST:  <h2>Intro</h2><h3>A</h3>       # id stripped
WITH id ADDED:           <h2 id="intro">Intro</h2>...   # id survives
DEFAULT RAILS ALLOWLIST: <h2>Intro</h2><h3>A</h3>       # id stripped here too
```

Note the third line: Rails' **default** `SafeListSanitizer` allowlist also excludes `id` (`Rails::Html::SafeListSanitizer.allowed_attributes.include?("id") # => false`), even though the underlying Loofah safelist includes it. So "just drop the explicit attributes argument" does **not** fix this.

Developers get burned because they fix layer 1 (the model), verify in `rails console`, and never notice layer 2 in the view.

**How to avoid:**
- Decide *one* place IDs are added, then make sure the **last** sanitizer in the chain permits them.
- Recommended: add `id` to the allowlist via a **restricted custom scrubber**, not a blanket `ALLOWED_ATTRIBUTES + ["id"]` (see Pitfall 2 for why). A `Loofah::Scrubber` that only permits `id` on `h1..h6` and only when it matches `/\A[a-z][a-z0-9-]*\z/` keeps the blast radius tiny.
- Add a request spec asserting the *rendered response body* (not the model attribute) contains `id=` on headings. Model-level tests will pass while the page is broken.

**Warning signs:**
- TOC links do nothing on click but the DOM inspector shows correct `<a href="#...">`.
- `document.querySelectorAll('h2[id]').length === 0` in the console on a real post.
- Tests pass at model level but manual QA finds broken anchors.

**Phase to address:**
Phase 1 (anchor ID generation / sanitizer changes) — before any front-end work starts.

---

### Pitfall 2: Allowing `id` globally opens a DOM-clobbering hole

**What goes wrong:**
The one-line fix for Pitfall 1 is `ALLOWED_ATTRIBUTES + ["id"]`. That permits an arbitrary `id` on *every* allowed tag, on content pasted into Tiptap from anywhere. An `id="body"`, `id="attributes"`, `id="location"` or `id="submit"` element can clobber `document.body`, form properties, and named-access globals — turning pasted marketing copy into a script-breaking (and in some patterns, XSS-enabling) payload.

**Why it happens:**
The allowlist is a flat array shared by model and view. Widening it is a 12-character change and looks harmless. The threat model (authenticated marketing staff pasting HTML from Google Docs / other CMSes) makes accidental clobbering more likely than malicious injection — but the failure mode is the same.

**How to avoid:**
- Permit `id` **only on heading elements**, and **only** for values matching a namespaced pattern you generate (e.g. `/\Atoc-[a-z0-9-]+\z/`).
- Namespacing has a second benefit: it guarantees IDs never collide with the app's own element IDs and never start with a digit (see Pitfall 4).
- Implement as a `Loofah::Scrubber` used by both `sanitize_body` and the view, so the two layers can never drift apart. Better still: replace the view's `sanitize` with a single shared helper so there is one source of truth.

**Warning signs:**
- `ALLOWED_ATTRIBUTES` diff in the PR contains a bare `"id"`.
- Any JS on the page starts behaving differently only on specific posts.

**Phase to address:**
Phase 1, in the same change as the sanitizer work.

---

### Pitfall 3: There are no H2/H3 headings in the existing content — an H2/H3-only TOC is empty on every current post

**What goes wrong:**
You ship a TOC that extracts `h2, h3`. An admin toggles it on for the flagship long-form post. The TOC renders empty (or the sidebar renders as a blank box), and the feature looks broken on exactly the content it was built for.

**Why it happens:**
*[VERIFIED IN REPO — dev database audit, 10 posts]*

```
posts with body:                 10
heading counts across all posts: {"h1" => 2}
posts with ZERO h2/h3:           10  (100%)
headings with existing id attrs: 0
```

Per-post breakdown showed 8 of 10 bodies contain **no block markup at all** — no `<p>`, no headings, just ~1000 chars of text with `\n` newlines. The only substantially structured post (`test`, 10.5 KB, 98 `<p>`) uses `<h1>` for its two section headings: *"Impacts of the sale price on revenue growth in Shopify"* and *"Why does the sales price go beyond just discounting"*.

The root cause is content lineage. Migration history is `blogs.content` → ActionText/Trix (`20251216121901_migrate_blog_content_to_rich_text.rb`) → `blogs.body` (`20260513121220_add_body_to_blogs.rb`). **Trix exposes a single heading button that emits `<h1>`** — so every heading authored in the old editor is an `<h1>`. Tiptap now offers `levels: [1,2,3,4,5,6]` (`tiptap_editor_controller.js:26`), but nothing has yet been re-authored with H2/H3.

**How to avoid:**
- Run a **production** content audit as an explicit, gated deliverable before the extractor spec is frozen. The dev DB may not mirror production, but a 100%-miss rate is a strong enough signal to make this a blocker, not a nice-to-have.
- Design the extractor to be **level-configurable**, not hardcoded to H2/H3. At minimum decide explicitly how in-body `<h1>` is treated.
- Note the adjacent SEO problem this surfaces: `show.html.erb` already renders `<h1><%= @blog.title %></h1>`, so in-body `<h1>`s create duplicate H1s. Either normalize legacy in-body `<h1>` → `<h2>` (a content migration, with its own risks — see Pitfall 9) or treat in-body `<h1>` as a TOC level-1 entry.
- Define and implement an explicit **empty/thin-TOC fallback**: if fewer than N entries (2 or 3) are extracted, render *nothing* — no empty sidebar, no empty mobile dropdown, and no layout change. This must be a server-side decision so it costs zero CLS.

**Warning signs:**
- Extractor unit tests use hand-written fixture HTML with tidy `<h2>`s that look nothing like real post bodies.
- Nobody has run a query against real content before Phase 2 starts.
- Acceptance criteria say "TOC generates from H2/H3" with no statement about what happens when there are none.

**Phase to address:**
Phase 0/1 — content audit is a prerequisite deliverable. Empty-state fallback belongs in the same phase as the extractor.

---

### Pitfall 4: Slug generation produces duplicate, empty, or unqueryable anchor IDs

**What goes wrong:**
Four distinct failure modes, all from naively using `heading.text.parameterize`:

*[VERIFIED IN REPO — actual `ActiveSupport` `parameterize` output]*

| Heading text | `parameterize` result | Failure |
|---|---|---|
| `Overview` (appears twice) | `overview`, `overview` | Duplicate IDs — browser jumps to the first one only; scroll-spy highlights the wrong entry |
| `2026 Trends` | `2026-trends` | `document.querySelector('#2026-trends')` throws a **DOMException/SyntaxError** — CSS identifiers cannot start with a digit |
| `?!?` | `""` | `id=""` — invalid; the link `href="#"` scrolls to top of page |
| `产品概览` | `""` | Same as above — any non-transliterable script collapses to empty |
| `C++ vs Rust` | `c-vs-rust` | Silent semantic collision risk with `C vs Rust` |
| `🚀 Getting Started` | `getting-started` | Emoji dropped (benign, but changes the ID if the emoji is later removed — see Pitfall 5) |

The digit-leading case is especially nasty: it works fine in the URL bar (HTML5 IDs may start with a digit) and only explodes inside the JS that does `querySelector('#' + id)` — so it passes manual click-testing via the URL and fails only in scroll-spy/smooth-scroll.

**How to avoid:**
- **Namespace-prefix every ID** (`toc-overview`). This single decision kills the digit-leading bug permanently and prevents collisions with app element IDs.
- **Deduplicate deterministically**: maintain a seen-set during extraction and append `-2`, `-3`, … Order-dependent, so it must be computed in a single pass over the document in document order.
- **Fall back on empty slugs**: if the parameterized text is blank, use `toc-section-#{index}`. Never emit `id=""`.
- **In JavaScript, never build a selector by string concatenation.** Use `document.getElementById(id)` (which accepts any ID string) or `CSS.escape(id)`. Same for reading `location.hash` — `decodeURIComponent` it first.
- Consider transliteration (`I18n.transliterate`) only if non-Latin headings are actually expected; otherwise the index fallback is sufficient and simpler.

**Warning signs:**
- Extractor code contains `"#" + id` or `` `#${id}` `` anywhere.
- No test with two identically-titled headings in one document.
- No test with a heading that is purely punctuation/emoji/non-Latin.

**Phase to address:**
Phase 1 (ID generation). Add the JS-side `getElementById` rule as an explicit convention in the Phase covering the Stimulus controller.

---

### Pitfall 5: Anchor IDs derived from heading text are unstable — deep links rot silently

**What goes wrong:**
An admin fixes a typo in a heading ("Recomended Tools" → "Recommended Tools"). Every previously shared/indexed deep link to `#toc-recomended-tools` now silently scrolls to the top of the page. Nothing errors; nobody notices; the Google-indexed jump-to-section links break.

Worse variant: if IDs are computed at *render* time from the current text, and an admin uses the "relabel entry" override feature, a careless implementation lets the override change the ID too — breaking anchors on every edit.

**Why it happens:**
Text-derived IDs are a hidden coupling between "editorial content" and "public URL surface." The dependency isn't visible in the admin UI, so editors have no way to know that renaming a heading is a breaking change.

**How to avoid:**
- **Persist the ID→heading mapping** alongside the TOC override data (the same JSONB/serialized column that stores relabel/reorder/hide). On regeneration, match existing entries by position + fuzzy text and *preserve* the previously assigned ID rather than recomputing it.
- **Make the admin "relabel" override affect the TOC label only, never the anchor ID.** This should be an explicit acceptance criterion, because the naive implementation gets it wrong.
- Surface the ID in the admin override UI (read-only) so editors can see anchors exist.
- Accept-and-document the alternative: fully deterministic render-time IDs with no persistence is *much* simpler; if link stability isn't valued, choose it deliberately and write it down in Key Decisions rather than falling into it.

**Warning signs:**
- Override data structure stores only `{label, hidden, position}` with no `id`/`anchor` key.
- Acceptance criteria say "stable, unique anchor id" (PROJECT.md does) but no test edits a heading and re-checks the ID.

**Phase to address:**
Phase 1 (ID model) + Phase 2 (admin override), and the two must be designed together.

---

### Pitfall 6: The sidebar layout change leaks into TOC-off posts and breaks the zero-regression requirement

**What goes wrong:**
This is the highest-probability way the project's hard constraint gets violated. In `app/views/blogs/show.html.erb`, the breadcrumb, category, **title, hero image, excerpt, and body are all inside one container**:

```erb
<div class="bg-white py-16">
  <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
```

To put a sidebar next to the body you must widen that container (`max-w-4xl` → `max-w-7xl`) and introduce a grid. If that change is unconditional, then on **every existing post**: the H1 gets wider, the 16:9 hero image gets physically larger, the excerpt reflows, and the body's line-length (measure) changes. That is a total visual regression across the whole blog — the exact thing PROJECT.md forbids.

The subtler variant: you correctly branch the container, but the grid wrapper is added around the body `<div class="prose ...">` for *both* states, adding a `display: grid` context that changes margin collapsing on the prose block.

**Why it happens:**
The template wasn't built with a sidebar slot. The path of least resistance is to restructure the whole hero+content block once, and "TOC off just means the sidebar column is empty" — which still changes the content column's width.

**How to avoid:**
- Branch at the **container** level, and keep the TOC-off branch **byte-identical** to today's markup. Not "equivalent" — identical. Extract today's markup into a partial unchanged, and add a *separate* TOC-on layout branch.
- Do **not** try to unify the two layouts with conditional Tailwind classes on a shared wrapper; class-soup conditionals are exactly how leaks happen. Two explicit branches is more code and far safer.
- Add a **golden-master regression test**: a request spec that captures the rendered HTML of a TOC-off post and asserts it is unchanged (checksum or full-string fixture). This is cheap and catches leaks the moment they appear.
- Keep the TOC-off path free of *any* new wrapper element, new class, or new `data-controller` attribute.

**Warning signs:**
- A diff on `show.html.erb` where `max-w-4xl` disappears from the only branch.
- Conditional class interpolation inside an existing wrapper: `class="max-w-4xl <%= 'lg:max-w-7xl' if ... %>"`.
- No test that renders a TOC-off post.

**Phase to address:**
Phase 3 (public rendering / layout). The golden-master test should land *before* the layout change.

---

### Pitfall 7: The "reading-experience typography pass" directly contradicts the zero-regression requirement

**What goes wrong:**
PROJECT.md lists both:
- *"Reading-experience pass on blog show page: typography/spacing refinements alongside the TOC layout change"*
- *"Existing published posts render exactly as before when TOC is off (zero visual/layout regression)"*

These cannot both be fully true. A typography pass that only applies when TOC is on produces two visually different blog experiences on the same site. A typography pass that applies to everything is, by definition, a visual regression on existing posts.

Left unresolved, this surfaces mid-implementation as a stalled PR or, worse, as a silently-broken constraint.

**Why it happens:**
The two requirements were written at different levels — one is a UX goal, the other is a risk-control guardrail. Nobody reconciled them.

Complicating factor already in the codebase: `.prose-paragraph-relaxed p { margin-bottom: 2em; }` is a bare-descendant selector driven by the `blogs.spacing` column (default `"normal"`). There is already a per-post typography switch, and a second, overlapping one will conflict.

**How to avoid:**
- Resolve this explicitly during roadmap creation, before Phase 1. Realistic options:
  - **(a)** Redefine "zero regression" as "zero *layout/structural* regression; typography refinements are intentional and apply site-wide." Requires stakeholder sign-off and a before/after screenshot review.
  - **(b)** Gate the typography pass on the same per-post flag as the TOC. Preserves the guarantee, costs consistency.
  - **(c)** Drop the typography pass from this milestone.
- Whichever is chosen, record it in PROJECT.md's Key Decisions table and rewrite the conflicting requirement.
- If (a): budget a manual visual review of all posts as a phase deliverable, not an afterthought.

**Warning signs:**
- Roadmap contains both requirements verbatim with no reconciling decision.
- A phase named "typography + TOC" bundling both changes into one PR (makes the regression diff unreviewable).

**Phase to address:**
Roadmap creation / Phase 0. This is a planning-time decision, not an implementation-time one.

---

### Pitfall 8: Injecting TOC markup into `body` corrupts three downstream consumers

**What goes wrong:**
The tempting shortcut is to build the `<nav><ul>…</ul></nav>` server-side and splice it into `body` before rendering. That poisons every other consumer of `body`:

*[VERIFIED IN REPO]* `body` is read in four places:

| Consumer | Code | Breakage if TOC markup is in `body` |
|---|---|---|
| Public HTML | `show.html.erb:76` | (intended) |
| **Meta description** | `Blog#seo_description` → `strip_tags(body).truncate(160)` | Meta description becomes "Overview Getting Started Pricing Conclusion…" — a site-wide SEO regression on every TOC-enabled post |
| **Markdown export** | `BlogsController#render_blog_markdown` → `strip_tags(@blog.body)` | `/blog/:slug.md` (and the `llms.txt` surface) gets TOC noise |
| **Public JSON API** | `api/v1/blogs/show.json.jbuilder` → `json.content_html @blog.body` | API consumers receive navigation chrome inside article content |

`seo_description` is the killer — it's silent and it hits SEO, which is this product's whole point.

**How to avoid:**
- **Never** write TOC list markup into `body`. Render the TOC as a separate ERB partial from extracted data.
- Inject **only `id` attributes** into headings, if you persist anything at all. IDs are inert for `strip_tags`, harmless in the markdown export, and arguably an improvement for the JSON API.
- If IDs are injected at *render* time only, note the inconsistency: deep links work on the HTML page but the JSON API's `content_html` has no anchors. Decide whether that matters and document it.

**Warning signs:**
- Any code path that does `body.sub(/<h2/, toc_html + "<h2")` or similar.
- `seo_description` output changes in a diff for a post whose text wasn't edited.

**Phase to address:**
Phase 1 (extraction/storage design). Add a spec asserting `seo_description` is unchanged for a TOC-enabled post.

---

### Pitfall 9: A save-time or backfill ID injection silently rewrites historical content and bumps `dateModified`

**What goes wrong:**
Two related versions:

1. You add ID injection to the existing `before_save :sanitize_body` chain. Now *any* save of an old post — including an admin toggling an unrelated checkbox — rewrites its stored HTML. If the injector has a bug, it corrupts content that was previously fine, and there is no version history to restore from.
2. You write a backfill migration that adds IDs to all existing posts. Using `update!`/`save` touches `updated_at` on every row. `updated_at` feeds `render_article_schema(@blog)` (`dateModified`) and the `.md` export's "Updated:" line. Every blog post suddenly claims it was modified today. Google sees a site-wide content-freshness spike that isn't real.

**Why it happens:**
`before_save` is the obvious hook, and `find_each { |b| b.update!(body: ...) }` is the obvious migration. Neither developer intends to touch `updated_at`.

**How to avoid:**
- Strongly prefer **render-time** ID injection (parse + decorate in a helper, cache the result) over mutating stored content. It is idempotent, reversible, and leaves history untouched. Cost is one Nokogiri parse per show request (see Performance Traps — this is negligible at current scale).
- If you must persist: use `update_columns` / `update_all` in the backfill so callbacks and timestamps are skipped, and take a DB snapshot first.
- If injection must run on save, make it a **separate, idempotent** callback (not folded into `sanitize_body`) with a test proving `f(f(x)) == f(x)`.
- Verify: after the backfill, `Blog.maximum(:updated_at)` should be unchanged.

**Warning signs:**
- Migration uses `blog.update!` or `blog.save`.
- `sanitize_body` grows a second responsibility.
- No idempotency test.

**Phase to address:**
Phase 1.

---

### Pitfall 10: Scroll-spy highlights the wrong section — or nothing — at document boundaries

**What goes wrong:**
The classic set of IntersectionObserver scroll-spy bugs, all of which look fine in casual testing and wrong in real reading:

- **Last section never activates.** Observing headings with a top-band `rootMargin`, the final heading can never reach the band because the document runs out of scroll. The reader sits at the conclusion while the TOC highlights the second-to-last item.
- **Scrolling up highlights late.** Heading-only observation gives no signal until the *previous* heading re-enters the band, so upward scrolling lags by a full section. *[WEB]* This limitation is acknowledged in published implementations.
- **Multiple entries active simultaneously.** With short sections, several headings sit inside the band at once; naive `entry.isIntersecting → addClass` lights up three items.
- **Nothing active at the top.** Before the first heading enters the band, no item is highlighted — the TOC looks broken on page load.
- **Long images/tables between headings** create huge gaps where the band is empty.

**Why it happens:**
The mental model "observe the headings" is wrong. What you actually want is "which *section* occupies the reading line" — and sections aren't elements in this DOM (the body is a flat sequence of siblings, not wrapped sections).

**How to avoid:**
- Observe with a **narrow horizontal band**, e.g. `rootMargin: "-10% 0px -85% 0px"`, threshold `0`.
- Do **not** derive active state directly from callback events. Maintain a set of currently-intersecting heading IDs and, on each callback, **recompute** the active item as "the last heading whose top is above the band" — a pure function of state, not of event order. This fixes both the multi-active and scroll-up-lag problems in one move.
- Handle the two boundaries explicitly: **at `scrollY === 0`**, force the first item active; **at document bottom** (`window.innerHeight + scrollY >= document.body.scrollHeight - threshold`), force the last visible item active.
- Since the body is flat sibling markup (no section wrappers), computing "the last heading above the line" from cached `offsetTop` values is often simpler and more correct than IntersectionObserver alone. If you go that route, cache offsets and recompute on `resize` — never per scroll event.
- Test with: a 2-heading post, a post with a 3000px image between headings, and a post whose last section is 200px tall.

**Warning signs:**
- The controller adds/removes the active class inside the observer callback per-entry.
- No handling for `scrollY === 0` or bottom-of-document.
- Only tested on one long, evenly-structured article.

**Phase to address:**
Phase 4 (Stimulus scroll-spy behaviour).

---

### Pitfall 11: Scroll listeners cause jank; IntersectionObservers leak across Turbo navigations

**What goes wrong:**
Two separate performance/lifecycle failures:

1. **Jank.** A raw `window.addEventListener('scroll', …)` that reads `getBoundingClientRect()` for every heading fires layout-thrashing reads at up to 100+ Hz. On mid-range mobile the sticky TOC stutters and the page feels heavy — the opposite of a "reading experience" improvement.
2. **Leak.** Turbo Drive does not reload the page. An observer (or scroll listener) created in `connect()` and never torn down survives navigation. After browsing 5 posts you have 5 live observers pointing at detached DOM, and the *cached* page preview Turbo paints on back-navigation shows a stale active highlight.

**Why it happens:**
Stimulus `disconnect()` is easy to forget; Turbo's cache-preview behaviour is non-obvious. This codebase already anticipates the problem — `app/javascript/application.js` registers a `turbo:before-cache` hook calling `c.teardown()` on every controller — but that convention is opt-in per controller and easy to miss.

**How to avoid:**
- Use `IntersectionObserver` (or a `requestAnimationFrame`-throttled scroll handler), never a bare scroll listener.
- If reading positions, cache `offsetTop` once and invalidate on `resize` (debounced) — never read layout inside the scroll handler.
- Implement **both** `disconnect()` (call `observer.disconnect()`, remove listeners) **and** the project's `teardown()` convention so the Turbo cache preview is reset to a clean state.
- Watch for late-loading images shifting heading offsets after cache is computed — recompute on `load` and on `ResizeObserver` of the article container.

**Warning signs:**
- Controller has `connect()` but no `disconnect()`.
- No `teardown()` method, despite the app-wide convention in `application.js`.
- `getBoundingClientRect()` inside a scroll callback.
- Active highlight is wrong for a split second when navigating back.

**Phase to address:**
Phase 4.

---

### Pitfall 12: `scroll-behavior: smooth` on `html` leaks site-wide and fights Turbo

**What goes wrong:**
The one-line smooth-scroll implementation is `html { scroll-behavior: smooth; }`. Consequences:

- It applies to **every page on the site**, not just blog posts with TOC on — a global behaviour change shipped by a scoped feature.
- *[WEB]* It interacts badly with Turbo Drive. Turbo restores scroll position on restoration visits and scrolls to anchors on navigation; with smooth enabled these become visible animated scrolls, and Firefox has a documented mismatch (hotwired/turbo#1255) where anchored visits land at the wrong position. Bootstrap 5's default `scroll-behavior: smooth` is a known source of "weirdness with Turbo" in the community.
- It ignores `prefers-reduced-motion` unless explicitly wrapped. *[WEB]* Browser handling is inconsistent enough that the universal recommendation is to gate it yourself.

**How to avoid:**
- Do **not** set `scroll-behavior` on `html` or `:root`.
- Prefer JS-controlled scrolling on the TOC link click only:
  ```js
  const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches
  target.scrollIntoView({ behavior: reduce ? 'auto' : 'smooth', block: 'start' })
  ```
  This is scoped, respects the preference, and never touches Turbo's own scrolling.
- If you use CSS instead, scope it to the article container **and** wrap it:
  ```css
  @media (prefers-reduced-motion: no-preference) {
    .blog-toc-enabled { scroll-behavior: smooth; }
  }
  ```
- Add `scroll-margin-top` to targeted headings so they don't land flush against the viewport edge. Scope this to the TOC-on container — the site nav is currently **not** sticky (verified: no `sticky`/`fixed` in `layouts/application.html.erb` or `shared/_navigation.html.erb`), but a sticky mobile "Contents" bar would occlude the target if no offset is set.

**Warning signs:**
- `scroll-behavior: smooth` appears in `application.tailwind.css` outside a media query or outside a scoped selector.
- No `prefers-reduced-motion` check anywhere in the diff.
- Back-button navigation on non-blog pages starts animating.

**Phase to address:**
Phase 4, with the scoping rule set as a constraint in Phase 3 (so the container class exists to scope against).

---

### Pitfall 13: Clicking a TOC entry breaks the URL hash, the back button, and keyboard focus

**What goes wrong:**
The standard smooth-scroll handler calls `event.preventDefault()`. That single line removes three native behaviours:

1. **The URL hash never updates** — the reader can't copy a link to the section they're reading, and the browser **back button no longer returns to the previous section**.
2. **Keyboard focus stays on the TOC link.** *[WEB]* This is the best-documented smooth-scroll accessibility bug: the viewport moves but focus doesn't, so pressing Tab continues from the TOC, not from the section the user just jumped to. Screen reader users hear nothing change.
3. Reloading the page at a hash URL scrolls to the anchor before your JS runs, so the TOC's initial active state disagrees with the viewport.

**How to avoid:**
- After scrolling, restore the URL yourself: `history.pushState(null, '', '#' + id)` — `pushState` (not `replaceState`) so back-navigation walks section history.
- Move focus explicitly:
  ```js
  target.setAttribute('tabindex', '-1')
  target.focus({ preventScroll: true })
  ```
  *[WEB]* `tabindex="-1"` is required on non-interactive elements when focus is moved **programmatically** (the "modern browsers handle it" advice applies only to native, non-intercepted anchor jumps — which you've just disabled).
- With `behavior: 'smooth'`, focusing immediately cancels/competes with the animation in some browsers. Focus after the scroll settles (`scrollend` event where supported, otherwise a short timeout or a one-shot IntersectionObserver on the target).
- On page load with a hash present, sync the TOC's active state from `location.hash` before the observer's first callback.

**Warning signs:**
- `preventDefault()` with no corresponding `pushState`.
- No `.focus()` call anywhere in the click handler.
- Manual test plan doesn't include "click a TOC entry, then press Tab" or "click three entries, then press Back three times."

**Phase to address:**
Phase 4.

---

### Pitfall 14: The sticky sidebar doesn't stick, or sticks and then overlaps the footer

**What goes wrong:**
*[WEB — multiple independent sources agree]* A cluster of `position: sticky` failures, each producing a different wrong behaviour:

- **Never sticks.** `position: sticky` applied *directly* to the grid/flex item. Grid and flex default to `align-items: stretch`, so the item is already as tall as its track — there is no room inside its containing block for it to move, and it appears to do nothing. Fix: either set `align-self: start` (`self-start` in Tailwind) on the sticky item, **or** keep the item stretched and put `position: sticky` on an **inner** wrapper (`<div class="sticky top-8">`). The inner-wrapper pattern is the more robust of the two.
- **Missing offset.** `position: sticky` with no `top` value never activates. Always pair with `top-*`.
- **Ancestor `overflow`.** Any ancestor with `overflow: hidden|auto|scroll` becomes the scroll container and silently kills sticky. Currently clean in this app (no `overflow-hidden` on `<body>`, `<main>`, or the blog wrappers — verified), but a future wrapper could break it from a distance. Use `overflow: clip` instead of `hidden` where clipping is genuinely needed — it clips without creating a scroll container.
- **Short article.** If the article is shorter than the sidebar, the sidebar defines the row height, adding whitespace below the article; sticky is pointless and the layout looks broken. Ship an explicit rule: don't render the sidebar TOC below a minimum content height / heading count (reuse the Pitfall 3 threshold).
- **Long TOC.** A post with 25 headings produces a TOC taller than the viewport; the bottom entries are permanently unreachable. Fix: `max-h-[calc(100vh-8rem)] overflow-y-auto` plus `overscroll-behavior: contain` so scrolling the TOC to its end doesn't chain-scroll the article.
- **Footer overlap.** The sticky element rides down over the "Related Articles" / CTA sections if the sticky container extends past the article. Keep the sticky element's containing block scoped to the article grid row only — do not let the grid span the related-articles and CTA blocks, which are currently siblings outside the `max-w-4xl` container.

**How to avoid:**
- Standardise on: `grid` container → sidebar column (stretched, default) → inner `<div class="sticky top-8 max-h-… overflow-y-auto overscroll-contain">`.
- Constrain the grid to the article region only.
- Test matrix: 2-heading post, 25-heading post, article shorter than the sidebar, 1280px / 1024px / 768px viewports.

**Warning signs:**
- `sticky` class on the same element as `col-span-*` / the direct grid child.
- No `top-*` alongside `sticky`.
- No `max-h`/`overflow-y-auto` on the TOC list.
- QA only used one long, well-structured post.

**Phase to address:**
Phase 3 (layout).

---

### Pitfall 15: The mobile "Contents" dropdown is a div, not a disclosure

**What goes wrong:**
The mobile TOC ships as `<div onclick=…>` toggling a `hidden` class. Consequences: not keyboard-reachable (no Tab stop, no Enter/Space), no state announced to screen readers, Escape doesn't close it, and focus isn't returned to the trigger on close — so a keyboard user who opens it and closes it is dumped at the top of the tab order.

Secondary issue specific to responsive TOCs: rendering the TOC **twice** (a desktop `<nav>` and a mobile `<nav>`) puts two "Table of contents" navigation landmarks in the accessibility tree. Screen reader users hear the TOC announced twice on every post.

**Why it happens:**
Tailwind's `hidden md:block` / `md:hidden` pattern makes dual rendering trivially easy, and the disclosure semantics are invisible in visual QA.

**How to avoid:**
- *[WEB]* Use the standard disclosure pattern: a real `<button aria-expanded="false" aria-controls="blog-toc-list">`, toggle `aria-expanded`, close on `Escape`, and return focus to the button on close.
- Hide the inactive copy with **`display: none`** (Tailwind's `hidden`), which removes it from the accessibility tree. Do **not** hide via `opacity: 0`, `visibility` tricks, or off-screen positioning — those leave it announced.
- Better: render the TOC **once** and reposition it with CSS (grid `order` / placement) rather than duplicating markup. This eliminates the duplicate-landmark problem entirely and halves the state you must keep in sync (the active scroll-spy item otherwise has to be updated in two DOM trees).
- Wrap the TOC in `<nav aria-label="Table of contents">` and mark the current item with `aria-current="location"` (or `"true"`) in addition to a visual class. *[WEB]* Indicating current location is a WCAG AAA criterion and needs both the visual cue and the ARIA attribute.
- Ensure the visual active-state cue is not colour-only (add weight/border) for contrast compliance.

**Warning signs:**
- No `<button>` in the mobile TOC markup.
- `aria-expanded` absent.
- Two `<nav>` elements with the same content in the rendered HTML.
- Active state applied via a class only, no `aria-current`.

**Phase to address:**
Phase 3 (markup/semantics) with keyboard behaviour in Phase 4.

---

### Pitfall 16: Client-side TOC generation causes cumulative layout shift

**What goes wrong:**
The TOC is built in JavaScript from the rendered DOM after page load. The article paints at full width, then the sidebar appears and shoves the content — a visible jump and a measurable CLS hit. On mobile, a "Contents" bar inserted above the article pushes everything down after first paint. Since this project is explicitly SEO-first, a Core Web Vitals regression is directly counter-productive.

**Why it happens:**
Client-side generation is the fastest path to a working demo — the headings are right there in the DOM. It also seems to avoid the sanitizer problem (Pitfall 1) by adding IDs via JS. That's a false economy: JS-added IDs don't exist for search engines, don't survive "view source," and don't work in the `.md`/JSON surfaces.

**How to avoid:**
- **Render the TOC server-side in ERB.** JavaScript should only add *behaviour* (scroll-spy, smooth scroll, dropdown toggle) to already-present markup — this is the Stimulus philosophy and matches the project's stack constraint.
- Server-render the mobile disclosure collapsed with a fixed-height trigger so its footprint is stable from first paint.
- If any part must be client-side, reserve space with an explicit min-height.
- Measure: run Lighthouse on a TOC-on post before/after and record CLS in the phase's acceptance criteria.

**Warning signs:**
- The Stimulus controller contains `document.createElement('li')` or builds `innerHTML`.
- Heading IDs are set in JS.
- No TOC visible in "view source."

**Phase to address:**
Phase 3 (server-rendered markup) — establishes the contract Phase 4 enhances.

---

### Pitfall 17: Admin-supplied override labels are rendered unescaped

**What goes wrong:**
The override feature lets admins retype TOC entry labels. If those labels are stored and rendered with `raw`, `html_safe`, or passed through `sanitize` with tags allowed (by analogy with body rendering), an admin-supplied label becomes an HTML/script injection vector. Even without malice, a label containing `<` or `&` breaks the markup.

**Why it happens:**
The surrounding code (`show.html.erb:76`) legitimately calls `sanitize` on HTML. Copy-paste momentum makes the next developer reach for the same helper on the label field. Admin-authored content is also mistakenly treated as trusted.

**How to avoid:**
- TOC labels are **plain text**. Render with plain `<%= %>` (auto-escaped). Never `html_safe`, never `sanitize`.
- Strip tags on write (`strip_tags`) as defence in depth, and enforce a max length so a pasted paragraph can't destroy the sidebar layout.
- Same rule for the auto-generated label: extract with Nokogiri's `.text`, which already yields plain text — headings can legitimately contain `<code>`, `<strong>`, or `<a>` (all in `ALLOWED_TAGS`), and `.text` flattens them correctly. Do not use `.inner_html`.

**Warning signs:**
- `raw`, `html_safe`, or `sanitize` anywhere near the override label in the TOC partial.
- No length validation on the label.
- Extraction uses `inner_html` instead of `text`.

**Phase to address:**
Phase 2 (admin override) and Phase 3 (rendering).

---

### Pitfall 18: STI subclasses and non-blog consumers inherit the schema change without the feature

**What goes wrong:**
`blogs` has a `type` column and `Article < Blog` exists (`app/models/article.rb`). A `toc_enabled` boolean and any TOC-override column added to `blogs` are inherited by `Article`. If `Article` has its own show view or admin form, it gets the DB column but not the UI — or worse, gets a partially-wired UI that renders a TOC in a template that has no sidebar slot.

**Why it happens:**
STI is easy to forget when the subclass is a one-line file.

**How to avoid:**
- Enumerate every consumer of the `blogs` table before writing the migration: `Article`, the admin form, the public show view, `api/v1/blogs/show.json.jbuilder`, the `.md` renderer.
- Decide explicitly whether `Article` gets the feature. If not, ensure its rendering path never reads the new columns.
- Default the new boolean to `false, null: false` so inheritance is inert by default.

**Warning signs:**
- Migration PR touches only `blog.rb` and `admin/blogs/_form.html.erb`.
- Nobody has opened `app/models/article.rb`.

**Phase to address:**
Phase 1 (schema) / Phase 2 (admin).

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Add bare `"id"` to `Blog::ALLOWED_ATTRIBUTES` | One-line fix for Pitfall 1 | DOM-clobbering surface on all tags; arbitrary pasted IDs; no way to distinguish generated from pasted anchors | **Never** — a heading-scoped scrubber is ~15 lines |
| Generate the TOC client-side from the DOM | No server changes, no sanitizer work | CLS regression, invisible to crawlers, no anchors in `view-source`/`.md`/JSON, harder to test | Only as a throwaway spike; never shipped |
| Recompute anchor IDs from heading text on every render (no persistence) | Much simpler; no new columns; naturally idempotent | Deep links rot silently whenever a heading is edited | Acceptable **if consciously chosen and documented** — link stability may genuinely not matter here |
| Conditional Tailwind classes on the existing shared wrapper instead of two layout branches | Smaller diff | Highest-probability route to violating the zero-regression constraint | Never — the constraint is the point of the project |
| Duplicate the TOC markup for desktop + mobile | Trivially easy with Tailwind responsive classes | Two landmarks in the a11y tree; scroll-spy state must be synced in two DOM trees | Acceptable only if the inactive copy uses `display: none` **and** scroll-spy updates both |
| Skip system/browser specs (none exist today) | Ships faster | Every interactive behaviour in this feature (spy, sticky, dropdown, focus) is unverifiable and will regress | Acceptable for one milestone **only if** paired with a written manual QA checklist executed before merge |
| Fold ID injection into the existing `sanitize_body` callback | Fewer moving parts | Every save of every old post rewrites stored content; no idempotency guarantee | Never — make it a separate, tested, idempotent callback, or do it at render time |
| Hardcode `h2, h3` in the extractor | Matches the requirement as literally written | Empty TOC on 100% of current content (verified) | Never — make levels configurable |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| `Rails::Html::SafeListSanitizer` (view layer) | Fixing the model allowlist only and assuming the rendered page matches | Both layers share one allowlist/scrubber; assert against the **rendered response**, not the model attribute |
| Rails default sanitizer allowlist | "Removing the explicit `attributes:` arg will let `id` through" | It won't — Rails' default `allowed_attributes` excludes `id` (verified). You must add it deliberately |
| Nokogiri (extraction) | `Nokogiri::HTML(body)` on a fragment wraps content in `<html><body>`, shifting selectors and serialisation | Use `Nokogiri::HTML.fragment(body)`. Note the project's sanitizer resolves to `Rails::HTML4::SafeListSanitizer` — parse with the matching parser to avoid tokenisation drift |
| Tiptap editor | Assuming authors will produce H2/H3 because the toolbar offers them | Editor allows `levels: [1,2,3,4,5,6]`; legacy Trix content is all `<h1>`. Handle what exists, not what's ideal |
| Turbo Drive | Setting up observers in `connect()` and never tearing down | Implement `disconnect()` **and** the app's `teardown()` convention (`application.js` `turbo:before-cache` hook) |
| Turbo Drive + `scroll-behavior: smooth` | Global `html { scroll-behavior: smooth }` | Scope it, or do scrolling in JS. Global smooth breaks Turbo restoration visits and anchored visits (Firefox, hotwired/turbo#1255) |
| `api/v1/blogs/show.json.jbuilder` | Forgetting it emits `content_html @blog.body` verbatim | Never inject nav markup into `body`. Decide deliberately whether the API's HTML carries anchor IDs |
| `Blog#seo_description` | Not realising it is `strip_tags(body).truncate(160)` | Any body mutation is an SEO mutation. Regression-test `seo_description` |
| ActiveStorage images in body | Late-loading images shift heading offsets after scroll-spy caches positions | Recompute offsets on `load` / `ResizeObserver`, or rely on IntersectionObserver (which is layout-live) |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Nokogiri-parsing `body` on every show request | Slower TTFB on long posts | Negligible at current scale (10 posts, largest body 10.5 KB). Memoize per request; add fragment caching only if posts exceed ~100 KB or traffic grows | Not a concern below ~100 KB bodies / low-traffic marketing blog |
| Parsing body for a TOC on the **index** page | N+1 parses per page load | Index renders excerpts only — keep it that way; never call the TOC helper from `blogs/index` or from `_related_blogs` | Immediately, if the helper leaks into a collection partial |
| Raw `scroll` listener reading `getBoundingClientRect()` per heading | Stuttery sticky sidebar, jank on mid-range mobile | IntersectionObserver, or `requestAnimationFrame`-throttled handler with cached offsets | ~15+ headings, or any mobile device |
| Leaked observers across Turbo navigations | Memory growth, stale highlight after Back | `disconnect()` + `teardown()` | After ~5 in-session navigations |
| Recomputing heading offsets on every scroll tick | Layout thrashing (forced synchronous reflow visible in DevTools Performance) | Cache on load, invalidate on debounced `resize` and image `load` | Any post with images |
| Long TOC re-rendering active class on every callback | Minor, but compounds with the above | Only touch the DOM when the active ID actually changes (compare against previous) | 20+ entries |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Adding `id` to the global attribute allowlist | DOM clobbering (`id="body"`, `id="attributes"`, `id="submit"`) from pasted content; script breakage and potential XSS gadget | Heading-scoped scrubber; `id` values restricted to a generated `/\Atoc-[a-z0-9-]+\z/` pattern |
| Rendering admin override labels with `raw`/`html_safe`/`sanitize` | Stored XSS via the admin UI; broken markup from stray `<`/`&` | Plain-text only; auto-escaped `<%= %>`; `strip_tags` on write; length cap |
| Extracting heading text with `inner_html` instead of `.text` | Nested `<a>`/`<code>`/`<strong>` markup leaks into the TOC and into any `html_safe` sink | Nokogiri `.text` |
| Relaxing `ALLOWED_TAGS` "while we're in there" | Widens the XSS surface for a reason unrelated to the TOC | Tag allowlist changes are out of scope for this milestone — state it explicitly |
| Trusting `location.hash` and passing it to `querySelector` | Selector-injection / thrown exceptions from crafted fragments | `getElementById(decodeURIComponent(hash.slice(1)))`, wrapped in a null check |
| Fragment-caching TOC HTML keyed only on blog ID | Serving a stale/incorrect TOC after edits | Include `updated_at` and the override payload in the cache key |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Rendering an empty or 1-item TOC | A blank sidebar box looks broken and wastes the widest part of the layout | Server-side threshold: fewer than 2–3 entries → render nothing and keep the original single-column layout |
| Including H4–H6 (or H2+H3 on a deeply nested post) | *[WEB]* Overly long TOCs are hard to navigate, especially on small screens | Default to two levels; visually indent H3 under H2; cap total entries |
| Mobile dropdown open by default | Pushes the article below the fold; readers see navigation, not content | Collapsed by default with a fixed-height trigger |
| Heading lands flush against the viewport top after a jump | Reader can't tell whether they're at the start of the section | `scroll-margin-top` on target headings (scoped to the TOC-on container) |
| No active item highlighted at page top | TOC looks inert/broken on load | Force the first item active at `scrollY === 0` |
| Active state indicated by colour alone | Fails contrast/colour-blindness; WCAG issue | Colour **plus** weight or a left border, **plus** `aria-current` |
| Long TOC with no internal scroll | Bottom entries permanently unreachable on short viewports | `max-h-[calc(100vh-8rem)] overflow-y-auto overscroll-contain` |
| Sticky TOC overlapping the Related Articles / CTA sections | Navigation chrome floats over unrelated content | Scope the sticky containing block to the article grid row only |
| Smooth scroll ignoring `prefers-reduced-motion` | Nausea/vestibular discomfort for affected users | `matchMedia` check, or `@media (prefers-reduced-motion: no-preference)` |
| Focus left behind on the TOC link after a jump | Keyboard users must Tab through the whole TOC again; SR users hear nothing change | `tabindex="-1"` + `focus({preventScroll: true})` after the scroll settles |
| Hash not updated on click | Can't share a link to a section; Back button doesn't undo the jump | `history.pushState(null, '', '#' + id)` |

---

## "Looks Done But Isn't" Checklist

- [ ] **Heading IDs:** Verified in the **rendered HTML response** (`view-source` / request spec), not just the model attribute — the view's `sanitize` call strips them independently.
- [ ] **Empty TOC:** A post with zero H2/H3 (i.e. every post currently in the DB) has been toggled on and renders *no* sidebar and *no* layout change — not an empty box.
- [ ] **Zero-regression:** A TOC-**off** post's rendered HTML is byte-identical to pre-change output. Golden-master test committed, not just eyeballed.
- [ ] **Duplicate headings:** A post with two identically-titled headings produces two distinct IDs and the TOC highlights the correct one.
- [ ] **Digit-leading / empty slugs:** A heading named `2026 Trends` and one named `?!?` both produce working, queryable anchors.
- [ ] **Rename stability:** Editing a heading's text (or relabelling it via the override UI) does not silently change its anchor ID — or the decision to allow it is documented.
- [ ] **`seo_description` unchanged:** Meta description for a TOC-enabled post is identical to before.
- [ ] **`.md` export and JSON API:** `/blog/:slug.md` and `api/v1/blogs/show.json` contain no TOC navigation markup.
- [ ] **`updated_at` untouched:** After any backfill, `Blog.maximum(:updated_at)` is unchanged.
- [ ] **Idempotency:** Saving a TOC-enabled post twice produces identical `body`.
- [ ] **Last section:** Scrolling to the very bottom highlights the *last* TOC entry, not the second-to-last.
- [ ] **Page top:** At `scrollY === 0` the first entry is highlighted.
- [ ] **Scroll up:** Scrolling upward updates the highlight promptly, not a section late.
- [ ] **Turbo:** Navigating away and back leaves no leaked observers and no stale highlight in the cache preview.
- [ ] **Reduced motion:** With OS "reduce motion" on, TOC clicks jump instantly.
- [ ] **Keyboard:** Tab reaches the mobile trigger; Enter/Space toggles; Escape closes; focus returns to the trigger; after clicking a TOC entry, Tab continues from the target section.
- [ ] **Screen reader:** Exactly one "Table of contents" navigation landmark is announced; the active item is announced via `aria-current`.
- [ ] **Sticky:** Verified with a 2-heading post, a 25-heading post, an article shorter than the sidebar, and at 1280/1024/768px.
- [ ] **Footer:** The sticky TOC never overlaps Related Articles or the CTA block.
- [ ] **CLS:** Lighthouse CLS on a TOC-on post is unchanged or improved versus a TOC-off post.
- [ ] **STI:** `Article` behaviour with the new columns is defined and verified.

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| IDs stripped by the view sanitizer | LOW | Add the heading-scoped scrubber to the view's sanitize path; no data change needed |
| Bare `id` shipped in the global allowlist | MEDIUM | Tighten to a scrubber; re-run sanitisation over stored bodies to purge pasted IDs; audit for clobbering-prone values |
| Extractor targets H2/H3 only, TOC empty everywhere | LOW–MEDIUM | Make levels configurable (code-only). Content normalisation (H1→H2 across posts) is a separate, riskier content migration |
| Layout regression shipped to all posts | MEDIUM | Revert the container change; re-do with two explicit branches + golden-master test. Damage is cosmetic but public |
| TOC markup injected into `body` and persisted | HIGH | Requires a reverse migration to strip injected nav markup from stored HTML without damaging authored content; `seo_description` values must be re-derived. Restore from DB snapshot if available |
| Backfill bumped every `updated_at` | MEDIUM | `updated_at` cannot be recovered without a snapshot. `dateModified` in Article schema stays wrong until posts are genuinely edited. **Take a snapshot before any backfill** |
| Anchor IDs changed after a heading edit (link rot) | MEDIUM | Add persisted ID mapping going forward; optionally emit legacy-ID duplicate anchors for known-shared links. Externally shared links already broken cannot be recovered |
| Scroll-spy jank / leaked observers | LOW | Rewrite the controller's observation strategy; add `disconnect()`/`teardown()` |
| Sticky sidebar not sticking | LOW | CSS-only: move `sticky` to an inner wrapper, add `top-*`, check ancestor `overflow` |
| A11y defects found post-launch | LOW–MEDIUM | Markup-level fixes (button, `aria-expanded`, `aria-current`, focus management); no data impact |

---

## Pitfall-to-Phase Mapping

Phase names are suggestions for the roadmap; the important part is the ordering and the gating.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| 3. No H2/H3 in existing content | **Phase 0 — content audit (gate)** | Nokogiri heading-distribution report over the **production** DB, reviewed before the extractor spec is frozen |
| 7. Typography pass vs zero-regression conflict | **Phase 0 — roadmap/decision (gate)** | A recorded decision in PROJECT.md Key Decisions; the conflicting requirement rewritten |
| 1. View sanitizer strips `id` | Phase 1 — anchors & sanitizer | Request spec asserting `id=` present on headings in the **response body** |
| 2. Global `id` allowlist / DOM clobbering | Phase 1 | Spec: `<p id="body">` in input is stripped; `<h2 id="toc-x">` survives |
| 4. Slug collisions / empty / digit-leading | Phase 1 | Unit tests for duplicate, punctuation-only, non-Latin, and digit-leading headings |
| 5. Anchor instability / link rot | Phase 1 + Phase 2 (designed together) | Spec: edit heading text → anchor ID unchanged; relabel via override → anchor ID unchanged |
| 8. Body mutation corrupts `seo_description` / `.md` / JSON | Phase 1 | Specs asserting `seo_description`, `.md`, and JSON output unchanged for a TOC-enabled post |
| 9. Save-time rewrite / `updated_at` bump | Phase 1 | Idempotency spec; `Blog.maximum(:updated_at)` unchanged after backfill |
| 18. STI (`Article`) inherits schema | Phase 1 + Phase 2 | Explicit decision + a spec covering `Article` rendering |
| 17. Unescaped override labels | Phase 2 — admin override | Spec: label containing `<script>` renders escaped |
| 6. Layout leak into TOC-off posts | **Phase 3 — public layout** (golden-master test lands first) | Golden-master HTML comparison for a TOC-off post, in CI |
| 14. Sticky failures / footer overlap / long TOC | Phase 3 | Manual matrix: 2-heading, 25-heading, short-article, 1280/1024/768px |
| 15. Mobile dropdown semantics / duplicate landmarks | Phase 3 (markup) + Phase 4 (keyboard) | Axe/Lighthouse a11y pass; manual keyboard + VoiceOver run |
| 16. CLS from client-side generation | Phase 3 | TOC present in `view-source`; Lighthouse CLS comparison |
| 10. Scroll-spy boundary/direction bugs | Phase 4 — Stimulus behaviour | Manual test on short-last-section, tall-image, and 2-heading posts |
| 11. Jank + Turbo observer leaks | Phase 4 | DevTools Performance trace; navigate 5 posts and confirm observer count |
| 12. Global smooth scroll / reduced motion | Phase 4 | Grep for `scroll-behavior` outside the scoped selector; OS reduce-motion manual test |
| 13. Hash / back button / focus loss | Phase 4 | Manual: click 3 entries → Back ×3; click an entry → Tab |
| Missing browser-test infrastructure | Phase 4 (or Phase 0 if adopted) | `spec/system` exists with at least a smoke test, **or** a written manual QA checklist is attached to the phase |

---

## Sources

**Verified empirically in this repository (HIGH confidence):**
- `app/models/blog.rb` — `ALLOWED_TAGS`/`ALLOWED_ATTRIBUTES`, `sanitize_body`, `seo_description`
- `app/views/blogs/show.html.erb:76` — second sanitize pass; `max-w-4xl` shared container
- `app/controllers/blogs_controller.rb` — `.md` export via `strip_tags(body)`
- `app/views/api/v1/blogs/show.json.jbuilder` — `content_html @blog.body`
- `app/javascript/application.js` — `turbo:before-cache` → `teardown()` convention
- `app/javascript/controllers/tiptap_editor_controller.js:26` — `heading: { levels: [1,2,3,4,5,6] }`
- `db/migrate/20251216121901_migrate_blog_content_to_rich_text.rb`, `20260513121220_add_body_to_blogs.rb` — content lineage (Trix → Tiptap)
- `db/schema.rb` — `blogs.type` (STI), `blogs.spacing`
- Sanitizer behaviour reproduced via `Rails::Html::SafeListSanitizer` with the project's exact allowlist
- `parameterize` edge cases reproduced via ActiveSupport
- Dev-DB heading audit via Nokogiri over `Blog.find_each` (10 posts; 0 H2/H3; 2 H1; 0 existing IDs) — **dev data; re-run against production**

**Web sources (MEDIUM–HIGH confidence):**
- [Table of Contents with IntersectionObserver — CSS-Tricks](https://css-tricks.com/table-of-contents-with-intersectionobserver/) (incl. comments on TOC depth)
- [Building a Table of Contents with the Intersection Observer API — tj.ie](https://tj.ie/building-a-table-of-contents-with-the-intersection-observer-api/) (acknowledged scroll-up limitation)
- [Getting stuck: all the ways position:sticky can fail — Polypane](https://polypane.app/blog/getting-stuck-all-the-ways-position-sticky-can-fail/)
- [The Weird Parts of position: sticky — Frontend Masters](https://frontendmasters.com/blog/the-weird-parts-of-position-sticky/)
- [How to Fix CSS Position Sticky Not Working in a Flexbox — Designcise](https://www.designcise.com/web/tutorial/how-to-fix-css-position-sticky-not-working-in-a-flexbox)
- [Firefox issue with `scroll-behavior: smooth` and Turbo enabled — hotwired/turbo#1255](https://github.com/hotwired/turbo/issues/1255)
- [Navigate with Turbo Drive — Turbo Handbook](https://turbo.hotwired.dev/handbook/drive)
- [Smooth Scrolling and Accessibility — CSS-Tricks](https://css-tricks.com/smooth-scrolling-accessibility/)
- [Focus management still matters — Sarah Higley](https://sarahmhigley.com/writing/focus-navigation-start-point/)
- [smooth-scroll prevents anchor focus — cferdinandi/smooth-scroll#113](https://github.com/cferdinandi/smooth-scroll/issues/113)
- [Respecting Users' Motion Preferences — Smashing Magazine](https://www.smashingmagazine.com/2021/10/respecting-users-motion-preferences/)
- [Accessible nav drawer disclosure widgets — Make Things Accessible](https://www.makethingsaccessible.com/guides/accessible-nav-drawer-disclosure-widgets/)
- [Navigation — Accessible Web Dev](https://accessibleweb.dev/navigation)

---
*Pitfalls research for: TOC / anchor navigation / scroll-spy on an existing pre-sanitized-HTML Rails CMS*
*Researched: 2026-08-01*
