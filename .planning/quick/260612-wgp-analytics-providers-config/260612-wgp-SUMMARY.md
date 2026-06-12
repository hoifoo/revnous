---
title: Summary — Config-driven analytics providers (GA live, Mixpanel dormant) + unified track() + public disclosure
quick_id: 260612-wgp
date: 2026-06-12
status: incomplete
reason: Task 6 is a human-verify browser checkpoint — pending user confirmation
---

# Summary: Config-driven analytics providers

Made the cookie-consent system fully config-driven via a static JSON registry. Enabling a provider
(e.g. Mixpanel) now requires editing `config/analytics_providers.json` only — no UI/JS code change.
GA is live; Mixpanel ships dormant (`active:false`, `token:null`) with EU residency pre-configured.

Builds on quick task 260612-vyn. Branch: `implement-cookie-consent`.

## Commits

| Commit | Task | Change |
|--------|------|--------|
| `b33dd48` | 1 | Config JSON registry + `AnalyticsHelper` + expose via `data-providers` on mount div |
| `89f2fbf` | 2 | JS provider registry + Mixpanel manager + JSON-driven Stimulus controller + `mixpanel-browser@2.80.0` dep |
| `5b93797` | 3 | Unified `track()` dispatcher + rewire all 15 inline `gtag('event',...)` calls |
| `bdc3a94` | 4 | Public `/cookies` disclosure page + route + footer link |

Worktree fast-forward-merged; worktree removed.

## What changed

- **`config/analytics_providers.json`** — single source of truth. GA (`active:true`, `G-6ZPXSBZYL8`, `anonymize_ip`), Mixpanel (`active:false`, `token:null`, `api_host:api-eu.mixpanel.com`, `ip:false`). Each provider: name, vendor, category, description, cookies (name/purpose/retention), privacy (processor/transfer/policy_url).
- **`app/helpers/analytics_helper.rb`** — parses + memoizes JSON; `enabled_analytics_providers` gates on `active && credential present`; `analytics_consent_config_json` emits only the browser-safe subset. Fail-safe `[]` + log on bad JSON.
- **`app/javascript/lib/analytics_providers.js`** — JS registry mapping provider key → manageFunction (`google_analytics` → lib `manageGoogleAnalytics`; `mixpanel` → `manageMixpanel`).
- **`app/javascript/lib/manage_mixpanel.js`** — `mixpanel-browser` init with `api_host` (EU), `ip:false`, `opt_out_tracking_by_default:true`; opt-in on accept, opt-out/clear on reject; no-op if token missing.
- **`app/javascript/controllers/cookie_consent_controller.js`** — now reads `data-providers`, builds CookiesConsent `cookies[]` dynamically (Essential always-on + active providers grouped by category). DSGVO invariants preserved.
- **`app/javascript/lib/analytics.js`** — `track(event, props)` dispatching to active+consented providers; `window.RevnousAnalytics`; consent map `window.__analyticsConsent` updated per provider on accept/reject.
- **`app/javascript/application.js`** — imports analytics module so `RevnousAnalytics` exists early.
- **15 inline `gtag('event',...)` calls** in home/index, solutions/show, _navigation, _footer → `RevnousAnalytics.track(...)`, event names + props + ERB interpolation verbatim. Zero inline `gtag('event'` remain.
- **`/cookies`** route → `pages#cookies` → `app/views/pages/cookies.html.erb`: disclosure table from `enabled_analytics_providers` (tool, purpose, cookies, processor, transfer basis, policy link), no-sell statement, "Manage Cookie Settings" reopen, privacy/impressum links. Footer "Cookies" link added.

## Post-merge action by orchestrator

`yarn add mixpanel-browser` ran in the worktree only. Ran `yarn install` in main tree → `mixpanel-browser@2.80.0` present, `yarn build` + `yarn build:css` succeed. (Built assets gitignored; deploy reinstalls.)

## Automated verification — PASS

- JSON parses; GA active, Mixpanel dormant w/ EU residency.
- `analytics_consent_config_json` (via rails runner) returns **GA only** — Mixpanel never reaches the browser payload while dormant.
- `pages/cookies.html.erb` renders; GA row present, Mixpanel absent.
- Zero `gtag('event'` in `app/views/`; all rewired to `RevnousAnalytics.track()`.
- `cookies_path` → `/cookies`.
- `yarn build` OK; bundle contains `mixpanel` (bundled, dormant), `RevnousAnalytics`, `__analyticsConsent`. `yarn build:css` OK.

## Manual browser checkpoint — STILL PENDING (Task 6, blocking)

Run `bin/dev`, incognito:
1. Banner built from JSON — Essential + Analytics>Google Analytics only (Mixpanel absent); equal Accept/Reject, no pre-tick.
2. GA gating — no `_ga` before consent; loads + sets cookie after Accept; persists on reload.
3. `track()` — after Accept, clicking CTAs fires GA events with original names/props; nothing before Accept.
4. `/cookies` page — table lists GA (Mixpanel absent), no-sell statement, "Manage Cookie Settings" reopens modal, footer "Cookies" link works.
5. Mixpanel dormant — `window.mixpanel` undefined, no `api-eu.mixpanel.com` requests. (Do NOT flip active during check.)
6. (Optional) Fail-safe — corrupt JSON → banner still shows Essential only, no crash, logged; restore after.

Mark complete only after user confirms.

## NOT code — before flipping Mixpanel live
- Register Mixpanel project, get token, set `active:true` + token in JSON.
- Update privacy policy to name Mixpanel + US transfer (EU-US DPF); sign DPA.
