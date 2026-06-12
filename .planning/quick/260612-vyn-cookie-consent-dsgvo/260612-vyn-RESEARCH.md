---
title: Research — Replace custom cookie banner with @metamorfosilab/cookies-consent (DSGVO)
quick_id: 260612-vyn
date: 2026-06-12
---

# Research: @metamorfosilab/cookies-consent for German DSGVO compliance

This was researched directly from the npm tarball (`@metamorfosilab/cookies-consent@0.2.9`)
type defs and minified source. Facts below are verified, not guessed — implement against them.

## Current state (what is being replaced)

- `app/views/layouts/application.html.erb:81-96` — hardcoded GA loader: a `gtag()` stub,
  `gtag('consent','default',{analytics_storage:'denied', ad_storage:'denied', wait_for_update:500})`,
  `gtag('config','G-6ZPXSBZYL8')`, then `<script async src="googletagmanager.com/gtag/js?id=G-6ZPXSBZYL8">`.
  This loads GA unconditionally on every page (only storage is consent-gated). **Remove this block** — the lib will inject/manage GA.
- `app/views/shared/_cookie_consent.html.erb` — custom vanilla banner (binary Accept All / Decline Optional),
  stores choice in `localStorage` key `revnous_cookie_consent`, flips gtag consent. **Delete this file** and its `render` in the layout (`application.html.erb:79`).
- `app/views/shared/_footer.html.erb` — may contain a `#cookie-settings-link` / "Cookie Settings" link → must call the new lib's `toggleSettings()` to reopen preferences. Verify and rewire.
- Existing inline `onclick="gtag('event', ...)"` handlers exist across views (home/index, solutions/show, _navigation, _footer). After this change GA only loads AFTER consent, so `gtag` is undefined before consent → those onclick calls would throw. **Add a safe no-op gtag/dataLayer stub** early in `<head>` so queued events don't error (they harmlessly buffer into dataLayer; GA replays them only if it later loads).

## Library facts (v0.2.9)

- Install: `@metamorfosilab/cookies-consent` (npm). ESM entry `dist/index.js`. Vanilla JS — fits esbuild/Stimulus, no framework. Fetched via yarn (project uses yarn 1.22).
- **CSS required**: `dist/index.css` ships with the package. Must be imported/included for the banner + settings modal to render. Options: import in JS bundle (esbuild can import css? — no, esbuild here bundles JS only) OR copy/reference the css. Simplest reliable path: import the CSS into the Tailwind/`application.tailwind.css` via `@import "@metamorfosilab/cookies-consent/dist/index.css";` OR add a `<link>`/`@import`. **Decide a path that works with this project's cssbundling (Tailwind CLI) + esbuild split** — verify the import actually lands in the built `application.css`. Fallback: vendor the css file into `app/assets/stylesheets` and `@import` it.

### Exported API
```ts
import { CookiesConsent, manageGoogleAnalytics, manageGoogleTagManager,
         darkTheme, smoothTheme, contrastTheme } from '@metamorfosilab/cookies-consent'

new CookiesConsent({
  expirationDays: number,            // consent cookie lifetime
  path?, sameSite?: 'strict'|'lax'|'none',
  position?: 'bottom'|'bottom-left'|... ,
  buttons?: ('dismiss'|'accept'|'reject'|'info'|'settings')[],
  ignorePages?: string[],
  hideDescription?, mainWindowSettings?, animation?,
  content: { title?, message?, info?, policy?, policyLink?, btnDismiss?, btnAccept?,
             btnReject?, btnInfo?, btnSettings?, align?, settingsHeader?, settingsFooter?,
             btnSettingsSelectAll?, btnSettingsUnselectAll?, btnSettingsAccept? },
  cookies?: Cookie[],
  callback?: { first_load?, accept?, reject?, load? },  // each (params: CookiesStatus) => void
  theme?: Theme,
})
```

Public methods: `getStatus()`, `getConfig()`, `showMessage()`, `removeCookies()`, **`toggleSettings()`** (use for the footer "Cookie Settings" reopen link).

### Cookie object
```ts
{
  name: string, title?, description?,
  checked?: boolean,   // initial checkbox state — MUST be false/unchecked for opt-in categories (DSGVO: no pre-ticked boxes)
  disabled?: boolean,  // true for essential category (always on, not toggleable)
  onLoad?: boolean,    // GA only: collect data BEFORE consent. MUST be false for DSGVO (no tracking pre-consent)
  code?: string,       // GA only: measurement id, e.g. 'G-6ZPXSBZYL8'
  manageFunction?: (arg: { lifecycle: 'first-load'|'load'|'accept'|'reject', cookie, status?: boolean, path? }) => void,
  cookies?: Cookie[],  // child cookies; parent accept/reject cascades
}
```

### Built-in `manageGoogleAnalytics({lifecycle, cookie, status, path})`
Verified from source — it does the FULL GA lifecycle so we do NOT hand-roll gtag:
- Injects `<script src="googletagmanager.com/gtag/js?id=${cookie.code}">` and defines `gtag`, `dataLayer`.
- Sets `gtag('consent','default',{analytics_storage:'denied'})`.
- On accept (status true): `gtag('consent','update',{analytics_storage:'granted'})`, `gtag('config', code, {anonymize_ip:true})`, sets `allow_google_signals` / `allow_ad_personalization_signals`.
- On reject: consent update denied.
Pass GA as a child cookie with `code:'G-6ZPXSBZYL8'`, `manageFunction: manageGoogleAnalytics`, `onLoad:false`.

## DSGVO / TTDSG compliance requirements (must hold)

1. **Opt-in, not opt-out** — analytics off by default; `onLoad:false`, `checked:false`. No GA cookie/script before explicit consent.
2. **Equal weight Accept vs Reject** — `buttons` must include both `accept` and `reject` at the banner level (reject as easy/prominent as accept). Do NOT ship accept-only or a dismiss-only banner.
3. **Granular categories** — at least Essential (disabled, always-on) + Analytics (toggle). Settings modal via `settings` button.
4. **Withdrawal** — footer "Cookie Settings" link reopens via `toggleSettings()`; rejecting/clearing must drop GA (`removeCookies()` available).
5. **Privacy policy link** — use `content.policy` + `content.policyLink` → `privacy_policy_path`.
6. **No pre-ticked boxes** — every non-essential `checked:false`.

## Integration approach (recommended)

- Add dep via `yarn add @metamorfosilab/cookies-consent`.
- New Stimulus controller `app/javascript/controllers/cookie_consent_controller.js` (registered in `index.js`) that constructs `CookiesConsent` on connect. Attach to a `<div data-controller="cookie-consent">` rendered in the layout where the old partial was.
  - Alternatively a plain ESM module imported in `application.js`. Stimulus controller is more idiomatic for this repo (see existing controllers). Either is fine — pick one, keep it consistent.
- Ensure controller runs once (guard against Turbo re-init / double banner on `turbo:load`).
- Wire footer "Cookie Settings" link to call the controller's `toggleSettings()` (e.g. a controller action + `data-action`, or expose instance).
- Include `dist/index.css` in the built CSS. **Verify in the actual build output** that banner styles load (don't assume).
- Remove GA loader block + old partial + old render. Add safe gtag/dataLayer stub in `<head>` so existing `onclick="gtag('event',...)"` calls don't throw pre-consent.

## Pitfalls

- **CSS not loading** is the most likely failure — banner appears unstyled/broken. Verify the css import path resolves through Tailwind CLI / Propshaft. Test the built asset.
- **gtag undefined errors** from existing inline onclick handlers — the stub is mandatory, not optional.
- **Turbo double-init** — constructing CookiesConsent twice creates duplicate DOM. Guard it.
- **CSP** — layout uses `csp_meta_tag`. Injecting external GA script + inline init may hit CSP if a strict policy exists. Check `config/initializers/content_security_policy.rb` (if present) — currently GA is already allowed, keep it allowed.
- Don't break the existing GA measurement id `G-6ZPXSBZYL8` — same id, just consent-gated correctly now.
