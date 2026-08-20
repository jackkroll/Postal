import Foundation

enum AppConfiguration {
    #if DEBUG
    //static let apiBaseURL = URL(string: "http://192.168.1.115:8000")!
    static let apiBaseURL = URL(string: "http://postal.jackk.dev")!
    #else
    static let apiBaseURL = URL(string: "http://postal.jackk.dev")!
    #endif

    /// Host used for universal / web deep links (`https://postal.jackk.dev/track/...`, `/invite/...`).
    static let deepLinkHost = "postal.jackk.dev"

    /// Accepted hosts when parsing inbound track / invite URLs (http or https).
    static let deepLinkHosts: Set<String> = [deepLinkHost]

    /// Custom URL scheme fallback: `postal://track/{number}`, `postal://invite/{mailboxID}`.
    static let urlScheme = "postal"

    /// RevenueCat public SDK key (iOS).
    static let revenueCatAPIKey = "appl_KUhyCYspPQGtTxnwtTrnBPRQoZT"

    /// RevenueCat virtual currency code for postage stamps.
    static let stampVirtualCurrencyCode = "stamps"

}
