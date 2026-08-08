# Phase 3: Reading Navigation Behavior - Pattern Map

**Mapped:** 2026-08-08
**Files analyzed:** 11 (4 new source, 3 new spec, 4 modified)
**Analogs found:** 10 / 11

## File Classification

| New/Modified File | New/Mod | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|---------|------|-----------|----------------|---------------|
| `app/javascript/controllers/toc_controller.js` | NEW | stimulus controller | event-driven (DOM observer + click) | `app/javascript/controllers/cookie_consent_controller.js` | role-match |
| `app/views/blogs/_toc_disclosure.html.erb` | NEW | view partial (component) | request-response (server render) | `app/views/blogs/_toc_sidebar.html.erb` | exact |
| `app/views/blogs/_toc_sidebar.html.erb` | MOD | view partial (component) | request-response | itself (Phase 2) | exact (self) |
| `app/views/blogs/show.html.erb` | MOD | view template | request-response | itself, lines 76-85 | exact (self) |
| `app/javascript/controllers/index.js` | MOD (generated) | config/registry | n/a | itself, lines 19-20 | exact (self) |
| `spec/system/blogs/toc_navigation_spec.rb` | NEW | system test | event-driven (browser) | `spec/requests/blogs_toc_spec.rb` | partial (no system spec exists) |
| `spec/system/blogs/toc_scroll_spy_spec.rb` | NEW | system test | event-driven (browser) | `spec/requests/blogs_toc_spec.rb` | partial |
| `spec/system/blogs/toc_disclosure_spec.rb` | NEW | system test | event-driven (browser) | `spec/requests/blogs_toc_spec.rb` | partial |
| `spec/support/system.rb` | NEW | test config | n/a | `spec/support/devise.rb` | exact |
| `spec/factories/blogs.rb` | MOD (optional) | factory | n/a | itself | exact (self) |
| `.github/workflows/ci.yml` | MOD (optional, RESEARCH Open Q2) | CI config | n/a | itself, lines 99-105 | exact (self) |

**Read-only reference (must NOT be edited this phase):** `app/views/shared/_navigation.html.erb` lines 261-278 — the legacy handler the new controller must out-rank via capture-phase `stopPropagation()`. RESEARCH Open Question 1 recommends explicitly *not* fixing it here.

---

## Pattern Assignments

### `app/javascript/controllers/toc_controller.js` (NEW — stimulus controller, event-driven)

**Primary analog:** `app/javascript/controllers/cookie_consent_controller.js` (structure, lifecycle, comment style, `teardown()`)
**Secondary analogs:** `app/javascript/controllers/keywords_input_controller.js` (`static targets`, read DOM in `connect()`, no-`innerHTML` rule), `app/javascript/controllers/faq_builder_controller.js` (event handler + `closest()`)

**Imports + class declaration + connect-comment convention** — copy from `cookie_consent_controller.js` lines 1-13:
```javascript
import { Controller } from "@hotwired/stimulus"
import { CookiesConsent, manageGoogleAnalytics, darkTheme } from "@metamorfosilab/cookies-consent"
import { resolveManager } from "../lib/analytics_providers"

// Connects to data-controller="cookie-consent"
export default class extends Controller {
  connect() {
```
Copy the anonymous-default-export form (`export default class extends Controller`) and the `// Connects to data-controller="..."` header comment verbatim in style. For TOC: `// Connects to data-controller="toc"`. **Do not** copy the `window.__*` globals — CONTEXT.md and RESEARCH.md both forbid global state for this controller.

**`static targets` + read-the-DOM-in-connect pattern** — copy from `keywords_input_controller.js` lines 3-12:
```javascript
export default class extends Controller {
  static targets = ["input", "chipContainer"]

  connect() {
    // Read existing hidden inputs (pre-rendered by ERB on page load)
    this._keywords = Array.from(
      this.element.querySelectorAll("input[type=hidden]")
    ).map(i => i.value)
    this.renderChips()
  }
```
This is the exact shape the TOC controller needs: server-rendered markup is the source of truth, `connect()` reads it into instance state. TOC equivalent: `static targets = ["link", "disclosure", "summary", "sidebarScroller"]`, then resolve `this.headings` from `this.linkTargets` via `document.getElementById(decodeURIComponent(a.hash.slice(1)))`.

**No-`innerHTML` XSS convention** — the project already states this inline; copy the intent and the comment style from `keywords_input_controller.js` lines 59-62:
```javascript
      // Keyword text — using textContent (never innerHTML) to prevent XSS
      const labelSpan = document.createElement("span")
      labelSpan.textContent = kw
      chip.appendChild(labelSpan)
```
For TOC this hardens into a stronger rule (RESEARCH Security Domain): render **nothing** client-side; only toggle `aria-current` and call scroll/focus APIs.

**Event handler with `preventDefault()` + `closest()` delegation** — copy from `faq_builder_controller.js` lines 6-16:
```javascript
  addRow(event) {
    event.preventDefault()
    const fragment = this.templateTarget.content.cloneNode(true)
    this.rowContainerTarget.appendChild(fragment)
    this.rowContainerTarget.lastElementChild?.querySelector('input[type=text]')?.focus()
  }

  removeRow(event) {
    event.preventDefault()
    event.currentTarget.closest('[data-faq-row]')?.remove()
  }
```
This is the project's established action-method shape (short, `event.preventDefault()` first, `closest()` for delegation, optional chaining). `navigate(event)` follows it, with the phase-specific addition of `event.stopPropagation()` **before** `preventDefault()` (RESEARCH Pitfall 1 — measured as the only working suppression of the legacy handler).

**Public-actions-then-helpers ordering with explanatory comments** — `cookie_consent_controller.js` lines 69-79 and 99-109 show the convention: helper methods sit below the lifecycle/action methods, each preceded by a 2-4 line `//` comment explaining *why*, not *what*:
```javascript
  // Debug helper: visiting any page with ?cookie_consent=reset clears the
  // stored consent and reshows the banner, so the consent flow can be
  // re-tested without manually clearing cookies/storage.
  maybeResetForDebug() {
```
```javascript
  // Parses the JSON provider config from data-providers. Fails safe to []
  // so the banner still renders the Essential category on bad JSON.
  parseProviders() {
    try {
      const parsed = JSON.parse(this.element.dataset.providers || "[]")
      return Array.isArray(parsed) ? parsed : []
    } catch {
      console.error("ERROR: failed to parse analytics providers config")
      return []
    }
  }
```
Order for `toc_controller.js`: `connect()` → `disconnect()` → `navigate()` → `closeDisclosureAndRestoreFocus()` → then commented helpers `recomputeActive()` / `markActive()` / `atBottom()` / `focusHeading()` / `keepEntryVisible()` / `closeDisclosure()` / `get scrollBehavior()` → `teardown()` last.

**`teardown()` method** — copy the name and terminal position from `cookie_consent_controller.js` lines 159-161:
```javascript
  teardown() {
    this.consent = null
  }
}
```
This is not decorative: `app/javascript/application.js` lines 9-13 walks every connected controller on `turbo:before-cache` and calls `teardown()` if defined:
```javascript
document.addEventListener('turbo:before-cache', () => {
  application.controllers.forEach(c => {
    if (typeof c.teardown === 'function') c.teardown()
  })
})
```
So `toc_controller` MUST expose `teardown()` (idempotent) and call it from `disconnect()` — that satisfies success criterion #5 through an existing project convention rather than a new one.

**Anti-pattern present in the analog — do NOT copy:** `cookie_consent_controller.js` lines 8-13 and 64 store state on `window.__cookieConsentInstance` / `window.__analyticsConsent` and early-return on re-connect. That singleton behaviour is specific to the third-party consent widget. The TOC controller keeps all state on the instance (`this.observer`, `this.passed`, `this.activeHeading`) and `connect()` must be safe to run repeatedly.

---

### `app/views/blogs/_toc_disclosure.html.erb` (NEW — view partial, request-response)

**Analog:** `app/views/blogs/_toc_sidebar.html.erb` — **exact** structural match (same `entries` local, same loop, same anchor/label/level handling). Copy it and change the wrapper element + responsive gate.

**Full analog, lines 1-23:**
```erb
<% if entries.any? %>
  <div class="hidden lg:block lg:col-start-2 lg:row-start-1 lg:self-start lg:sticky lg:top-8 lg:max-h-[calc(100vh-4rem)] lg:overflow-y-auto">
    <nav aria-label="Table of contents">
      <p class="text-sm font-semibold uppercase tracking-wide text-gray-900 mb-4">Table of Contents</p>
      <ol role="list" class="list-none space-y-2 pl-0">
        <% entries.each do |entry| %>
          <li class="<%= entry.level == 3 ? 'pl-4' : '' %>">
            <% link_classes = [
                 'block no-underline transition-colors rounded-sm',
                 'hover:text-pink-600',
                 'focus-visible:text-pink-600 focus-visible:ring-2',
                 'focus-visible:ring-pink-600 focus-visible:ring-offset-2',
                 (entry.level == 3 ? 'text-sm text-gray-500' : 'text-base text-gray-900')
               ].join(' ') %>
            <%= link_to "##{entry.anchor}", class: link_classes do %>
              <%= sanitize(entry.label_html, tags: %w[strong em code], attributes: []) %>
            <% end %>
          </li>
        <% end %>
      </ol>
    </nav>
  </div>
<% end %>
```

**Copy verbatim into the disclosure:**
- the `<% if entries.any? %>` guard
- the `entry.level == 3 ? 'pl-4' : ''` indent expression
- the `link_classes` array-then-`.join(' ')` idiom (this is the file's own style for multi-class links)
- `link_to "##{entry.anchor}", ... do` + `sanitize(entry.label_html, tags: %w[strong em code], attributes: [])` — **never** `raw`/`html_safe`; the allowlist must stay exactly these three tags
- `<nav aria-label="Table of contents">` + `<ol role="list" class="list-none space-y-2 pl-0">`

**Change for the disclosure:**
- outer element `<div class="hidden lg:block ...">` → `<details class="lg:hidden group ..." data-toc-target="disclosure" data-action="keydown.esc->toc#closeDisclosureAndRestoreFocus">` (RESEARCH Pitfall 6: `toggle` does not bubble, so any `toggle` action must live on `<details>` itself)
- the `<p>Table of Contents</p>` heading → `<summary data-toc-target="summary">Contents</summary>` (D-07)
- add `data: { toc_target: "link" }` to the `link_to` call

**Comment style for view partials:** `app/views/blogs/_faq_section.html.erb` lines 1-11 shows the project's minimal ERB partial — `if`-guard at top, semantic element with `aria-labelledby`/`aria-label`, no ERB comments. Match that terseness; do not add explanatory ERB comments the neighbouring partials don't have.

---

### `app/views/blogs/_toc_sidebar.html.erb` (MODIFIED)

**Analog:** itself. Additive-only edits; the existing class strings are load-bearing (Phase 2 measured them, RESEARCH Pitfall 3).

- Line 2 wrapper `<div class="hidden lg:block ... lg:overflow-y-auto">` — add `data-toc-target="sidebarScroller"`. **Do not change any class** — `lg:sticky` / `lg:max-h-[calc(100vh-4rem)]` / `lg:overflow-y-auto` are what make `scrollIntoView({block:'nearest'})` safe (RESEARCH Pattern 6, A3).
- Line 15 `link_to` — add `data: { toc_target: "link" }`.
- Line 8-14 `link_classes` array — append the active-state variant into the existing array (keep the array-join idiom, one class group per string):
  ```ruby
  'aria-[current]:text-pink-600 aria-[current]:font-semibold',
  ```
  (`aria-[current]:` attribute-presence variant is compile-verified against tailwindcss 4.1.14 — RESEARCH "Tailwind v4 variants".)

---

### `app/views/blogs/show.html.erb` (MODIFIED)

**Analog:** itself, lines 76-85 — the existing `article.toc?` conditional wrapper Phase 2 introduced:
```erb
<% if article.toc? %>
    <div class="lg:grid lg:grid-cols-[minmax(0,1fr)_16rem] lg:gap-12">
      <%= render "blogs/toc_sidebar", entries: article.toc_entries %>
<% end %>
    <div class="prose prose-lg <%= article.toc? ? 'lg:col-start-1 lg:row-start-1 prose-h2:mt-16 prose-h3:mt-12 prose-headings:scroll-mt-8' : 'max-w-none' %> mb-16 <%= 'prose-paragraph-relaxed' if @blog.spacing == 'relaxed' %>">
      <%= article.html %>
    </div>
<% if article.toc? %>
    </div>
<% end %>
```

**Patterns to preserve:**
- The `<% if article.toc? %>` gate is the backward-compatibility contract (CLAUDE.md: "existing posts render identically until enabled"). Every new element — the `data-controller="toc"` wrapper, the disclosure render — goes **inside** this branch. A TOC-off post must emit zero new attributes.
- Partial render call style: `<%= render "blogs/toc_sidebar", entries: article.toc_entries %>` — copy exactly for `<%= render "blogs/toc_disclosure", entries: article.toc_entries %>`.
- `prose-headings:scroll-mt-8` on line 80 stays untouched — it is the verified 32px landing offset (RESEARCH Open Q4).
- HTML comment section markers (`<!-- Content -->`, line 75) are this file's separator convention; add `<!-- Mobile Contents disclosure -->` in the same style.

**New:** the `data-controller="toc" data-action="click->toc#navigate:capture"` wrapper must enclose **both** the disclosure and the sidebar and the `div.prose` (headings live inside `div.prose`; `focusHeading`/`getElementById` are document-scoped but the click-capture ancestor must contain every TOC link). Adding a wrapper `<div>` around the grid changes `div.prose`'s ancestry — `spec/support/golden_master.rb` line 43 selects `Nokogiri::HTML5(html).at_css("div.prose")` (Layer A, byte-exact on the element itself) so a new ancestor is safe, but Layer B (full-page normalized) **will** diff. Expect to regenerate with `UPDATE_GOLDEN=1 bundle exec rspec spec/requests/blogs_golden_master_spec.rb` and review — the file documents this at lines 12-15.

---

### `app/javascript/controllers/index.js` (MODIFIED — auto-generated)

**Analog:** itself, lines 1-8 and 19-20:
```javascript
// This file is auto-generated by ./bin/rails stimulus:manifest:update
// Run that command whenever you add a new controller or create them with
// ./bin/rails generate stimulus controllerName

import { application } from "./application"

import HelloController from "./hello_controller"
application.register("hello", HelloController)
```
```javascript
import CookieConsentController from "./cookie_consent_controller"
application.register("cookie-consent", CookieConsentController)
```
**Do not hand-edit.** Run `bin/rails stimulus:manifest:update`, then `npm run build`. Expected output: `import TocController from "./toc_controller"` + `application.register("toc", TocController)`.

---

### `spec/system/blogs/*_spec.rb` (NEW — system tests)

**No system spec exists in this repo** — `spec/` contains only `factories/ fixtures/ helpers/ models/ requests/ support/ views/`. Closest analog is the request spec that covers the same feature.

**Analog:** `spec/requests/blogs_toc_spec.rb`

**Explicit type declaration + `let(:body)` fixture idiom** (lines 1-9) — this is mandatory, not stylistic: `spec/rails_helper.rb` line 71 has `config.infer_spec_type_from_file_location!` **commented out**, so an untyped `spec/system/*_spec.rb` gets no Capybara DSL (RESEARCH Pitfall 8):
```ruby
require 'rails_helper'

RSpec.describe "Blog TOC anchor injection", type: :request do
  # Exercises every branch at once: H1 (untouched), H2 "Intro" (twice, to
  # force the dedup suffix), a paragraph, H3 "Detail", and H4 (untouched).
  let(:body_html) do
    "<h1>Title</h1><h2>Intro</h2><p>Some paragraph text.</p>" \
      "<h3>Detail</h3><h4>Sub</h4><h2>Intro</h2>"
  end
```
Copy: `require 'rails_helper'` (single quotes), a prose `RSpec.describe "…"` string, **explicit `type:`** → use `type: :system`, and one commented `let` per fixture shape explaining what branch it exercises.

**Blog creation + describe-block structure** (lines 33-45) — copy the `create(:blog, slug:, body:, toc_enabled: true, published_at: 1.day.ago)` call shape and the requirement-ID-tagged `describe` string:
```ruby
  describe "rendered response (TOC-03, success criterion #2)" do
    let(:blog) do
      create(:blog, slug: "anchor-on-post", body: body_html, toc_enabled: true,
                    published_at: 1.day.ago)
    end

    it "injects unescaped, unique toc- anchors on H2/H3 in document order" do
      get blog_path(blog.slug)

      expect(response.body).to include('<h2 id="toc-intro">')
```
For system specs, `get blog_path(blog.slug)` becomes `visit blog_path(blog.slug)`; everything else (explicit slug per example group to avoid collisions, `published_at: 1.day.ago` so the post is in the `published` scope, requirement IDs in the describe string) carries over unchanged.

**Phase-specific additions with no analog** (take verbatim from RESEARCH "Code Examples"):
- `before { driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1000] }` — **not** `driven_by :selenium_chrome_headless` (RESEARCH Pitfall 4: `screen_size` silently ignored on that path)
- `page.evaluate_script(...)` for `document.activeElement.id`, `getBoundingClientRect().top`, `getComputedStyle(document.documentElement).scrollBehavior`
- `page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [...])` for reduced-motion
- a file-header comment noting `npm run build && npm run build:css` is a local precondition (RESEARCH Pitfall 3)

---

### `spec/support/system.rb` (NEW — test config)

**Analog:** `spec/support/devise.rb` — **exact** match for role (a `spec/support/*.rb` file that configures behaviour for one spec type). It is auto-required by `spec/rails_helper.rb` line 30 (`Rails.root.glob('spec/support/**/*.rb')`), so no wiring is needed.

**Full analog, lines 1-22:**
```ruby
RSpec.configure do |config|
  # Include Devise test helpers for request specs
  config.include Devise::Test::IntegrationHelpers, type: :request

  # Ensure Warden is configured and routes are available
  config.before(:suite) do
    # Ensure routes are loaded
    Rails.application.reload_routes!
  end

  # Ensure Warden is configured properly for each test
  config.before(:each, type: :request) do
    host! 'www.example.com'
  end
```
Copy: top-level `RSpec.configure do |config|`, one-line `#` comment above each block, and the `type:`-filtered `config.before(:each, type: :xxx)` shape → `config.before(:each, type: :system) { driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1000] }`, plus `Capybara.save_path = Rails.root.join("tmp/screenshots")` (RESEARCH Pitfall 9 / Open Q2).

`spec/support/golden_master.rb` line 66 shows the alternate one-liner form for the same idea, if the file ends up module-shaped:
```ruby
RSpec.configure { |c| c.include GoldenMaster, type: :request }
```

**Note:** `spec/rails_helper.rb` line 14 already has `require 'capybara/rspec'`, and lines 51 + 78-88 (`use_transactional_fixtures = true` + DatabaseCleaner `:transaction`) were **verified working with a real browser** during research — do not modify `rails_helper.rb` beyond what a system spec actually needs, and do not uncomment line 71.

---

### `spec/factories/blogs.rb` (MODIFIED — optional)

**Analog:** itself, lines 1-19:
```ruby
FactoryBot.define do
  factory :blog do
    sequence(:title) { |n| "Blog Post #{n}" }
    sequence(:slug) { |n| "blog-post-#{n}" }
    body { "<p>Blog post content with lots of interesting information.</p>" }
```
If the ~24-heading INTX-03 fixture (RESEARCH Open Q3) is worth reusing across the three system specs, add a **trait** here rather than a new factory — but note that all existing TOC specs build bodies via inline `let(:body_html)` in the spec file (see `spec/requests/blogs_toc_spec.rb` lines 6-31), which is the established convention. Prefer inline `let` unless the fixture is shared across all three spec files.

---

## Shared Patterns

### Stimulus controller registration + build
**Source:** `app/javascript/controllers/index.js` (generated), `.github/workflows/ci.yml` lines 86-89
**Apply to:** the new controller
```bash
bin/rails stimulus:manifest:update
npm run build && npm run build:css
```
CI already runs both build steps before `bundle exec rspec` (ci.yml lines 86-97), so CI is safe. Local runs are not — `app/assets/builds/*` is gitignored and was measured stale.

### Turbo teardown contract
**Source:** `app/javascript/application.js` lines 9-13
**Apply to:** any controller holding observers/listeners
```javascript
document.addEventListener('turbo:before-cache', () => {
  application.controllers.forEach(c => {
    if (typeof c.teardown === 'function') c.teardown()
  })
})
```
Implement `teardown()` (idempotent) + call it from `disconnect()`. Existing precedent: `cookie_consent_controller.js` lines 159-161.

### Server-rendered, sanitized TOC labels
**Source:** `app/views/blogs/_toc_sidebar.html.erb` line 16
**Apply to:** the new disclosure partial; forbidden in JS
```erb
<%= sanitize(entry.label_html, tags: %w[strong em code], attributes: []) %>
```
The tag allowlist is fixed. The Stimulus controller must never render entry markup (RESEARCH Security Domain, V5).

### Anchor resolution
**Source:** RESEARCH anti-patterns; enforced against `_toc_sidebar.html.erb` line 15's `link_to "##{entry.anchor}"`
**Apply to:** every heading lookup in JS
```javascript
document.getElementById(decodeURIComponent(link.hash.slice(1)))
```
Never `querySelector("#" + id)`; never re-derive anchors in JS (Phase 1 owns derivation).

### Explicit spec type
**Source:** `spec/requests/blogs_toc_spec.rb` line 3, `spec/rails_helper.rb` line 71
**Apply to:** all three new system specs
```ruby
RSpec.describe "Blog TOC navigation", type: :system do
```
`infer_spec_type_from_file_location!` is commented out project-wide; leave it that way.

### Golden-master regeneration workflow
**Source:** `spec/support/golden_master.rb` lines 12-15, 50-63
**Apply to:** any `show.html.erb` wrapper change
```
UPDATE_GOLDEN=1 bundle exec rspec spec/requests/blogs_golden_master_spec.rb
```
Then review the diff under `spec/fixtures/golden_master/` before committing. Layer A (`div.prose`, byte-exact) should be unchanged by a new ancestor; Layer B (full page) will diff.

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `spec/system/blogs/*_spec.rb` (3 files) | system test | event-driven (browser) | No `spec/system/` directory exists — this phase creates the first. `spec/requests/blogs_toc_spec.rb` supplies the naming/structure/factory conventions, but every Capybara-specific construct (`driven_by`, `visit`, `evaluate_script`, `execute_cdp`, `resize_to`) must come from RESEARCH.md "Code Examples", which contains verified-working versions of all of them. |

Partially-novel code inside `toc_controller.js` with no in-repo analog — take verbatim from RESEARCH.md, not from any existing controller:
- IntersectionObserver extended-above `rootMargin` band (Pattern 1)
- `atBottom()` bottom-of-page override + passive scroll listener (Pattern 2)
- capture-phase `stopPropagation()` click ownership (Pattern 3 / Pitfall 1)
- Turbo's transient-`tabindex` `focusHeading()` (Pattern 3, sourced from `@hotwired/turbo` `View#focusElement`)
- `scrollIntoView({block:'nearest'})` sidebar containment (Pattern 6)

---

## Metadata

**Analog search scope:** `app/javascript/controllers/`, `app/views/blogs/`, `app/views/shared/`, `spec/`, `spec/support/`, `.github/workflows/`
**Files scanned:** 16 (5 Stimulus controllers + JS entry point, 4 blog views, 1 shared view region, rails_helper + 2 support files + 1 request spec + 1 factory, ci.yml)
**Pattern extraction date:** 2026-08-08
