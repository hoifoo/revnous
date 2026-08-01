# Feature Research

**Domain:** Blog reading UX — auto-generated Table of Contents with anchor navigation, scroll-spy, and sticky/collapsible placement (Rails + Stimulus, server-rendered)
**Researched:** 2026-08-01
**Confidence:** MEDIUM-HIGH

> Confidence note: the *feature landscape* (what TOC implementations do, what the standard settings are, what breaks) is HIGH — it is a well-trodden pattern with dozens of mature CMS implementations and consistent conventions. The *reference UX* (views4you.com) is LOW confidence: the site returned 403 to automated fetch, so its exact behavior is known only from the user's description. Complexity estimates are HIGH confidence for codebase-specific items (verified against `app/models/blog.rb`, `app/views/blogs/show.html.erb`, `db/schema.rb`).

---

## Already-Settled Scope (Do Not Relitigate)

These are decided in `.planning/PROJECT.md` and are treated as fixed inputs below. This research does **not** re-argue them; it fills the gaps around them.

| Settled decision | Source |
|---|---|
| TOC entries auto-generate from **H2/H3** headings in `blogs.body` | PROJECT.md Active + Key Decisions |
| Admin can **override** generated entries: relabel, reorder, hide | PROJECT.md Active |
| Per-post **opt-in toggle, default OFF**; existing posts must be pixel-identical when off | PROJECT.md Active + Constraints |
| **Sticky sidebar** on desktop/tablet | PROJECT.md Active |
| **Collapsible "Contents" dropdown** above article on mobile | PROJECT.md Active |
| **Smooth scroll** on TOC click | PROJECT.md Active |
| **Scroll-spy** active-section highlighting | PROJECT.md Active |
| Typography/spacing reading pass on blog show page | PROJECT.md Active |
| Multi-page posts, gem extraction, related-posts/search redesign are **out** | PROJECT.md Out of Scope |

Everything in the tables below that overlaps these is marked `[SETTLED]` and listed only so dependencies and complexity are visible to the roadmap.

---

## Feature Landscape

### Table Stakes (Users Expect These)

Missing any of these makes the TOC feel broken, not minimal.

| Feature | Why Expected | Complexity | Notes |
|---|---|---|---|
| `[SETTLED]` TOC list of H2/H3 headings with clickable anchor links | The entire point of a TOC. Every CMS TOC plugin does exactly this. | MEDIUM | Server-side parse of `blogs.body` with Nokogiri. Must be server-rendered, not JS-generated (see anti-features). |
| **Stable, unique `id` on every listed heading** | Anchors don't work without them. `Blog#body` currently has *no* heading IDs (PROJECT.md context confirms). | MEDIUM | **Load-bearing blocker:** `Blog::ALLOWED_ATTRIBUTES` does not include `id`, and `show.html.erb:76` re-sanitizes at render with that same allowlist — so an `id` written at save time is stripped at render. Both the model `sanitize_body` allowlist and the view `sanitize` call must be updated together, or IDs must be injected *after* sanitization at render time. |
| **Slug collision handling for duplicate headings** | Long posts routinely repeat "Conclusion", "Examples", "Step 1". Identical text → identical ID → the second link silently jumps to the first. | LOW | Industry convention (WordPress ToC plugins, Docusaurus, GitHub): kebab-case the text, then append `-2`, `-3` on collision. Dedup must be deterministic across renders. |
| **Fallback slug for headings that slugify to empty** | Emoji-only, CJK, Arabic, or punctuation-only headings `parameterize` to `""` → duplicate empty IDs → all anchors break. | LOW | Fall back to positional `section-1`, `section-2`. Rails `parameterize` is ASCII-only by default; consider `parameterize(locale: nil)` or an explicit empty-check. Cheap to handle, expensive to discover in production. |
| **Anchor-ID stability policy across edits** | Readers and other sites share deep links (`/blog/post#pricing`). If an admin retitles a heading, text-derived IDs silently 404-in-place. | LOW (decision) / MEDIUM (if persisted) | Two viable answers: (a) accept churn — text-derived IDs, documented as unstable, matching Docusaurus/GitHub default; or (b) persist IDs on first publish and never regenerate. **Recommend (a) for v1** — (b) requires an ID-storage side table and is not worth it before the feature has usage. Note the choice explicitly; it also determines how override records are keyed. |
| `[SETTLED]` Per-post opt-in toggle, default OFF, zero regression when off | Hard requirement — existing posts must not shift. | LOW (schema) / MEDIUM (layout gating) | One boolean column. The real work is that the sidebar layout changes `show.html.erb`'s `max-w-4xl` centered column; the TOC-off path must render the **same DOM as today**, not a one-column variant of the new grid. Treat as two distinct templates/branches, not one parameterized layout. |
| **Suppress TOC when there aren't enough headings** | A "Contents" box with one entry looks broken and eats vertical space above the fold. | LOW | Standard: WordPress *Table of Contents Plus* defaults to **4+ headings**; *Easy TOC* similar. For a marketing blog, **3+ visible entries** is a reasonable default. Must count *visible* entries (post-override, post-hide), not raw headings. Also covers "toggle is ON but post has 0 headings". |
| **Deep-link on page load works** (`?`/`#hash` in URL) | Shared links and Google jump-to sitelinks land mid-page. | LOW-MEDIUM | Requires `scroll-margin-top` on headings so the sticky site header doesn't cover the target, and correct initial scroll-spy state (the loaded section should already be highlighted, not "first entry"). Lazy-loaded images above the target (`loading: :lazy` on the hero, `show.html.erb:61`) can shift layout after the jump — reserve space or set explicit dimensions. |
| `[SETTLED]` Smooth scroll on click | Explicit requirement + reference UX. | LOW | Pure CSS: `@media (prefers-reduced-motion: no-preference) { html { scroll-behavior: smooth } }`. ~95% browser support; no JS needed. **Must** be gated on `prefers-reduced-motion` — animated scroll is a known vestibular-disorder trigger (WCAG 2.3.3). |
| **`scroll-margin-top` offset on heading targets** | Without it, every jump parks the heading underneath the sticky site header. Most-reported TOC bug in the wild. | LOW | One CSS rule on `h2, h3` inside `.prose`. Must be re-checked at mobile widths where the dropdown may also be sticky. |
| `[SETTLED]` Mobile collapse to a "Contents" disclosure | A 12-entry list above the fold on mobile pushes the article off-screen. | MEDIUM | Use a real disclosure: `<button aria-expanded aria-controls>` (or `<details>/<summary>`, which gets keyboard + SR semantics free). Must auto-close after an entry is tapped, or the reader lands on the section behind an open panel. |
| **Keyboard + screen-reader basics** | A nav component that only works with a mouse is a defect, not a polish gap. | MEDIUM | Concretely: wrap in `<nav aria-label="Table of contents">`; mark the active entry with `aria-current="true"`; on click, **move focus to the target heading** (`tabindex="-1"` + `.focus()`), otherwise a keyboard user's next Tab continues inside the TOC and the jump did nothing for them; visible `:focus-visible` ring. This is the single most commonly skipped table-stakes item in TOC implementations. |
| `[SETTLED]` Admin override UI: relabel, reorder, hide | Explicit requirement — marketing must fix bad heading labels without code. | MEDIUM-HIGH | The hardest table-stakes item. See "Override reconciliation" below — it is the part that gets underestimated. |
| **Override reconciliation when body headings change** | Admin overrides "Pricing" → "What it costs", then edits the heading. The override is now orphaned or, worse, silently reapplied to the wrong section. | MEDIUM | Universal failure mode of manual TOCs ("stale links frustrate readers more than no TOC at all"). Minimum viable: store overrides keyed by anchor ID; on load, diff stored keys against currently-parsed headings; show removed entries as "no longer in this post — remove?" and new headings as un-overridden defaults. Do **not** silently drop overrides on save. |
| **TOC reflects sanitized, published body only** | Admin previewing draft heads vs public render must not diverge. | LOW | Parse the same string the view renders. Since `sanitize_body` runs `before_save`, parse post-sanitization to avoid extracting headings that get stripped. |

### Differentiators (Polish / Competitive Advantage)

| Feature | Value Proposition | Complexity | Notes |
|---|---|---|---|
| `[SETTLED]` Scroll-spy active-section highlight | The thing that makes a TOC feel "alive"; the visible differentiator in the reference UX. | MEDIUM | Use `IntersectionObserver` in a Stimulus controller. Known pitfalls: last section never highlights (short final section never wins the "topmost intersecting" race), and fast scrolling desyncs. Standard fix is a `rootMargin` band, e.g. `-10% 0px -85% 0px`, so exactly one section is "current". **Do not** use the pure-CSS `scroll-target-group` / `:target-current` approach — it is Chromium-only and explicitly not Baseline (MDN: "not Baseline because it does not work in some of the most widely-used browsers"). It is a valid *progressive enhancement* layer on top, not a replacement. |
| `[SETTLED]` Sticky sidebar positioning | Keeps structure visible through the whole read; the reference pattern. | MEDIUM | `position: sticky; top: <header height>`. Requires a real two-column grid on the show page. Sticky silently fails if any ancestor has `overflow: hidden` — a very common debugging sink. |
| **TOC internal scroll + auto-scroll active item into view** | A 15-entry TOC on a 700px-tall laptop viewport overflows the sticky container; the active item scrolls out of the TOC itself and the highlight becomes invisible. | MEDIUM | `max-height: calc(100vh - offset); overflow-y: auto` plus `scrollIntoView({block:'nearest'})` on the active link. Only matters for long posts — but long posts are exactly the posts that get the TOC turned on. Worth doing in v1 if any post has >10 headings. |
| **H3 nesting / indentation under parent H2** | Communicates document hierarchy, not just a flat list. | LOW-MEDIUM | Two decisions the roadmap must make: (1) how to handle an **orphan H3** that appears before any H2 (Tiptap will happily produce this) — promote it, or nest under a synthetic parent; (2) whether H3s are always visible or only expanded under the active H2. **Recommend always-visible flat-indent for v1** — collapse-under-active is a scroll-spy state machine multiplier. |
| **Heading permalink affordance** (`#` on hover, click to copy) | Lets readers cite a specific section; standard on docs sites. Nearly free once heading IDs exist. | LOW | Pure CSS + tiny Stimulus action. Strong value-per-line-of-code once IDs are in place. |
| **Estimated reading time near the TOC** | Sets expectation on long posts; complements "see structure at a glance". | LOW | Word count from `strip_tags(body)` / 200 wpm. Adjacent to the reading-UX pass already in scope; cheap. |
| **"Back to top" control** | On very long posts, mobile readers have no way back to the collapsed TOC. | LOW | Only worth it if the mobile TOC is *not* sticky. If the mobile dropdown stays pinned, this is redundant — pick one. |
| **Reading progress indicator** | Commonly paired with TOC; signals remaining length. | LOW | **Genuinely contested value.** UX literature is split: claimed completion-rate lift is unverified, and it's frequently criticized as decorative and confusable with page-load progress bars. Cheap to build, so treat as an A/B-able extra — do not put it on the critical path. |
| **Print stylesheet** (hide sticky TOC, or render as flat list) | Marketing blogs get printed/PDF'd for decks and client shares. | LOW | `@media print { .toc-sidebar { display: none } }` at minimum, so a `position: sticky` element doesn't repeat or overlap. |
| **Numbered TOC entries** (1, 2, 2.1) | Scannability; common CMS option. | LOW | Cosmetic. Note it interacts with the reorder feature — numbering must reflect override order, not source order. |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---|---|---|---|
| **H4–H6 in the TOC** | "Be complete." | A 40-entry TOC is worse than none — it stops being scannable, which is the only reason it exists. Every mature plugin ships a depth limit for this reason. | Hard-code H2/H3 (already settled). If a post needs deeper structure, the fix is better headings, not a deeper TOC. |
| **Client-side JS TOC generation** (parse `document` on load) | Simplest to write; no Rails changes; no sanitizer surgery. | TOC is invisible to crawlers and no-JS readers; guaranteed layout shift (CLS) as the TOC pops in after paint; anchors don't exist until JS runs so deep links fail on load. | Server-render the TOC from parsed HTML; JS only adds scroll-spy behavior on top. |
| **Auto-inserting an inline TOC block into `body` HTML** | Matches WordPress plugin behavior; no layout work. | Mutates stored content, so the TOC is baked into `body` and can't be toggled off cleanly — directly violates the zero-regression constraint. Also breaks the Tiptap round-trip. | Render TOC in the view layer only; `body` stays authoritative and untouched apart from heading `id`s. |
| **Fully manual TOC entries** (admin adds arbitrary items not tied to a heading) | "Total control." | Creates entries with no scroll target, which breaks both anchor navigation and scroll-spy; guarantees stale/broken links over time. Auto-generate + override already covers the real need. | Keep overrides strictly *derived* — an override may relabel/reorder/hide a real heading, never invent one. |
| **TOC structured data** (`SiteNavigationElement`, custom `ItemList` of sections) | "More schema = more SEO." | `SiteNavigationElement` describes site-wide nav, not in-page sections; misuse is exactly the pattern that got FAQPage penalized. Google's jump-to sitelinks are generated **algorithmically from real anchor links** and cannot be forced with markup. | Ship clean semantic anchor links and a correct heading hierarchy. That's the actual mechanism for jump-to sitelinks. The existing Article/Breadcrumb/FAQ schema stays as-is. |
| **Persisting per-user TOC state** (collapsed/expanded remembered via localStorage/cookie) | "Respect my preference." | Drags in the project's cookie-consent machinery (see `config/analytics_providers.json` / cookie consent work) for a trivial UI preference, and creates a first-render flicker. | Deterministic defaults: expanded on desktop, collapsed on mobile. No storage. |
| **TOC click analytics in v1** | "Measure engagement." | Adds a consent-gated dependency and event-schema decisions to a feature that isn't shipped yet. Nothing to optimize until there's usage. | Ship it, watch the posts that enable it, add `RevnousAnalytics.track()` later if a question actually arises. |
| **Updating the URL hash as scroll-spy fires** | "Shareable current section." | Spams browser history (back button becomes unusable), and on Turbo Drive can interact badly with restoration visits. | Update hash only on explicit click, via `history.replaceState` (not `pushState`). |
| **Backfilling / auto-enabling TOC on existing posts** | "Why make them click 27 toggles?" | Directly contradicts the default-OFF, zero-regression constraint, and mass-enables the feature on posts whose heading quality was never reviewed. | Default OFF. If bulk enablement is ever wanted, it's a separate admin action with a preview, not a migration. |
| **Floating action button / overlay TOC on mobile** | Saves vertical space; some plugins do it. | Overlays the content it's meant to navigate, competes with cookie-consent banner and CTA elements already on the page, and needs focus trapping to be accessible. Materially more work than a disclosure. | The settled inline "Contents" disclosure above the article. |
| **Extending TOC to case studies / legal documents / index pages** | "Same component, why not." | Scope creep into models with different content shapes and no stated need. Note `Article < Blog` (STI) inherits from `blogs` automatically — that's free and fine; other models are not. | Blog/Article only. Reuse is the deferred gem-extraction project's problem. |
| **Rich TOC entries** (per-section icons, thumbnails, per-section read time) | Visual appeal. | Multiplies admin override surface and turns a navigation aid into a content-authoring task. | Text + hierarchy. That's what the reference UX does. |

---

## Feature Dependencies

```
Stable heading anchor IDs  ← THE root dependency
    ├──required by──> Server-rendered TOC list
    │                     ├──required by──> Smooth scroll on click
    │                     ├──required by──> Sticky sidebar layout
    │                     │                     └──required by──> TOC internal scroll + active-item-into-view
    │                     ├──required by──> Mobile "Contents" disclosure
    │                     ├──required by──> Scroll-spy highlighting
    │                     │                     └──enhanced by──> H3 nesting/indentation
    │                     └──required by──> Admin override (relabel/reorder/hide)
    │                                           └──required by──> Override reconciliation on heading change
    │                                           └──affects──────> Minimum-entry threshold (count AFTER hides)
    ├──required by──> Deep-link-on-load (#hash)
    └──required by──> Heading permalink ("#" copy link)

Sanitizer allowlist accepts `id`  ──required by──> Stable heading anchor IDs
    (BOTH app/models/blog.rb ALLOWED_ATTRIBUTES *and* the second sanitize()
     call in app/views/blogs/show.html.erb:76)

Per-post toggle (default OFF)  ──gates──> ALL of the above on the public page
    └──conflicts with──> Single parameterized layout for show.html.erb

prefers-reduced-motion guard  ──required by──> Smooth scroll (a11y correctness)
scroll-margin-top             ──required by──> Smooth scroll AND deep-link-on-load

Sticky sidebar ──conflicts with──> any ancestor `overflow: hidden` in show.html.erb
Reading progress bar ──independent──> (no dependency on TOC at all; can ship/drop freely)
```

### Dependency Notes

- **Everything requires heading IDs, and heading IDs require two sanitizer changes.** `app/models/blog.rb` strips `id` at save (`ALLOWED_ATTRIBUTES`), and `app/views/blogs/show.html.erb:76` strips it *again* at render with the same list. Changing only one produces a TOC whose links go nowhere, with no error. This is the first thing the roadmap's first phase must resolve. Security note: allowing `id` is low-risk but not zero — DOM-clobbering IDs (`id="body"`, `id="attributes"`, `id="location"`) can shadow document properties. Namespacing generated IDs (e.g. `toc-<slug>`) sidesteps it entirely, at the cost of uglier share URLs.
- **Admin override depends on stable keys, which depends on the ID-stability policy.** If IDs are text-derived and regenerate on every save, overrides keyed by ID orphan themselves whenever a heading is retitled. Pick the ID policy *before* designing the override storage, not after.
- **The minimum-entry threshold must be evaluated after overrides.** A post with 4 headings where the admin hid 2 has 2 visible entries and should suppress the TOC. Counting raw headings gives a one-entry TOC.
- **Toggle-OFF must be a different render path, not a degenerate case of the new grid.** The zero-regression requirement is easiest to guarantee (and to test) if the existing markup is preserved verbatim behind the flag.
- **Scroll-spy and H3-collapse conflict in practice.** Collapsing H3s under the active H2 means the spy drives both highlight state *and* visibility, doubling the state machine and creating layout shift inside the sticky column while reading. Ship flat-indent first.
- **Reading progress bar has zero dependencies** — it is the cleanest thing to cut if the phase runs long.

---

## MVP Definition

### Launch With (v1)

- [ ] `id` permitted through **both** sanitizer passes — unblocks everything else
- [ ] Server-side H2/H3 extraction from sanitized `body` with kebab-case slugs, `-2`/`-3` collision suffixes, and positional fallback for empty slugs
- [ ] Per-post boolean toggle, default OFF; TOC-off render path byte-identical to today
- [ ] Server-rendered TOC list with working anchor links
- [ ] `scroll-behavior: smooth` gated on `prefers-reduced-motion`, plus `scroll-margin-top` on headings
- [ ] Sticky sidebar on desktop/tablet; `<details>`-style "Contents" disclosure on mobile that auto-closes on selection
- [ ] Scroll-spy via IntersectionObserver with a `rootMargin` band; correct initial state on hash-deep-link; correct state at the last section
- [ ] Accessibility floor: `<nav aria-label>`, `aria-current` on active entry, focus moved to the target heading on click, visible `:focus-visible`
- [ ] Minimum-visible-entry threshold (suppress TOC below 3) — covers 0-heading and 1-heading posts
- [ ] Admin: toggle + relabel/reorder/hide, with reconciliation of orphaned overrides when headings change
- [ ] Typography/spacing pass on the show page

### Add After Validation (v1.x)

- [ ] TOC internal scroll + auto-scroll active item into view — **add immediately if any live post has >10 headings**
- [ ] Heading permalink `#` affordance — add once IDs prove stable in production
- [ ] Reading time estimate near the TOC — add with the next copy/typography touch
- [ ] Print stylesheet — add on first report of a mangled print/PDF
- [ ] Numbered entries — add if marketing asks

### Future Consideration (v2+)

- [ ] Reading progress bar — defer; contested value, zero dependencies, easy to add anytime
- [ ] Collapse H3s under the active H2 — defer; scroll-spy complexity multiplier
- [ ] `scroll-target-group` / `:target-current` CSS-only spy as a progressive-enhancement layer — defer until Baseline (currently Chromium-only)
- [ ] TOC engagement analytics — defer; needs a real question first
- [ ] Persisted ID mapping for permanently stable deep links — defer until a heading rename actually breaks an inbound link

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---|---|---|---|
| Sanitizer allowlist accepts `id` (both passes) | HIGH (blocker) | LOW | P1 |
| H2/H3 extraction + slug generation + collision/empty handling | HIGH | MEDIUM | P1 |
| Per-post toggle, default OFF, zero-regression path | HIGH | MEDIUM | P1 |
| Server-rendered TOC with anchor links | HIGH | MEDIUM | P1 |
| Smooth scroll + reduced-motion guard + `scroll-margin-top` | HIGH | LOW | P1 |
| Mobile "Contents" disclosure | HIGH | MEDIUM | P1 |
| Sticky sidebar | HIGH | MEDIUM | P1 |
| Scroll-spy (IntersectionObserver + rootMargin band) | MEDIUM-HIGH | MEDIUM | P1 |
| Keyboard/SR floor (nav label, `aria-current`, focus move) | HIGH | MEDIUM | P1 |
| Minimum-visible-entry threshold | MEDIUM | LOW | P1 |
| Admin override (relabel/reorder/hide) | HIGH | MEDIUM-HIGH | P1 |
| Override reconciliation on heading change | MEDIUM | MEDIUM | P1 |
| Deep-link-on-load correctness | MEDIUM | LOW-MEDIUM | P1 |
| TOC internal scroll + active-into-view | MEDIUM | MEDIUM | P2 |
| H3 flat indentation | MEDIUM | LOW | P2 |
| Heading permalink `#` | MEDIUM | LOW | P2 |
| Reading time estimate | LOW-MEDIUM | LOW | P2 |
| Print stylesheet | LOW | LOW | P2 |
| Numbered entries | LOW | LOW | P3 |
| Back-to-top | LOW | LOW | P3 |
| Reading progress bar | LOW (contested) | LOW | P3 |
| Collapse H3 under active H2 | LOW | MEDIUM | P3 |

---

## Competitor Feature Analysis

| Feature | WordPress ToC plugins (ToC+ / Easy ToC / AIOSEO) | Docs platforms (Docusaurus / Ghost / GitBook) | views4you.com (reference, unverified) | Our Approach |
|---|---|---|---|---|
| Heading source | Configurable H1–H6, admin picks | H2/H3 by default, `toc_min/max_heading_level` config | H2/H3 (per user description) | Fixed H2/H3, no config knob |
| Anchor IDs | Auto-slugified from heading text | Kebab-case of heading text; Docusaurus supports explicit `{#custom-id}` | n/a | Kebab-case + `-2` suffix dedup + `section-N` fallback |
| Duplicate handling | `-2`, `-3` suffixes | Same | n/a | Same (industry-standard, matches inbound-link expectations) |
| Show threshold | Default **4+ headings**, configurable | Always on in docs context | n/a | 3+ **visible** entries, not configurable in v1 |
| Enable model | Auto-insert site-wide, per-post disable | Always on | Appears always-on for long posts | **Inverted:** per-post opt-in, default OFF (backward-compat constraint) |
| Manual editing | Relabel / hide / reorder / edit anchor text without touching content | Not supported (content is the source of truth) | n/a | Relabel / reorder / hide — but never invent entries |
| Placement | Inline block in content, or widget/sidebar | Persistent right rail | Sticky left/right rail | Sticky sidebar desktop, disclosure mobile |
| Scroll-spy | Only in "sticky/floating" premium tiers | Standard | Yes (per user description) | Yes, IntersectionObserver |
| Mobile | Collapsible box or floating FAB | Collapsed disclosure at top | Dropdown above article | Disclosure above article (no FAB) |
| Structured data | Some plugins emit `SiteNavigationElement` | No | n/a | **No TOC schema** — deliberate; plain anchors are what earns jump-to sitelinks |

---

## Open Questions for Requirements

Gaps this research surfaced that the roadmap must decide, not discover:

1. **ID stability policy** — text-derived (churns on rename, matches Docusaurus/GitHub) vs persisted-on-publish (stable, needs storage). Determines override key design.
2. **ID namespacing** — raw slug (`#pricing`, prettier share URLs) vs prefixed (`#toc-pricing`, immune to DOM clobbering).
3. **Where IDs are injected** — at `before_save` in the model (persisted in `body`, one parse per save) vs at render in a helper (nothing persisted, one parse per request, needs fragment caching). Render-time keeps `body` clean and dodges a data migration for existing posts; save-time is faster but needs a backfill.
4. **Override storage shape** — a `jsonb` column on `blogs` (matches the existing `keywords` / `faq_schema` precedent in this codebase) vs a `toc_entries` table. jsonb is consistent with what's already there.
5. **Orphan H3 handling** — an H3 appearing before any H2 (Tiptap permits it).
6. **Exact minimum-entry threshold** — 3 (recommended) vs the WordPress-conventional 4.
7. **Does the mobile disclosure stay sticky while scrolling?** Determines whether "back to top" is needed at all.
8. **`Article < Blog` STI** — the toggle column lives on `blogs` and is inherited automatically. Confirm that's intended, and that `articles` render through the same show template.

---

## Sources

**Feature landscape and conventions (MEDIUM — multiple independent sources agree)**
- WordPress TOC plugin comparisons — heading-level limits, slug generation, duplicate-heading `-2` suffixing, relabel/reorder/hide without altering content: https://www.wpbeginner.com/showcase/best-table-of-contents-plugins-for-wordpress/ , https://www.seedprod.com/best-table-of-contents-wordpress-plugins/ , https://superbthemes.com/blog/best-table-of-contents-plugins-for-wordpress/
- Minimum-heading threshold default of 4 — Table of Contents Plus docs: https://aioseo.com/docs/table-of-contents-plus/ , https://wordpress.org/plugins/easy-table-of-contents/
- Sticky + scroll-spy pattern as the standard "premium" TOC UX: https://css-tricks.com/sticky-table-of-contents-with-scrolling-active-states/ , https://wpeasytools.com/sticky-table-of-contents/

**Anchor ID generation (HIGH — official docs)**
- Docusaurus heading IDs (kebab-case auto-generation + explicit `{#custom-id}` override): https://docusaurus.io/docs/next/markdown-features/toc
- Ghost auto-generates heading `id` attributes: https://www.freecodecamp.org/news/how-to-add-a-table-of-contents-to-your-article-on-ghost/

**Accessibility (HIGH — W3C/MDN/web.dev)**
- WCAG 2.1 SC 2.3.3 Animation from Interactions (motion-triggered vestibular reactions): https://www.w3.org/WAI/WCAG21/Understanding/animation-from-interactions.html
- `prefers-reduced-motion`: https://developer.mozilla.org/docs/Web/CSS/Reference/At-rules/@media/prefers-reduced-motion
- Smooth scrolling and focus management for anchor links: https://css-tricks.com/smooth-scrolling-accessibility/
- Keyboard focus / `:focus-visible` guidance: https://web.dev/learn/accessibility/focus/

**Scroll-spy implementation (MEDIUM-HIGH)**
- IntersectionObserver scroll-spy pitfalls (multi-intersect, fast-scroll desync, `rootMargin` band technique): https://blog.maximeheckel.com/posts/scrollspy-demystified/ , https://yashmahalwal.medium.com/scrollspy-using-intersection-observer-36acb7520e46
- CSS-only scroll-spy is **not** production-viable — `:target-current` is experimental, Chromium-only, not Baseline (HIGH, MDN): https://developer.mozilla.org/en-US/docs/Web/CSS/:target-current ; context: https://www.sarasoueidan.com/blog/css-scrollspy/

**SEO / structured data (MEDIUM)**
- Jump-to sitelinks are algorithmic, derived from real anchor links, not from markup: https://www.sebkln.de/en/tutorials/seo-jump-links/ , https://pixis.ai/blog/does-a-table-of-contents-help-seo-and-ai-citations/
- Structured-data misuse pattern (FAQPage precedent; markup must describe visible content): https://joost.blog/faq-schema-cycle/ , https://developers.google.com/search/docs/appearance/structured-data/article

**Reading progress bar (LOW-MEDIUM — genuinely contested)**
- Pro/con analysis, "solely eye candy" critique, confusion with load progress: https://uxdesign.cc/pros-and-cons-of-progress-indicator-as-a-scroll-bar-345f19967cb6
- Implementation reference: https://css-tricks.com/reading-position-indicator/

**Stale manual TOC failure mode (MEDIUM)**
- Manual TOC entries desync from headings; "stale links frustrate readers more than no TOC at all": https://blog.markdowntools.com/posts/how-to-create-table-of-contents-in-markdown

**Codebase (HIGH — direct inspection)**
- `app/models/blog.rb` — `ALLOWED_TAGS` / `ALLOWED_ATTRIBUTES` (no `id`), `sanitize_body` `before_save`, `keywords` jsonb + `faq_schema` text precedent
- `app/views/blogs/show.html.erb:76` — second `sanitize` call at render with the same allowlist
- `db/schema.rb` — `blogs` table, `type` column (STI), `spacing` column precedent for per-post display flags
- `app/models/article.rb` — `Article < Blog` STI subclass
- `app/javascript/controllers/` — existing Stimulus controllers (`tiptap_editor`, `cookie_consent`, `faq_builder`, `keywords_input`)

**Reference UX (LOW — not directly verifiable)**
- https://views4you.com/blog/move-tiktok-audience-to-instagram/ — returned HTTP 403 to automated fetch. Sticky sidebar + scroll-spy + smooth-scroll behavior is per the user's description only. Verify visually during implementation if exact details matter.

---
*Feature research for: blog Table of Contents & reading UX*
*Researched: 2026-08-01*
