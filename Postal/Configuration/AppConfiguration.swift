import Foundation

enum AppConfiguration {
    #if DEBUG
    //static let apiBaseURL = URL(string: "http://192.168.1.115:8000")!
    static let apiBaseURL = URL(string: "http://postal.jackk.dev")!
    #else
    static let apiBaseURL = URL(string: "http://postal.jackk.dev")!
    #endif

    /// RevenueCat public SDK key (iOS).
    static let revenueCatAPIKey = "appl_KUhyCYspPQGtTxnwtTrnBPRQoZT"

    /// RevenueCat virtual currency code for postage stamps.
    static let stampVirtualCurrencyCode = "stamps"

    /// Fallback letter size ceilings when `GET /api/me/limits` is unavailable.
    /// Matches free-tier defaults from the limits API.
    static let letterLimits = LetterLimits(
        maxTextBytes: 16_384,
        maxDrawingBytes: 2 * 1_024 * 1_024,
        isSubscriber: false
    )
}
