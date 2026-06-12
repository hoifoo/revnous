---
title: Spec/Research — Config-driven analytics providers (GA live, Mixpanel dormant) w/ unified track() + public disclosure
quick_id: 260612-wgp
date: 2026-06-12
---

# Goal

Make the cookie-consent system **config-driven**: a single static JSON registry of analytics
providers drives (a) the consent banner categories, (b) which scripts load on consent, (c) a
unified `track()` event dispatcher, and (d) a public "what we track" disclosure table.

**Hard requirement from user:** enabling a NEW provider (e.g. Mixpanel) must require *no custom UI
work* — edit the JSON only. GA is live now; Mixpanel is dormant (`active:false`, no token) until the
project is registered. EU data residency required for Mixpanel.

Builds directly on quick task 260612-vyn (the `@metamorfosilab/cookies-consent` integration already
in place — see `app/javascript/controllers/cookie_consent_controller.js`, currently HARDCODES the
GA cookie). This task replaces that hardcoding with JSON-driven config.

# Existing state (verified)

- Consent lib: `@metamorfosilab/cookies-consent@0.2.9` already installed + wired (quick 260612-vyn).
  - `cookie_consent_controller.js` hardcodes `cookies: [essential, analytics>google-analytics]`.
  - Lib API (verified): `new CookiesConsent({buttons, content, cookies, ...})`; cookie object supports
    `name,title,description,checked,disabled,onLoad,code,manageFunction,cookies[]`; child cookies cascade.
  - Built-in `manageGoogleAnalytics({lifecycle,cookie,status,path})` injects gtag + sets consent + anonymize_ip. Use for GA.
  - Public method `toggleSettings()` (footer reopen). Instance on `window.__cookieConsentInstance`.
- Layout `app/views/layouts/application.html.erb`: no-op gtag/dataLayer stub in <head> (line ~56-59);
  mount `<div data-controller="cookie-consent" data-privacy-url="<%= privacy_policy_path %>">` (~line 85).
- **15 inline `gtag('event', ...)` call sites** across: `app/views/home/index.html.erb`,
  `app/views/solutions/show.html.erb`, `app/views/shared/_navigation.html.erb`, `app/views/shared/_footer.html.erb`.
  Event names in use: `start_trial_click`, `book_demo_click`, `learn_more_click` (each with a props object).
- Footer `_footer.html.erb`: `#cookie-settings-link` calls `window.__cookieConsentInstance.toggleSettings()`.
- Routes: `privacy_policy_path` -> legal_documents#privacy_policy; `impressum_path` -> pages#impressum.
  Legal docs render `app/views/legal_documents/show.html.erb`. Pages controller exists (pages#impressum).
- Helpers live in `app/helpers/application_helper.rb`. Stimulus controllers registered in `app/javascript/controllers/index.js`.
- JS build: esbuild (`yarn build`) bundles `app/javascript/*`; CSS via Tailwind CLI (`yarn build:css`). Built assets in `app/assets/builds/` are GITIGNORED (rebuilt at deploy).
- `mixpanel-browser` latest = 2.80.0 (add as dep so enabling Mixpanel is zero-code).

# Design

## 1. Config registry — `config/analytics_providers.json`

Single source of truth. Schema per provider:

```json
{
  "providers": [
    {
      "key": "google_analytics",
      "name": "Google Analytics",
      "vendor": "Google Ireland Ltd.",
      "category": "analytics",
      "active": true,
      "description": "Measures site usage (pages, events) so we can improve UX. Data is not sold; used only for product/UX development.",
      "config": { "measurement_id": "G-6ZPXSBZYL8", "anonymize_ip": true },
      "cookies": [
        { "name": "_ga",  "purpose": "Distinguish users", "retention": "13 months" },
        { "name": "_ga_*","purpose": "Persist session state", "retention": "13 months" }
      ],
      "privacy": { "processor": "Google", "transfer": "EU-US Data Privacy Framework", "policy_url": "https://policies.google.com/privacy" }
    },
    {
      "key": "mixpanel",
      "name": "Mixpanel",
      "vendor": "Mixpanel, Inc.",
      "category": "analytics",
      "active": false,
      "description": "Product analytics for understanding feature usage. Data is not sold; used only for product/UX development.",
      "config": { "token": null, "api_host": "https://api-eu.mixpanel.com", "region": "eu", "ip": false },
      "cookies": [
        { "name": "mp_*", "purpose": "Mixpanel distinct id + state", "retention": "12 months" }
      ],
      "privacy": { "processor": "Mixpanel", "transfer": "EU-US Data Privacy Framework", "policy_url": "https://mixpanel.com/legal/privacy-policy/" }
    }
  ]
}
```

Notes:
- GA measurement id + Mixpanel token are **public client-side tokens** — safe in JSON / exposed to browser.
- A provider is wired into consent + loaded ONLY if `active == true` AND its required credential is present
  (GA: `measurement_id`; Mixpanel: `token`). So Mixpanel stays dormant until both flip. **Enabling Mixpanel = set `active:true` + add `token`. Nothing else.**
- EU residency baked into Mixpanel config (`api_host: api-eu.mixpanel.com`, `ip:false`).
- Optionally allow `"token": "ENV:MIXPANEL_TOKEN"` style indirection resolved server-side (figaro/ENV is in use). Nice-to-have, keep simple if it adds risk.

## 2. Rails side — helper + exposure

- Add `app/helpers/analytics_helper.rb` (or methods in application_helper):
  - `analytics_providers` — parse + memoize the JSON (cache in prod; re-read in dev). Rescue parse errors → `[]` + log.
  - `enabled_analytics_providers` — only `active && credential present`.
  - `analytics_consent_config_json` — the subset the browser needs to BUILD the consent UI + load scripts,
    serialized to JSON for a data attribute / meta tag. Include: key, name, category, description, config, cookies (name+purpose+retention for the settings descriptions).
- Expose to JS via the existing mount div: add `data-providers="<%= analytics_consent_config_json %>"`
  on `<div data-controller="cookie-consent" ...>`. (Single source — controller reads `this.element.dataset.providers`.)
- Disclosure page reads `enabled_analytics_providers` for the table.

## 3. Stimulus controller — build consent dynamically

Rewrite `cookie_consent_controller.js`:
- Parse `this.element.dataset.providers`.
- Always include Essential category (`disabled:true, checked:true`).
- Group active providers by `category` (e.g. analytics) → build CookiesConsent `cookies[]` dynamically.
  Each category node has child cookies, one per provider, with `checked:false`, `onLoad:false`, and a
  `manageFunction` resolved from a **JS provider registry** keyed by `provider.key`:
  - `google_analytics` -> lib's `manageGoogleAnalytics` (pass `code: measurement_id`).
  - `mixpanel` -> custom `manageMixpanel` (see below).
- Keep Turbo double-init guard + `toggleSettings()` + privacy policy link from `data-privacy-url`.
- DSGVO invariants preserved: opt-in (`checked:false`,`onLoad:false`), equal accept/reject buttons, granular, no pre-tick.

### Mixpanel manager — `app/javascript/lib/manage_mixpanel.js`
- Import `mixpanel-browser`. On `lifecycle === 'accept'` (status true): `mixpanel.init(token, { api_host, ip:false, opt_out_tracking_by_default:true, persistence:'localStorage' })` then `mixpanel.opt_in_tracking()`. On `reject`: `mixpanel.opt_out_tracking()` (+ clear). Guard: no-op if token missing.
- EU residency via `api_host` from config. No tracking before consent (opt_out default + onLoad:false).

## 4. Unified `track()` dispatcher — `app/javascript/lib/analytics.js`

- ESM module exporting `track(event, props)`; also assign `window.RevnousAnalytics = { track }` so inline
  `onclick` handlers can call it.
- `track` dispatches to every **active + consented** provider:
  - GA: `window.gtag && gtag('event', event, props)`.
  - Mixpanel: `mixpanel.has_opted_in_tracking?.() && mixpanel.track(event, props)`.
- Reads consent from the CookiesConsent instance / its stored state (or a small shared consent flag the
  consent controller sets per provider, e.g. `window.__analyticsConsent = { google_analytics:true, mixpanel:false }`).
  The consent controller updates this map in each provider's manageFunction (accept->true, reject->false).
- Pre-consent: `track()` no-ops for non-consented providers (events dropped — GDPR-safe). GA's own consent-mode
  buffering still applies to gtag.
- Import the module in `app/javascript/application.js` so `window.RevnousAnalytics` exists early.
- **Rewire the 15 inline `gtag('event', name, {...})` calls** in home/index, solutions/show, _navigation,
  _footer → `RevnousAnalytics.track('name', {...})`. Preserve event names + props verbatim. Keep the ERB
  interpolation (`product.name` etc.) intact.

## 5. Public disclosure — `/cookies`

- Route `get "cookies", to: "pages#cookies", as: :cookies` (sits near impressum route).
- `Pages#cookies` (or reuse a simple action) renders `app/views/pages/cookies.html.erb`:
  a table from `enabled_analytics_providers`: Tool | Purpose/Category | Cookies (name+retention) | Processor | Transfer basis | Provider policy link. Plus a short "we do not sell your data; used only for UX/product development" statement and a button/link to reopen cookie settings (`toggleSettings()`), and link to privacy policy + impressum.
- Link to `/cookies` from the footer (near the existing Cookie Settings link) and optionally from the consent banner `content.message`.
- Style with existing Tailwind conventions (match `legal_documents/show` / site styling).

# DSGVO compliance (must remain true)

- Opt-in only; no GA/Mixpanel script or cookie before explicit consent (`onLoad:false`, Mixpanel `opt_out...by_default:true`).
- Equal-weight Accept / Reject; granular per-category; no pre-ticked boxes.
- EU data residency for Mixpanel (`api-eu.mixpanel.com`, `ip:false`); GA `anonymize_ip:true`.
- Transparency: public disclosure table names each tool, processor, US-transfer basis (EU-US DPF), cookies, retention.
- Revocation via footer "Cookie Settings" (`toggleSettings()`).
- "We do not sell data" statement surfaced on the disclosure page (user-confirmed; privacy policy already states it).
- NOTE for user (not code): privacy policy must still name Mixpanel + sign DPA before flipping it live.

# Pitfalls

- **JSON parse failure must fail safe** — bad JSON → no providers, banner still renders Essential, no crash. Rescue + log.
- **Don't expose secrets that aren't public** — only client-public tokens (GA id, Mixpanel browser token) belong in the exposed payload. No server secrets in `data-providers`.
- **CSS already handled** in 260612-vyn (relative node_modules @import). Adding mixpanel-browser is JS-only.
- **esbuild must bundle mixpanel-browser** even while dormant (it's imported by manage_mixpanel). That's fine — it just won't init without a token. Verify `yarn build` succeeds with the new dep.
- **Turbo**: keep the double-init guard; ensure `window.RevnousAnalytics` + consent map survive Turbo navigations.
- **Event-name parity**: the rewire must not change GA event names/props or analytics history breaks.
- **Built assets gitignored** — verify by rebuilding locally; deploy reinstalls + rebuilds.
- Run `yarn install` in the MAIN tree after `yarn add mixpanel-browser` (lesson from 260612-vyn: worktree install didn't populate main node_modules).
