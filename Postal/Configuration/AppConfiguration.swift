import Foundation

enum AppConfiguration {
    //static let apiBaseURL = URL(string: "http://postal.jackk.dev")!
    static let apiBaseURL = URL(string: "http://192.168.1.115:8000")!

    /// RevenueCat public SDK key (iOS).
    static let revenueCatAPIKey = "appl_KUhyCYspPQGtTxnwtTrnBPRQoZT"

    /// RevenueCat virtual currency code for postage stamps.
    static let stampVirtualCurrencyCode = "stamps"

    /// Fallback letter size ceilings when `GET /api/me/limits` is unavailable.
    static let letterLimits = LetterLimits(
        maxTextBytes: 65_536,
        maxDrawingBytes: 4 * 1_024 * 1_024
    )
}
