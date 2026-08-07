import Foundation
import OSLog

/// Where a Plus paywall or monetization action originated.
enum PaywallSource: String, Sendable {
    case settings
    case stampPhase = "stamp_phase"
    case sendAlert = "send_alert"
    case mailboxLimit = "mailbox_limit"
    case notifications
    case onboarding
}

/// Lightweight monetization event logging (OSLog). Ready to forward to a backend later.
enum MonetizationAnalytics {
    private static let logger = Logger(subsystem: "Postal", category: "Monetization")

    static func paywallPresented(source: PaywallSource) {
        logger.info("paywall_presented source=\(source.rawValue, privacy: .public)")
    }

    static func paywallDismissedWithoutPurchase(source: PaywallSource) {
        logger.info("paywall_dismissed_without_purchase source=\(source.rawValue, privacy: .public)")
    }

    static func upgradeTapped(source: PaywallSource) {
        logger.info("upgrade_tapped source=\(source.rawValue, privacy: .public)")
    }

    static func claimTapped(source: PaywallSource) {
        logger.info("claim_tapped source=\(source.rawValue, privacy: .public)")
    }

    static func sendBlockedNoStamps() {
        logger.info("send_blocked_no_stamps")
    }
}
