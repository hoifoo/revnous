import { manageGoogleAnalytics } from "@metamorfosilab/cookies-consent"
import { manageMixpanel } from "./manage_mixpanel"

// Registry of provider key -> manageFunction, used by the cookie-consent
// controller to wire each JSON-configured provider into the consent banner.
// Adding a new provider requires registering its manageFunction here (code)
// and flipping active:true + credentials in config/analytics_providers.json
// (no other code changes needed once registered).
const PROVIDER_MANAGERS = {
  google_analytics: manageGoogleAnalytics,
  mixpanel: manageMixpanel,
}

export function resolveManager(key) {
  return PROVIDER_MANAGERS[key] || null
}
