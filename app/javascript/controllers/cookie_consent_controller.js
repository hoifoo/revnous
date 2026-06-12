import { Controller } from "@hotwired/stimulus"
import { CookiesConsent, manageGoogleAnalytics } from "@metamorfosilab/cookies-consent"
import { resolveManager } from "../lib/analytics_providers"

// Connects to data-controller="cookie-consent"
export default class extends Controller {
  connect() {
    window.__analyticsConsent = window.__analyticsConsent || {}

    if (window.__cookieConsentInstance) {
      this.consent = window.__cookieConsentInstance
      return
    }

    const providers = this.parseProviders()
    const analyticsCookies = this.buildProviderCookies(providers)

    const cookies = [
      {
        name: "essential",
        title: "Essential",
        description: "Required for the website to function properly. Cannot be disabled.",
        disabled: true,
        checked: true,
      },
    ]

    if (analyticsCookies.length > 0) {
      cookies.push({
        name: "analytics",
        title: "Analytics",
        description: "Helps us understand how visitors use our site so we can improve it.",
        checked: false,
        cookies: analyticsCookies,
      })
    }

    this.consent = new CookiesConsent({
      expirationDays: 365,
      sameSite: "lax",
      position: "bottom",
      buttons: ["accept", "reject", "settings"],
      content: {
        title: "We value your privacy",
        message: "We use cookies to improve your experience on our site and, with your consent, to understand how visitors use our site via analytics tools. You can accept or reject analytics cookies, or manage your preferences in settings.",
        btnAccept: "Accept",
        btnReject: "Reject",
        btnSettings: "Settings",
        settingsHeader: "Cookie preferences",
        settingsFooter: "You can change your preferences at any time via the Cookie Settings link in the footer.",
        btnSettingsSelectAll: "Select all",
        btnSettingsUnselectAll: "Unselect all",
        btnSettingsAccept: "Save preferences",
        policy: "Privacy Policy",
        policyLink: this.element.dataset.privacyUrl,
      },
      cookies,
    })

    window.__cookieConsentInstance = this.consent

    this.maybeResetForDebug()
  }

  // Debug helper: visiting any page with ?cookie_consent=reset clears the
  // stored consent and reshows the banner, so the consent flow can be
  // re-tested without manually clearing cookies/storage.
  maybeResetForDebug() {
    const param = new URLSearchParams(window.location.search).get("cookie_consent")
    if (param !== "reset") return

    if (this.consent.removeCookies) this.consent.removeCookies()
    window.__analyticsConsent = {}
    if (this.consent.showMessage) this.consent.showMessage()
  }

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

  // Groups active providers by category and builds one cookie entry per
  // provider. Categories with zero providers produce no cookies and are
  // skipped by the caller.
  buildProviderCookies(providers) {
    return providers
      .filter((provider) => provider && provider.key)
      .map((provider) => {
        const config = provider.config || {}
        const credential = provider.key === "mixpanel" ? config.token : config.measurement_id
        const baseManager = resolveManager(provider.key)

        return {
          name: provider.key,
          title: provider.name,
          onLoad: false,
          checked: false,
          code: credential,
          config,
          manageFunction: this.wrapManager(provider.key, baseManager),
        }
      })
  }

  // Wraps each provider's manageFunction so window.__analyticsConsent stays
  // in sync with accept/reject decisions, regardless of whether the
  // underlying manager already does so (Mixpanel does; GA's built-in
  // manageGoogleAnalytics does not).
  wrapManager(key, manager) {
    if (!manager) return null

    return (args) => {
      manager(args)

      if (manager === manageGoogleAnalytics) {
        window.__analyticsConsent[key] = !!args.status && args.lifecycle !== "reject"
        if (args.lifecycle === "reject") {
          window.__analyticsConsent[key] = false
        }
      }
    }
  }

  toggleSettings() {
    if (window.__cookieConsentInstance) {
      window.__cookieConsentInstance.toggleSettings()
    }
  }

  teardown() {
    this.consent = null
  }
}
