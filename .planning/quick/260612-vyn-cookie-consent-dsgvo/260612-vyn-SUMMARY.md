---
title: Summary — Replace custom cookie banner with @metamorfosilab/cookies-consent (DSGVO)
quick_id: 260612-vyn
date: 2026-06-12
status: incomplete
reason: Task 3 is a human-verify browser checkpoint — still pending user confirmation
---

# Summary: DSGVO Cookie Consent

Replaced the custom binary cookie banner with `@metamorfosilab/cookies-consent@0.2.9`,
configured for German DSGVO/TTDSG compliance, gating Google Analytics (`G-6ZPXSBZYL8`)
via the library's built-in `manageGoogleAnalytics` helper.

## Commits (on branch `implement-cookie-consent`)

| Commit | Task | Change |
|--------|------|--------|
| `38ed04c` | 1 | Add library + DSGVO-configured Stimulus controller, register it, wire CSS import |
| `794d377` | 2a | Delete old `_cookie_consent.html.erb` partial |
| `91a1c2b` | 2b | Swap layout (GA loader → gtag stub + controller mount), wire footer reopen link |

Worktree branch fast-forward-merged into `implement-cookie-consent`; worktree removed.

## What changed

- **`app/javascript/controllers/cookie_consent_controller.js`** (new) — constructs `CookiesConsent` on connect with:
  - `buttons: ["accept", "reject", "settings"]` (equal-weight accept/reject)
  - Essential category `disabled:true, checked:true` (always-on)
  - Analytics category `checked:false` with child GA cookie `onLoad:false, code:"G-6ZPXSBZYL8", manageFunction: manageGoogleAnalytics`
  - `policyLink` from `data-privacy-url` (Rails `privacy_policy_path`)
  - `window.__cookieConsentInstance` guard against Turbo double-init; `toggleSettings()` exposed
- **`app/javascript/controllers/index.js`** — registers the controller
- **`app/assets/stylesheets/application.tailwind.css`** — `@import` of the library CSS (relative node_modules path — the documented fallback; the package `exports` map does not expose `./dist/index.css` as a bare specifier)
- **`app/views/layouts/application.html.erb`** — removed the hardcoded GA loader; added a no-op `gtag`/`dataLayer` stub in `<head>`; mounts `<div data-controller="cookie-consent" data-privacy-url=...>`
- **`app/views/shared/_footer.html.erb`** — "Cookie Settings" link calls `window.__cookieConsentInstance.toggleSettings()`
- **`app/views/shared/_cookie_consent.html.erb`** — deleted
- **`package.json` / `yarn.lock`** — dependency added

## Deviations (auto-fixed)

1. **CSS bare-import failed** — `@import "@metamorfosilab/cookies-consent/dist/index.css"` does not resolve (package `exports` omits the css). Switched to the relative `../../../node_modules/...` path documented in RESEARCH.md. Library CSS now compiles into `application.css`.
2. **yarn.lock not package-lock.json** — project uses yarn 1.22; committed `yarn.lock`.

## Post-merge fix by orchestrator

`yarn add` had run inside the executor's worktree, so the library was missing from the
main tree's `node_modules`; `yarn build:css` failed there with an unresolved import.
Ran `yarn install` in the main tree → package present, `yarn build:css` + `yarn build`
both succeed, and the built `application.css` now contains `cc-window`/`cc-btn-accept`/
`cc-btn-reject`/`cc-modal`. (Built assets under `app/assets/builds/` are gitignored and
rebuilt at deploy; the committed `package.json`+`yarn.lock` mean CI/Docker `yarn install`
will resolve the dependency.)

## Automated verification — PASS

- `yarn install`, `yarn build:css`, `yarn build` all succeed in the main tree
- Built `application.css` contains library selectors (cc-window, cc-btn-accept, cc-btn-reject, cc-modal)
- Built `application.js` contains `G-6ZPXSBZYL8`
- `cookie-consent` controller registered; old partial deleted; no `googletagmanager.com/gtag/js` left in layout source; gtag stub present; mount div + footer reopen link present
- ERB syntax OK

## Manual browser checkpoint — STILL PENDING (Task 3, blocking)

Run `bin/dev`, then in a fresh/incognito window:

1. **Banner + styling** — styled bottom banner, equal-weight Accept / Reject + Settings.
2. **No tracking pre-consent** — Network tab: no `googletagmanager.com/gtag/js`, no `_ga` cookie before any click.
3. **Granular + no pre-tick** — Settings: Essential always-on/disabled; Analytics present and UNCHECKED.
4. **Reject path** — click Reject: still no `gtag/js`, no `_ga`.
5. **Accept path** — reload, click Accept: `gtag/js?id=G-6ZPXSBZYL8` fires, `_ga` cookie appears.
6. **Withdrawal** — footer "Cookie Settings" reopens settings modal.
7. **No JS errors** — Console open, click footer "Book a Demo": no "gtag is not defined".

Mark complete only after the user confirms these pass.
