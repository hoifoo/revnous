---
phase: quick-260612-wgp
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - config/analytics_providers.json
  - app/helpers/analytics_helper.rb
  - app/views/layouts/application.html.erb
  - app/javascript/lib/analytics_providers.js
  - app/javascript/lib/manage_mixpanel.js
  - app/javascript/controllers/cookie_consent_controller.js
  - app/javascript/lib/analytics.js
  - app/javascript/application.js
  - app/views/home/index.html.erb
  - app/views/solutions/show.html.erb
  - app/views/shared/_navigation.html.erb
  - app/views/shared/_footer.html.erb
  - config/routes.rb
  - app/controllers/pages_controller.rb
  - app/views/pages/cookies.html.erb
  - package.json
autonomous: false
requirements:
  - WGP-01
  - WGP-02
  - WGP-03
  - WGP-04
  - WGP-05

must_haves:
  truths:
    - "Enabling a provider requires editing config/analytics_providers.json only (active:true + credential); no UI/JS code change"
    - "Google Analytics is wired into the consent banner and loads only after analytics consent"
    - "Mixpanel ships dormant (active:false, token:null) and never loads or tracks"
    - "A unified RevnousAnalytics.track() dispatches events to consented+active providers, preserving GA event names/props"
    - "Public /cookies page renders a disclosure table from enabled providers"
    - "Bad/malformed JSON fails safe: banner still renders Essential, no crash, error logged"
  artifacts:
    - path: "config/analytics_providers.json"
      provides: "Single source of truth for analytics providers (GA active, Mixpanel dormant w/ EU residency)"
      contains: "google_analytics"
    - path: "app/helpers/analytics_helper.rb"
      provides: "analytics_providers / enabled_analytics_providers / analytics_consent_config_json (fail-safe parse)"
      min_lines: 30
    - path: "app/javascript/lib/analytics_providers.js"
      provides: "JS provider registry keyed by provider.key -> manageFunction"
    - path: "app/javascript/lib/manage_mixpanel.js"
      provides: "Mixpanel manageFunction with EU residency + opt-out-by-default"
    - path: "app/javascript/lib/analytics.js"
      provides: "Unified track() dispatcher exposed as window.RevnousAnalytics"
    - path: "app/views/pages/cookies.html.erb"
      provides: "Public disclosure table from enabled_analytics_providers"
      contains: "enabled_analytics_providers"
  key_links:
    - from: "app/views/layouts/application.html.erb"
      to: "app/javascript/controllers/cookie_consent_controller.js"
      via: "data-providers attribute holding analytics_consent_config_json"
      pattern: "data-providers"
    - from: "app/javascript/controllers/cookie_consent_controller.js"
      to: "app/javascript/lib/analytics_providers.js"
      via: "registry lookup by provider.key"
      pattern: "analytics_providers"
    - from: "app/views/home/index.html.erb"
      to: "app/javascript/lib/analytics.js"
      via: "RevnousAnalytics.track in onclick"
      pattern: "RevnousAnalytics\\.track"
    - from: "config/routes.rb"
      to: "app/controllers/pages_controller.rb"
      via: "get cookies -> pages#cookies"
      pattern: "pages#cookies"
---

<objective>
Make the cookie-consent system config-driven from a single static JSON registry of analytics
providers. GA is live; Mixpanel ships dormant (active:false, no token) with EU data residency
pre-baked. Add a unified `track()` dispatcher, rewire the existing inline `gtag('event',...)`
call sites through it, and publish a public `/cookies` disclosure page rendered from the same JSON.

Purpose: Enabling a new provider becomes a JSON edit (active:true + credential) — zero custom UI/JS
work — while preserving every DSGVO invariant already in place from quick task 260612-vyn.

Output: JSON registry + Rails helper + JS provider registry + Mixpanel manager + rewritten Stimulus
controller + track() dispatcher + rewired call sites + public disclosure page + route + footer link.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/quick/260612-wgp-analytics-providers-config/260612-wgp-RESEARCH.md
@.planning/STATE.md

@app/javascript/controllers/cookie_consent_controller.js
@app/helpers/application_helper.rb
@app/views/layouts/application.html.erb
@app/views/shared/_footer.html.erb
@app/javascript/application.js
@config/routes.rb
@app/controllers/pages_controller.rb

<interfaces>
<!-- Consent lib API (verified, @metamorfosilab/cookies-consent@0.2.9): -->
<!-- new CookiesConsent({ expirationDays, sameSite, position, buttons, content, cookies }) -->
<!-- cookie object: { name, title, description, checked, disabled, onLoad, code, manageFunction, cookies[] } -->
<!-- child cookies cascade; manageGoogleAnalytics({lifecycle,cookie,status,path}) injects gtag + sets consent + anonymize_ip -->
<!-- instance: window.__cookieConsentInstance ; public method toggleSettings() -->
<!-- import: import { CookiesConsent, manageGoogleAnalytics } from "@metamorfosilab/cookies-consent" -->

<!-- Existing inline GA event names/props (MUST preserve verbatim when rewiring through track()): -->
<!-- start_trial_click  { button_location, app_name | solution_slug } -->
<!-- book_demo_click    { button_location, demo_type | product_name | solution_slug } -->
<!-- learn_more_click   { button_location, product_name } -->

<!-- Mount div (app/views/layouts/application.html.erb:85): -->
<!-- <div data-controller="cookie-consent" data-privacy-url="<%= privacy_policy_path %>"></div> -->
<!-- gtag no-op stub already in <head> (lines 56-60) — keep it -->

<!-- 15 inline gtag('event',...) call sites (verified by grep): -->
<!-- home/index.html.erb: lines 14, 17, 226, 233, 530, 533 (233 uses link_to onclick:, others raw onclick=) -->
<!-- solutions/show.html.erb: lines 28, 34, 179, 185 -->
<!-- shared/_navigation.html.erb: lines 33, 36, 189, 192 -->
<!-- shared/_footer.html.erb: line 21 -->
<!-- NOTE 233 + 226 interpolate product.name.gsub("'","\\'"); solutions interpolate @slug — keep ERB intact -->
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Config JSON registry + Rails helper + expose via data attribute</name>
  <files>config/analytics_providers.json, app/helpers/analytics_helper.rb, app/views/layouts/application.html.erb</files>
  <action>
Create `config/analytics_providers.json` using the exact schema from RESEARCH.md section 1: a top-level
`{ "providers": [...] }` with two entries. `google_analytics` — active:true, category "analytics",
config `{ "measurement_id": "G-6ZPXSBZYL8", "anonymize_ip": true }`, cookies (_ga, _ga_*), vendor/privacy
fields. `mixpanel` — active:false, config `{ "token": null, "api_host": "https://api-eu.mixpanel.com",
"region": "eu", "ip": false }` (EU residency baked in), cookies (mp_*), vendor/privacy fields. GA
measurement id and Mixpanel token are PUBLIC client-side tokens — safe to expose. Do NOT add the
`ENV:` indirection (RESEARCH marks it nice-to-have; keep simple).

Create `app/helpers/analytics_helper.rb` with three methods:
- `analytics_providers` — read + parse the JSON file (`Rails.root.join("config/analytics_providers.json")`),
  return the providers array. Memoize per-request; in production memoize across requests (e.g. module-level
  constant or `Rails.cache`), in dev re-read. FAIL SAFE: rescue `JSON::ParserError`/`Errno::ENOENT` →
  `Rails.logger.error(...)` and return `[]` (DSGVO invariant: bad JSON must not crash; banner still
  renders Essential).
- `enabled_analytics_providers` — filter to `active == true` AND required credential present
  (GA: `config["measurement_id"]`; Mixpanel: `config["token"]`). This is the gate that keeps Mixpanel dormant.
- `analytics_consent_config_json` — serialize the BROWSER-NEEDED subset of `enabled_analytics_providers`
  to JSON for the data attribute: key, name, category, description, config, cookies(name+purpose+retention).
  Do NOT leak any server secret — only the public tokens above belong here. Return `[].to_json` when none.

In `app/views/layouts/application.html.erb`, add `data-providers="<%= analytics_consent_config_json %>"`
to the existing cookie-consent mount div (line 85). Keep the gtag no-op stub (lines 56-60) and
`data-privacy-url` intact. Use `html_safe`/standard ERB attribute escaping so the JSON survives in the
attribute (it is already escaped by ERB; verify it parses in browser in Task 5).
  </action>
  <verify>
    <automated>ruby -rjson -e 'JSON.parse(File.read("config/analytics_providers.json")); puts "json ok"' && ruby -rjson -e 'd=JSON.parse(File.read("config/analytics_providers.json")); ga=d["providers"].find{|p| p["key"]=="google_analytics"}; mp=d["providers"].find{|p| p["key"]=="mixpanel"}; abort "GA must be active" unless ga["active"]==true; abort "MP must be dormant" unless mp["active"]==false && mp["config"]["token"].nil?; abort "MP must be EU" unless mp["config"]["api_host"]=="https://api-eu.mixpanel.com" && mp["config"]["ip"]==false; puts "invariants ok"' && grep -q "data-providers" app/views/layouts/application.html.erb && grep -q "def enabled_analytics_providers" app/helpers/analytics_helper.rb && grep -q "rescue" app/helpers/analytics_helper.rb && echo "helper ok"</automated>
  </verify>
  <done>JSON parses; GA active + MP dormant + EU residency asserted; helper has fail-safe rescue and enabled-filter; mount div carries data-providers.</done>
</task>

<task type="auto">
  <name>Task 2: JS provider registry + Mixpanel manager + JSON-driven Stimulus controller + mixpanel-browser dep</name>
  <files>app/javascript/lib/manage_mixpanel.js, app/javascript/lib/analytics_providers.js, app/javascript/controllers/cookie_consent_controller.js, package.json</files>
  <action>
Run `yarn add mixpanel-browser` (latest 2.80.0). Then run `yarn install` in the MAIN tree (lesson from
260612-vyn: worktree install does not populate main node_modules; required for esbuild to bundle it).

Create `app/javascript/lib/manage_mixpanel.js`: export `manageMixpanel({ lifecycle, status, code, config })`
(signature compatible with how the controller invokes managers). Import `mixpanel-browser`. Guard: no-op if
token (`config.token`) is missing. On accept (status true): `mixpanel.init(token, { api_host: config.api_host,
ip: false, opt_out_tracking_by_default: true, persistence: 'localStorage' })` then `mixpanel.opt_in_tracking()`,
and set `window.__analyticsConsent.mixpanel = true`. On reject: `mixpanel.opt_out_tracking()` (clear) and set
`window.__analyticsConsent.mixpanel = false`. EU residency comes from `config.api_host`. DSGVO: no tracking
before consent (opt_out default true + onLoad:false set by controller).

Create `app/javascript/lib/analytics_providers.js`: a registry object keyed by `provider.key` mapping to its
manageFunction — `google_analytics` -> `manageGoogleAnalytics` (imported from the lib), `mixpanel` ->
`manageMixpanel`. Export a `resolveManager(key)` helper returning the function or null.

Rewrite `app/javascript/controllers/cookie_consent_controller.js` to build consent dynamically:
- Keep the Turbo double-init guard (`window.__cookieConsentInstance`) and `toggleSettings()` + `teardown()`.
- Initialize `window.__analyticsConsent = window.__analyticsConsent || {}`.
- Parse `JSON.parse(this.element.dataset.providers || "[]")`; on parse error, fall back to `[]` (fail safe).
- Always include the Essential category (`disabled:true, checked:true`) verbatim from current code.
- Group active providers by `category`; build a category node (e.g. "analytics") whose child `cookies[]` is
  one entry per provider: `{ name: provider.key, title: provider.name, onLoad: false, checked: false,
  code: <credential>, manageFunction: resolveManager(provider.key) }`. For GA pass `code: config.measurement_id`;
  for Mixpanel pass `code: config.token` and the full `config` so manageMixpanel gets api_host.
- Each provider's manageFunction must also set `window.__analyticsConsent[provider.key]` (true on accept, false
  on reject) so the track() dispatcher can read consent. For GA, wrap manageGoogleAnalytics so the consent map
  is updated alongside it (preserve its gtag/anonymize_ip behavior).
- Preserve content/buttons (equal accept/reject), privacy link from `data-privacy-url`.
DSGVO invariants preserved: opt-in (`checked:false`,`onLoad:false`), equal-weight buttons, granular per
provider, no pre-tick. Categories with zero active providers must not render an empty toggle.
  </action>
  <verify>
    <automated>grep -q '"mixpanel-browser"' package.json && test -d node_modules/mixpanel-browser && grep -q "manageMixpanel" app/javascript/lib/manage_mixpanel.js && grep -q "opt_out_tracking_by_default" app/javascript/lib/manage_mixpanel.js && grep -q "resolveManager" app/javascript/lib/analytics_providers.js && grep -q "dataset.providers" app/javascript/controllers/cookie_consent_controller.js && grep -q "__analyticsConsent" app/javascript/controllers/cookie_consent_controller.js && grep -q "onLoad: false\|onLoad:false" app/javascript/controllers/cookie_consent_controller.js && echo "js wiring ok"</automated>
  </verify>
  <done>mixpanel-browser installed in main node_modules; manager has EU residency + opt-out-default + token guard; registry resolves by key; controller builds consent from JSON, keeps Essential + double-init guard, sets consent map, no pre-tick.</done>
</task>

<task type="auto">
  <name>Task 3: Unified track() dispatcher + rewire all 15 inline gtag call sites</name>
  <files>app/javascript/lib/analytics.js, app/javascript/application.js, app/views/home/index.html.erb, app/views/solutions/show.html.erb, app/views/shared/_navigation.html.erb, app/views/shared/_footer.html.erb</files>
  <action>
Create `app/javascript/lib/analytics.js`: ESM exporting `track(event, props)` and assigning
`window.RevnousAnalytics = { track }`. `track` reads `window.__analyticsConsent || {}` and dispatches to each
ACTIVE + CONSENTED provider:
- GA: if `__analyticsConsent.google_analytics` and `window.gtag` → `gtag('event', event, props)`.
- Mixpanel: if `__analyticsConsent.mixpanel` and `window.mixpanel?.has_opted_in_tracking?.()` →
  `mixpanel.track(event, props)`. Import mixpanel-browser lazily or guard on `window.mixpanel` to avoid
  forcing init. Pre-consent: no-op for non-consented providers (events dropped — GDPR-safe).
Import this module in `app/javascript/application.js` (e.g. `import "./lib/analytics"`) so
`window.RevnousAnalytics` exists early and survives Turbo navigations (module-level assignment).

Rewire ALL 15 inline `gtag('event', NAME, {PROPS})` calls to `RevnousAnalytics.track('NAME', {PROPS})`,
preserving event names and props VERBATIM (analytics history depends on parity) and keeping ERB interpolation
intact:
- home/index.html.erb lines 14, 17, 530, 533 (raw onclick=), 226 (raw onclick= with product.name gsub),
  233 (link_to onclick: with `#{product.name.gsub("'","\\'")}`).
- solutions/show.html.erb lines 28, 34, 179, 185 (interpolate `@slug`).
- shared/_navigation.html.erb lines 33, 36, 189, 192.
- shared/_footer.html.erb line 21.
Only swap the `gtag('event', ...)` → `RevnousAnalytics.track(...)` token; do not touch surrounding markup,
classes, hrefs, or ERB. The gtag no-op stub stays in the layout so any missed handler still no-ops safely.
  </action>
  <verify>
    <automated>grep -q "window.RevnousAnalytics" app/javascript/lib/analytics.js && grep -q "__analyticsConsent" app/javascript/lib/analytics.js && grep -q "lib/analytics" app/javascript/application.js && test "$(grep -rc "gtag('event'" app/views/ | awk -F: '{s+=$2} END{print s}')" = "0" && echo "no inline gtag left" && test "$(grep -rho "RevnousAnalytics.track('[a-z_]*'" app/views/ | sort -u | wc -l | tr -d ' ')" = "3" && echo "3 event names preserved" && grep -rq "start_trial_click" app/views/ && grep -rq "book_demo_click" app/views/ && grep -rq "learn_more_click" app/views/ && echo "names intact"</automated>
  </verify>
  <done>track() dispatcher exists, gated on consent map, imported in application.js; zero inline gtag('event' calls remain; exactly 3 distinct event names (start_trial_click/book_demo_click/learn_more_click) routed through RevnousAnalytics.track with props/ERB intact.</done>
</task>

<task type="auto">
  <name>Task 4: Public /cookies disclosure page + route + footer link</name>
  <files>config/routes.rb, app/controllers/pages_controller.rb, app/views/pages/cookies.html.erb, app/views/shared/_footer.html.erb</files>
  <action>
Add route `get "cookies", to: "pages#cookies", as: :cookies` near the impressum route in `config/routes.rb`
(after line 49). Add `def cookies; end` to `app/controllers/pages_controller.rb` (matches the existing
impressum pattern — no body needed).

Create `app/views/pages/cookies.html.erb` rendering a disclosure table from `enabled_analytics_providers`
(so Mixpanel only appears once flipped live). Columns: Tool (name) | Purpose/Category (description + category)
| Cookies (name + retention list) | Processor (privacy.processor) | Transfer basis (privacy.transfer) |
Provider policy (link to privacy.policy_url). Include a short statement: "We do not sell your data; analytics
data is used only for product/UX development." Add a button/link to reopen cookie settings via
`window.__cookieConsentInstance && window.__cookieConsentInstance.toggleSettings()`, plus links to
`privacy_policy_path` and `impressum_path`. Style with existing Tailwind conventions (match
`app/views/pages/impressum` / `legal_documents/show` layout — max-w container, prose-ish headings).

In `app/views/shared/_footer.html.erb`, add a "Cookies" link to `cookies_path` in the bottom-section link
group (line 51-57 area), next to the existing "Cookie Settings" link, using the same
`text-gray-400 hover:text-white transition text-sm` classes.
  </action>
  <verify>
    <automated>grep -q "pages#cookies" config/routes.rb && grep -q "def cookies" app/controllers/pages_controller.rb && grep -q "enabled_analytics_providers" app/views/pages/cookies.html.erb && grep -q "do not sell\|not sold\|don't sell" app/views/pages/cookies.html.erb && grep -q "toggleSettings" app/views/pages/cookies.html.erb && grep -q "cookies_path" app/views/shared/_footer.html.erb && echo "disclosure page wired"</automated>
  </verify>
  <done>/cookies route + pages#cookies action exist; disclosure view iterates enabled_analytics_providers with all columns + no-sell statement + settings reopen; footer links to cookies_path.</done>
</task>

<task type="auto">
  <name>Task 5: Build assets (esbuild + Tailwind) and confirm bundle includes mixpanel-browser</name>
  <files>app/assets/builds/application.js</files>
  <action>
Run `yarn build` (esbuild) and `yarn build:css` (Tailwind CLI). Confirm both succeed with the new
mixpanel-browser dependency bundled (it is imported by manage_mixpanel.js, so esbuild must resolve it even
while dormant — it just won't init without a token). Built assets in app/assets/builds/ are gitignored;
this is a local correctness check (deploy reinstalls + rebuilds). Do not commit the built files. If
`yarn build` fails on the new import, the most likely cause is mixpanel-browser missing from the main
node_modules — re-run `yarn install` in the main tree (per 260612-vyn lesson).
  </action>
  <verify>
    <automated>yarn build && yarn build:css && grep -q "mixpanel" app/assets/builds/application.js && grep -q "RevnousAnalytics\|__analyticsConsent" app/assets/builds/application.js && echo "build ok with mixpanel bundled"</automated>
  </verify>
  <done>yarn build and yarn build:css succeed; bundled application.js contains mixpanel-browser code and the analytics dispatcher; no build errors.</done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <what-built>
Config-driven consent system: JSON provider registry → Rails helper → data-providers attribute →
JSON-driven Stimulus consent banner; unified RevnousAnalytics.track() with all inline gtag calls rewired;
public /cookies disclosure page; Mixpanel shipped dormant with EU residency. All builds pass and greps
confirm wiring + DSGVO invariants in code.
  </what-built>
  <how-to-verify>
Start the app (`bin/dev` or your usual dev server) and verify in the browser:
1. Banner builds from JSON: Load any page → consent banner shows Essential + Analytics > Google Analytics
   only (Mixpanel must NOT appear — it is dormant). Open Settings: equal-weight Accept/Reject, no pre-ticked
   analytics box.
2. GA gates correctly: Before accepting, DevTools Network/Application shows NO _ga cookie and no gtag/GA
   script loaded. Click Accept → GA loads, _ga cookie set. Reload → consent persists.
3. track() fires: With analytics accepted, click a "Start trial" / "Book a demo" / "Learn more" button →
   DevTools shows the GA event sent with the SAME event name + props as before (start_trial_click,
   book_demo_click, learn_more_click). Before accepting, clicking those buttons sends nothing (dropped).
4. Disclosure page renders: Visit /cookies → table lists Google Analytics (Mixpanel absent), shows cookies +
   retention + processor + EU-US DPF transfer + policy link, the "we do not sell your data" statement, a
   working "Cookie Settings" reopen button, and footer "Cookies" link navigates here.
5. Mixpanel stays dormant: Console → `window.mixpanel` is undefined / not initialized; no api-eu.mixpanel.com
   requests. (Sanity: editing the JSON to active:true + a token would enable it with no code change — do not
   actually flip it.)
6. Fail-safe (optional): temporarily corrupt config/analytics_providers.json → reload → banner still shows
   Essential, no JS crash, Rails log shows the parse error. Restore the file after.
  </how-to-verify>
  <resume-signal>Type "approved" or describe issues found.</resume-signal>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| config JSON → browser | analytics_consent_config_json is serialized into a DOM data attribute; only public client tokens may cross |
| user → analytics providers | consent decision gates whether GA/Mixpanel load and track |
| npm registry → bundle | mixpanel-browser added as a dependency and bundled by esbuild |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-wgp-01 | Information Disclosure | analytics_consent_config_json | mitigate | Only emit public client tokens (GA measurement id, Mixpanel browser token); helper builds an explicit allowlisted subset — no server secrets in data-providers |
| T-wgp-02 | Denial of Service | malformed analytics_providers.json | mitigate | Helper rescues JSON::ParserError/ENOENT → [] + log; controller falls back to [] on parse error; banner still renders Essential |
| T-wgp-03 | Tampering | consent bypass / pre-consent tracking | mitigate | onLoad:false + checked:false per provider; Mixpanel opt_out_tracking_by_default:true; track() gated on window.__analyticsConsent map |
| T-wgp-04 | Information Disclosure | Mixpanel data residency | mitigate | api_host pinned to api-eu.mixpanel.com + ip:false baked into JSON config; EU residency enforced at init |
| T-wgp-SC | Tampering | mixpanel-browser npm install | mitigate | mixpanel-browser is a well-known legitimate package (Mixpanel official SDK, ~2.80.0); verified on npmjs.com; not [ASSUMED]/[SUS] |
</threat_model>

<verification>
- `config/analytics_providers.json` parses; GA active, Mixpanel dormant (active:false, token:null) with EU residency.
- Helper fails safe on bad JSON; only public tokens exposed via data-providers.
- Consent banner builds from JSON; Essential always present; no pre-tick; equal buttons (DSGVO).
- track() dispatches only to consented+active providers; all 15 inline gtag calls rewired with names/props intact.
- /cookies disclosure page renders from enabled_analytics_providers; footer links to it.
- `yarn build` + `yarn build:css` succeed with mixpanel-browser bundled.
- Browser checkpoint confirms GA gating, track() firing, disclosure render, Mixpanel dormant.
</verification>

<success_criteria>
- Enabling a provider = JSON edit only (active:true + credential); no UI/JS change required.
- Mixpanel ships dormant with EU residency; GA live and consent-gated.
- All DSGVO invariants preserved (opt-in, equal reject, granular, no pre-tick, EU residency, no pre-consent tracking, fail-safe).
- GA event names/props preserved verbatim through the unified track() dispatcher.
- Public /cookies disclosure page live and linked from footer.
</success_criteria>

<output>
Create `.planning/quick/260612-wgp-analytics-providers-config/260612-wgp-SUMMARY.md` when done
</output>
