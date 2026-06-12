// Unified analytics dispatcher. Exposes window.RevnousAnalytics.track(event, props)
// so inline onclick handlers and Stimulus controllers can fire events without
// knowing which providers are active or consented.
//
// DSGVO: dispatches only to providers the visitor has consented to
// (window.__analyticsConsent, maintained by the cookie-consent controller's
// manageFunctions). Pre-consent, events are dropped (no buffering, no-op).
export function track(event, props) {
  const consent = window.__analyticsConsent || {}

  if (consent.google_analytics && typeof window.gtag === "function") {
    window.gtag("event", event, props)
  }

  if (
    consent.mixpanel &&
    window.mixpanel &&
    typeof window.mixpanel.has_opted_in_tracking === "function" &&
    window.mixpanel.has_opted_in_tracking()
  ) {
    window.mixpanel.track(event, props)
  }
}

window.RevnousAnalytics = window.RevnousAnalytics || { track }
