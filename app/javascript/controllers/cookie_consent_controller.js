import { Controller } from "@hotwired/stimulus"
import { CookiesConsent, manageGoogleAnalytics } from "@metamorfosilab/cookies-consent"

// Connects to data-controller="cookie-consent"
export default class extends Controller {
  connect() {
    if (window.__cookieConsentInstance) {
      this.consent = window.__cookieConsentInstance
      return
    }

    this.consent = new CookiesConsent({
      expirationDays: 365,
      sameSite: "lax",
      position: "bottom",
      buttons: ["accept", "reject", "settings"],
      content: {
        title: "We value your privacy",
        message: "We use cookies to improve your experience on our site and, with your consent, to understand how visitors use our site via Google Analytics. You can accept or reject analytics cookies, or manage your preferences in settings.",
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
      cookies: [
        {
          name: "essential",
          title: "Essential",
          description: "Required for the website to function properly. Cannot be disabled.",
          disabled: true,
          checked: true,
        },
        {
          name: "analytics",
          title: "Analytics",
          description: "Helps us understand how visitors use our site so we can improve it.",
          checked: false,
          cookies: [
            {
              name: "google-analytics",
              title: "Google Analytics",
              onLoad: false,
              code: "G-6ZPXSBZYL8",
              manageFunction: manageGoogleAnalytics,
            },
          ],
        },
      ],
    })

    window.__cookieConsentInstance = this.consent
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
