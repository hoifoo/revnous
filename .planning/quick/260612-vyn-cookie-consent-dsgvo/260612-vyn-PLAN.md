---
phase: quick-260612-vyn
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - package.json
  - package-lock.json
  - app/javascript/controllers/cookie_consent_controller.js
  - app/javascript/controllers/index.js
  - app/assets/stylesheets/application.tailwind.css
  - app/views/layouts/application.html.erb
  - app/views/shared/_footer.html.erb
  - app/views/shared/_cookie_consent.html.erb
autonomous: false
requirements:
  - DSGVO-CONSENT
must_haves:
  truths:
    - "On first visit (no consent cookie), a banner appears with equal-weight Accept and Reject buttons and a Settings option; no GA script or cookie is present in the DOM/network until the user explicitly accepts"
    - "Analytics category is unchecked by default and Essential is shown as always-on (disabled); rejecting or never-consenting means GA never loads"
    - "Accepting analytics injects googletagmanager.com/gtag/js?id=G-6ZPXSBZYL8 and grants analytics_storage; the same measurement id is used"
    - "The footer 'Cookie Settings' link reopens the consent settings modal"
    - "Existing inline onclick=\"gtag('event', ...)\" handlers do not throw before consent because a no-op gtag/dataLayer stub is defined in <head>"
    - "The cookies-consent library CSS is present in the built app/assets/builds/application.css so the banner and modal render styled"
  artifacts:
    - path: "app/javascript/controllers/cookie_consent_controller.js"
      provides: "Stimulus controller that constructs CookiesConsent with DSGVO config and exposes toggleSettings"
      min_lines: 40
    - path: "app/assets/stylesheets/application.tailwind.css"
      provides: "@import of @metamorfosilab/cookies-consent/dist/index.css"
      contains: "cookies-consent/dist/index.css"
    - path: "app/views/layouts/application.html.erb"
      provides: "gtag/dataLayer no-op stub in head, cookie-consent mount div, removal of hardcoded GA loader + old partial render"
  key_links:
    - from: "app/views/shared/_footer.html.erb"
      to: "cookie_consent_controller.toggleSettings"
      via: "data-action click on #cookie-settings-link"
      pattern: "cookie-consent#toggleSettings"
    - from: "app/javascript/controllers/cookie_consent_controller.js"
      to: "manageGoogleAnalytics with code G-6ZPXSBZYL8"
      via: "child cookie manageFunction"
      pattern: "G-6ZPXSBZYL8"
---

<objective>
Replace the custom hand-rolled cookie banner with the `@metamorfosilab/cookies-consent` library, configured for German DSGVO/TTDSG compliance: opt-in by default, granular categories (Essential always-on + Analytics toggle, no pre-ticked boxes), equal-weight Accept and Reject buttons, reopenable settings modal from the footer, and Google Analytics (`G-6ZPXSBZYL8`) gated behind explicit consent via the library's built-in `manageGoogleAnalytics` helper. No tracking script or cookie loads before consent.

Purpose: The current implementation loads GA unconditionally on every page (only storage flags are consent-gated), which is non-compliant under DSGVO/TTDSG. This makes consent genuinely gating and removes hand-rolled gtag logic.

Output: A working DSGVO-compliant consent banner backed by a maintained library, with the old custom banner and unconditional GA loader removed.

This plan builds directly on the verified library API, integration approach, and pitfalls in @.planning/quick/260612-vyn-cookie-consent-dsgvo/260612-vyn-RESEARCH.md — do not re-research the library.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/quick/260612-vyn-cookie-consent-dsgvo/260612-vyn-RESEARCH.md
@./CLAUDE.md

<interfaces>
<!-- Verified library API (v0.2.9) — from RESEARCH.md. Use directly, do not explore the package. -->

Imports (ESM, from "@metamorfosilab/cookies-consent"):
  - CookiesConsent (class)
  - manageGoogleAnalytics (function: ({lifecycle, cookie, status, path}) => void — does the FULL GA lifecycle, injects script, sets consent default/update, config with anonymize_ip)

new CookiesConsent({
  expirationDays: number,
  sameSite?: 'strict'|'lax'|'none',
  position?: 'bottom'|'bottom-left'|...,
  buttons?: ('dismiss'|'accept'|'reject'|'info'|'settings')[],   // include 'accept','reject','settings' — equal weight
  content: { title?, message?, info?, policy?, policyLink?, btnAccept?, btnReject?, btnSettings?,
             settingsHeader?, settingsFooter?, btnSettingsSelectAll?, btnSettingsUnselectAll?, btnSettingsAccept? },
  cookies?: Cookie[],
  callback?: { first_load?, accept?, reject?, load? },
})

Cookie object:
  { name, title?, description?,
    checked?: boolean,    // MUST be false for opt-in analytics (no pre-ticked boxes)
    disabled?: boolean,   // true for essential (always-on, not toggleable)
    onLoad?: boolean,     // GA only: MUST be false (no tracking pre-consent)
    code?: string,        // GA measurement id, e.g. 'G-6ZPXSBZYL8'
    manageFunction?,      // pass manageGoogleAnalytics for the GA child cookie
    cookies?: Cookie[] }  // child cookies; parent accept/reject cascades

Public instance methods: getStatus(), getConfig(), showMessage(), removeCookies(), toggleSettings()  // toggleSettings reopens the settings modal
</interfaces>

Build pipeline facts (verified this plan):
- CSS: `build:css` runs `@tailwindcss/cli` v4 on `app/assets/stylesheets/application.tailwind.css` (which starts `@import "tailwindcss";`) → `app/assets/builds/application.css --minify`. Tailwind v4 CLI resolves bare-package `@import` from node_modules, so `@import "@metamorfosilab/cookies-consent/dist/index.css";` lands in the built CSS.
- JS: `build` runs esbuild bundling `app/javascript/*.*` → `app/assets/builds/`. esbuild bundles the library JS via the Stimulus controller import.
- CSP: `config/initializers/content_security_policy.rb` is entirely commented out — NO active CSP. `csp_meta_tag` emits nothing enforceable. No CSP changes required.
- Turbo teardown: `application.js` already calls `c.teardown()` on `turbo:before-cache` for every controller — implement `teardown()` in the new controller to avoid duplicate banners across Turbo navigations.
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add the library, build the DSGVO-configured Stimulus controller, and wire CSS</name>
  <files>package.json, package-lock.json, app/javascript/controllers/cookie_consent_controller.js, app/javascript/controllers/index.js, app/assets/stylesheets/application.tailwind.css</files>
  <action>
Add the dependency with `yarn add @metamorfosilab/cookies-consent` (project uses yarn 1.22; this updates package.json and the lockfile).

Create `app/javascript/controllers/cookie_consent_controller.js` as a Stimulus controller importing `CookiesConsent` and `manageGoogleAnalytics` from the package. On `connect()`:
- Guard against double-init across Turbo navigations: if `window.__cookieConsentInstance` already exists, store the reference and return; otherwise construct a new `CookiesConsent` and store it on both `this.consent` and `window.__cookieConsentInstance` (the footer link and Turbo re-renders must reach the same instance).
- Construct `new CookiesConsent({ ... })` configured for DSGVO compliance:
  - `expirationDays: 365`, `sameSite: 'lax'`, `position: 'bottom'`.
  - `buttons: ['accept', 'reject', 'settings']` — equal-weight Accept and Reject plus a Settings entry. Do NOT include a standalone `dismiss`/accept-only flow.
  - `content`: set `title`, `message`, `btnAccept` ("Accept"), `btnReject` ("Reject"), `btnSettings` ("Settings"), `policy`/`policyLink` pointing to the privacy policy. The privacy policy URL must be passed in from the layout (read it from a data attribute on the controller element — `this.element.dataset.privacyUrl`) so the Rails route owns the path; do not hardcode a URL string in JS.
  - `cookies`: an Essential category cookie `{ name: 'essential', disabled: true, checked: true }` (always on, not toggleable) and an Analytics category cookie `{ name: 'analytics', checked: false, cookies: [ { name: 'google-analytics', onLoad: false, code: 'G-6ZPXSBZYL8', manageFunction: manageGoogleAnalytics } ] }`. `checked: false` and `onLoad: false` are MANDATORY — no pre-ticked boxes, no tracking before consent. Keep `code: 'G-6ZPXSBZYL8'` unchanged.
- Add a `toggleSettings()` controller method that calls the stored instance's `toggleSettings()` (so the footer link can invoke it via `data-action`).
- Add a `teardown()` method (called by the existing `turbo:before-cache` hook in application.js) that nulls `this.consent`; do NOT destroy `window.__cookieConsentInstance` (the banner persists across Turbo visits; the global guard prevents duplicates).
Do NOT hand-roll any gtag/consent logic in this controller — `manageGoogleAnalytics` owns the entire GA lifecycle.

Register the controller in `app/javascript/controllers/index.js` following the existing pattern (`import` then `application.register("cookie-consent", CookieConsentController)`).

Add `@import "@metamorfosilab/cookies-consent/dist/index.css";` to `app/assets/stylesheets/application.tailwind.css`, placed immediately after the existing `@import "tailwindcss";` / `@plugin` lines so the library styles compile into the built CSS.
  </action>
  <verify>
    <automated>cd /Users/irfan/projects/revnous/web && yarn build && yarn build:css && grep -q "G-6ZPXSBZYL8" app/assets/builds/application.js && grep -q "cookie-consent" app/javascript/controllers/index.js && grep -rqi "cookie" app/assets/builds/application.css && echo "BUILD+CSS+JS OK"</automated>
  </verify>
  <done>Library installed; controller constructs CookiesConsent with accept+reject+settings buttons, Essential(disabled)+Analytics(checked:false) categories, GA child cookie code G-6ZPXSBZYL8 onLoad:false via manageGoogleAnalytics, Turbo-safe single-init guard, and toggleSettings; controller registered; CSS @import added and the library styles are present in the built application.css (the css grep confirms the library CSS compiled in, not just Tailwind).</done>
</task>

<task type="auto">
  <name>Task 2: Swap the layout and footer over to the library, delete the old banner</name>
  <files>app/views/layouts/application.html.erb, app/views/shared/_footer.html.erb, app/views/shared/_cookie_consent.html.erb</files>
  <action>
In `app/views/layouts/application.html.erb`:
- Add a minimal, safe no-op gtag/dataLayer stub as an inline `<script>` in `<head>` (place it before the `stylesheet_link_tag`/`javascript_include_tag` lines, around line 55): `window.dataLayer = window.dataLayer || []; window.gtag = window.gtag || function(){ dataLayer.push(arguments); };`. This ensures existing inline `onclick="gtag('event', ...)"` handlers (e.g. the footer "Book a Demo" link) buffer harmlessly into dataLayer and never throw before GA loads. Do NOT call `gtag('config', ...)` or load any GA script here — the library owns GA loading.
- Remove the hardcoded Google Analytics block at the end of `<body>` (the inline `<script>` with `gtag('consent','default',...)`, `gtag('config','G-6ZPXSBZYL8')` and the `<script async src="...googletagmanager.com/gtag/js?id=G-6ZPXSBZYL8">` tag, current lines ~81-96). The library injects GA only after consent.
- Replace `<%= render "shared/cookie_consent" %>` (line ~79) with a mount element for the Stimulus controller, passing the privacy policy URL as a data attribute: `<div data-controller="cookie-consent" data-privacy-url="<%= privacy_policy_path %>"></div>`.

In `app/views/shared/_footer.html.erb`:
- Rewire the existing `<a href="#" id="cookie-settings-link">Cookie Settings</a>` to reopen the library settings modal. Since the controller is mounted on a layout-level div (not an ancestor of the footer link), invoke it via the shared instance: change the link to `<a href="#" id="cookie-settings-link" onclick="event.preventDefault(); window.__cookieConsentInstance && window.__cookieConsentInstance.toggleSettings();" class="...">Cookie Settings</a>` (keep existing classes). Keep `id="cookie-settings-link"`.
- Leave the existing `onclick="gtag('event', 'book_demo_click', ...)"` on the Book a Demo link as-is — the head stub now protects it.

Delete `app/views/shared/_cookie_consent.html.erb` entirely (the old custom banner, its inline JS, and styles are fully replaced).
  </action>
  <verify>
    <automated>cd /Users/irfan/projects/revnous/web && test ! -f app/views/shared/_cookie_consent.html.erb && ! grep -q 'googletagmanager.com/gtag/js' app/views/layouts/application.html.erb && grep -q 'data-controller="cookie-consent"' app/views/layouts/application.html.erb && grep -q 'window.gtag = window.gtag' app/views/layouts/application.html.erb && grep -q 'toggleSettings' app/views/shared/_footer.html.erb && echo "LAYOUT+FOOTER OK"</automated>
  </verify>
  <done>Old `_cookie_consent.html.erb` partial deleted and its render removed; hardcoded GA loader/script removed from the layout; no-op gtag stub present in head; cookie-consent mount div with data-privacy-url rendered; footer "Cookie Settings" link calls toggleSettings on the shared instance.</done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <what-built>
The custom cookie banner has been replaced with the `@metamorfosilab/cookies-consent` library, configured for DSGVO/TTDSG: opt-in analytics (off by default), equal-weight Accept/Reject, granular Essential(always-on)+Analytics categories, a reopenable settings modal from the footer, and GA `G-6ZPXSBZYL8` gated behind explicit consent. JS and CSS are rebuilt. Because compliance and correct styling can only be confirmed visually and in the network tab, this needs a human check.
  </what-built>
  <how-to-verify>
1. Run the dev server (`bin/dev` or your usual command) so esbuild + Tailwind builds are served. Open the site in a fresh/incognito window (no prior consent cookie). Open DevTools → Network and Application/Storage tabs.
2. BANNER + STYLING: The consent banner appears at the bottom, fully styled (not raw/unstyled HTML). It shows an "Accept" and a "Reject" button of clearly equal prominence, plus a "Settings" option. If the banner is unstyled, the library CSS did not compile — re-check the `@import` in application.tailwind.css and that `build:css` ran (this is the #1 expected pitfall).
3. NO TRACKING PRE-CONSENT: In the Network tab, confirm there is NO request to `googletagmanager.com/gtag/js` and NO `_ga` cookie present in Application → Cookies before you click anything.
4. SETTINGS / GRANULAR + NO PRE-TICK: Open Settings. Confirm Essential is shown always-on/disabled and Analytics is present and UNCHECKED by default.
5. REJECT PATH: Reject. Confirm still no `gtag/js` request and no `_ga` cookie.
6. ACCEPT PATH: Reload, then Accept analytics. Confirm a `googletagmanager.com/gtag/js?id=G-6ZPXSBZYL8` request now fires and a `_ga` cookie appears.
7. WITHDRAWAL: Click the footer "Cookie Settings" link — the settings modal reopens.
8. NO JS ERRORS: With the Console open, click the footer "Book a Demo" link (which uses inline `gtag('event', ...)`). Confirm no "gtag is not defined" error is thrown at any point before consent.
  </how-to-verify>
  <resume-signal>Type "approved" if all eight checks pass, or describe which check failed (especially banner styling or a pre-consent gtag/js request).</resume-signal>
</task>

</tasks>

<verification>
- `yarn build` and `yarn build:css` both succeed; `G-6ZPXSBZYL8` appears in built JS and the library CSS appears in built `application.css`.
- No `googletagmanager.com/gtag/js` reference remains in the layout source (only the library injects it post-consent).
- `_cookie_consent.html.erb` no longer exists and is not rendered anywhere (`grep -r "shared/cookie_consent" app/views` returns nothing).
- Human checkpoint confirms: styled banner, equal-weight Accept/Reject, no GA before consent, GA loads only on accept, footer reopen works, no gtag console errors.
</verification>

<success_criteria>
- DSGVO/TTDSG holds: opt-in (analytics `checked:false` + `onLoad:false`), equal-weight accept/reject, granular Essential+Analytics, no pre-ticked boxes, reopenable settings, privacy policy link, zero GA script/cookie before explicit consent.
- GA measurement id remains `G-6ZPXSBZYL8`, now correctly consent-gated via `manageGoogleAnalytics`.
- Old custom banner and unconditional GA loader fully removed; existing inline `gtag('event', ...)` handlers protected by the head stub.
- Library CSS verified present in the built stylesheet (not assumed).
</success_criteria>

<output>
Create `.planning/quick/260612-vyn-cookie-consent-dsgvo/260612-vyn-SUMMARY.md` when done.
</output>
