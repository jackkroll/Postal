import Foundation

/// Nested allowance block from `GET /api/me/entitlements`.
struct StampAllowanceInfo: Codable, Hashable, Sendable {
    var amount: Int
    var intervalSeconds: Int
    var claimable: Bool
    var lastClaimedAt: String?
    var nextClaimAt: String?
    var availableWhileSubscribed: Bool

    enum CodingKeys: String, CodingKey {
        case amount
        case intervalSeconds = "interval_seconds"
        case claimable
        case lastClaimedAt = "last_claimed_at"
        case nextClaimAt = "next_claim_at"
        case availableWhileSubscribed = "available_while_subscribed"
    }
}

/// Nested notification entitlement block from `GET /api/me/entitlements`.
struct NotificationEntitlements: Codable, Hashable, Sendable {
    var allowedSent: [String]
    var allowedInbound: [String]
    var defaultSent: String
    var defaultInbound: String

    enum CodingKeys: String, CodingKey {
        case allowedSent = "allowed_sent"
        case allowedInbound = "allowed_inbound"
        case defaultSent = "default_sent"
        case defaultInbound = "default_inbound"
    }

    var allowedSentModes: [SentNotificationMode] {
        allowedSent.compactMap(SentNotificationMode.init(rawValue:))
    }

    var allowedInboundModes: [InboundNotificationMode] {
        allowedInbound.compactMap(InboundNotificationMode.init(rawValue:))
    }
}

/// Response from `GET /api/me/entitlements`.
///
/// `stampBalance` may still appear in the JSON for compatibility, but the app
/// overlays it from RevenueCat’s `STAMP` virtual currency after fetch.
struct UserEntitlements: Codable, Hashable, Sendable {
    var isSubscriber: Bool
    var expiresAt: String?
    var stampBalance: Int
    var stampsPerSend: Int
    var unlimitedSends: Bool
    var mailboxLimit: Int
    var ownedMailboxes: Int
    var allowance: StampAllowanceInfo
    var notification: NotificationEntitlements

    enum CodingKeys: String, CodingKey {
        case isSubscriber = "is_subscriber"
        case expiresAt = "expires_at"
        case stampBalance = "stamp_balance"
        case stampsPerSend = "stamps_per_send"
        case unlimitedSends = "unlimited_sends"
        case mailboxLimit = "mailbox_limit"
        case ownedMailboxes = "owned_mailboxes"
        case allowance
        case notification
    }

    init(
        isSubscriber: Bool,
        expiresAt: String?,
        stampBalance: Int,
        stampsPerSend: Int,
        unlimitedSends: Bool,
        mailboxLimit: Int,
        ownedMailboxes: Int,
        allowance: StampAllowanceInfo,
        notification: NotificationEntitlements
    ) {
        self.isSubscriber = isSubscriber
        self.expiresAt = expiresAt
        self.stampBalance = stampBalance
        self.stampsPerSend = stampsPerSend
        self.unlimitedSends = unlimitedSends
        self.mailboxLimit = mailboxLimit
        self.ownedMailboxes = ownedMailboxes
        self.allowance = allowance
        self.notification = notification
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isSubscriber = try container.decode(Bool.self, forKey: .isSubscriber)
        expiresAt = try container.decodeIfPresent(String.self, forKey: .expiresAt)
        // Balance is sourced from RC; tolerate a missing server field.
        stampBalance = try container.decodeIfPresent(Int.self, forKey: .stampBalance) ?? 0
        stampsPerSend = try container.decode(Int.self, forKey: .stampsPerSend)
        unlimitedSends = try container.decode(Bool.self, forKey: .unlimitedSends)
        mailboxLimit = try container.decode(Int.self, forKey: .mailboxLimit)
        ownedMailboxes = try container.decode(Int.self, forKey: .ownedMailboxes)
        allowance = try container.decode(StampAllowanceInfo.self, forKey: .allowance)
        notification = try container.decode(NotificationEntitlements.self, forKey: .notification)
    }

    var canClaimAnotherMailbox: Bool {
        ownedMailboxes < mailboxLimit
    }

    var hasStampsToSend: Bool {
        unlimitedSends || stampBalance >= max(stampsPerSend, 1)
    }

    var planTitle: String {
        isSubscriber ? PromoText.planPlus : PromoText.planFree
    }
}

/// Successful body for `POST /api/me/stamps/allowance/claim`.
///
/// `stampBalance` is optional legacy; the app refreshes balance from RC after claim.
struct StampAllowanceClaimResponse: Codable, Hashable, Sendable {
    var credited: Int
    var stampBalance: Int?
    var nextClaimAt: String?

    enum CodingKeys: String, CodingKey {
        case credited
        case stampBalance = "stamp_balance"
        case nextClaimAt = "next_claim_at"
    }
}
