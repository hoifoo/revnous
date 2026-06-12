import mixpanel from "mixpanel-browser"

// manageFunction for the Mixpanel cookie-consent entry.
// Signature matches how @metamorfosilab/cookies-consent invokes managers:
// manageFunction({ lifecycle, cookie, status, path })
//
// DSGVO invariants:
// - No tracking before consent: opt_out_tracking_by_default true on init.
// - EU data residency: api_host pinned via config.api_host (api-eu.mixpanel.com), ip:false.
// - Guard: no-op entirely if the token is missing (Mixpanel stays dormant).
export function manageMixpanel({ lifecycle, cookie, status }) {
  const config = (cookie && cookie.config) || {}
  const token = config.token

  window.__analyticsConsent = window.__analyticsConsent || {}

  if (!token) {
    window.__analyticsConsent.mixpanel = false
    return
  }

  switch (lifecycle) {
    case "first-load":
      window.__analyticsConsent.mixpanel = false
      break
    case "load":
    case "accept":
      if (status) {
        mixpanel.init(token, {
          api_host: config.api_host,
          ip: false,
          opt_out_tracking_by_default: true,
          persistence: "localStorage",
        })
        mixpanel.opt_in_tracking()
        window.__analyticsConsent.mixpanel = true
      } else {
        if (window.mixpanel && typeof window.mixpanel.opt_out_tracking === "function") {
          mixpanel.opt_out_tracking()
        }
        window.__analyticsConsent.mixpanel = false
      }
      break
    case "reject":
      if (window.mixpanel && typeof window.mixpanel.opt_out_tracking === "function") {
        mixpanel.opt_out_tracking()
      }
      window.__analyticsConsent.mixpanel = false
      break
  }
}
