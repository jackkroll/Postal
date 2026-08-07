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
///
/// Prefer `GET /api/me/limits` while composing — entitlements may credit the
/// one-time free stamp grant as a side effect.
struct UserEntitlements: Codable, Hashable, Sendable {
    var isSubscriber: Bool
    var expiresAt: String?
    var stampBalance: Int
    var stampPricing: StampPricing
    var unlimitedSends: Bool
    var mailboxLimit: Int
    var ownedMailboxes: Int
    var letter: LetterLimitBlock?
    var allowance: StampAllowanceInfo
    var notification: NotificationEntitlements
    var scheduling: SchedulingEntitlements

    enum CodingKeys: String, CodingKey {
        case isSubscriber = "is_subscriber"
        case expiresAt = "expires_at"
        case stampBalance = "stamp_balance"
        case stampPricing = "stamp_pricing"
        case unlimitedSends = "unlimited_sends"
        case mailboxLimit = "mailbox_limit"
        case ownedMailboxes = "owned_mailboxes"
        case letter
        case allowance
        case notification
        case scheduling
    }

    init(
        isSubscriber: Bool,
        expiresAt: String?,
        stampBalance: Int,
        stampPricing: StampPricing = .default,
        unlimitedSends: Bool,
        mailboxLimit: Int,
        ownedMailboxes: Int,
        letter: LetterLimitBlock? = nil,
        allowance: StampAllowanceInfo,
        notification: NotificationEntitlements,
        scheduling: SchedulingEntitlements? = nil
    ) {
        self.isSubscriber = isSubscriber
        self.expiresAt = expiresAt
        self.stampBalance = stampBalance
        self.stampPricing = stampPricing
        self.unlimitedSends = unlimitedSends
        self.mailboxLimit = mailboxLimit
        self.ownedMailboxes = ownedMailboxes
        self.letter = letter
        self.allowance = allowance
        self.notification = notification
        self.scheduling = scheduling
            ?? (isSubscriber ? .plusDefaults : .freeDefaults)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isSubscriber = try container.decode(Bool.self, forKey: .isSubscriber)
        expiresAt = try container.decodeIfPresent(String.self, forKey: .expiresAt)
        // Balance is sourced from RC; tolerate a missing server field.
        stampBalance = try container.decodeIfPresent(Int.self, forKey: .stampBalance) ?? 0
        stampPricing = try container.decodeIfPresent(StampPricing.self, forKey: .stampPricing) ?? .default
        unlimitedSends = try container.decode(Bool.self, forKey: .unlimitedSends)
        mailboxLimit = try container.decode(Int.self, forKey: .mailboxLimit)
        ownedMailboxes = try container.decode(Int.self, forKey: .ownedMailboxes)
        letter = try container.decodeIfPresent(LetterLimitBlock.self, forKey: .letter)
        allowance = try container.decode(StampAllowanceInfo.self, forKey: .allowance)
        notification = try container.decode(NotificationEntitlements.self, forKey: .notification)
        scheduling = try container.decodeIfPresent(SchedulingEntitlements.self, forKey: .scheduling)
            ?? (isSubscriber ? .plusDefaults : .freeDefaults)
    }

    var canClaimAnotherMailbox: Bool {
        ownedMailboxes < mailboxLimit
    }

    /// Stamp cost for a letter of the given size (0 when Plus).
    func stampCost(byteSize: Int, kind: LetterComposeKind) -> Int {
        stampPricing.cost(byteSize: byteSize, kind: kind, unlimitedSends: unlimitedSends)
    }

    func hasStampsToSend(cost: Int) -> Bool {
        unlimitedSends || stampBalance >= cost
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

/// Structured `detail` on HTTP 402 from `POST /api/shipments`.
struct InsufficientStampsDetail: Codable, Hashable, Sendable {
    var message: String?
    var stampBalance: Int?
    var required: Int?
    var allowanceClaimable: Bool?
    var nextClaimAt: String?

    enum CodingKeys: String, CodingKey {
        case message
        case stampBalance = "stamp_balance"
        case required
        case allowanceClaimable = "allowance_claimable"
        case nextClaimAt = "next_claim_at"
    }
}
