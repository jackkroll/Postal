import Foundation

/// Read-only plan ceilings and stamp tariff from `GET /api/me/limits`.
///
/// Safe to poll while composing — no stamp-grant side effects (prefer over entitlements).
struct LetterLimits: Equatable, Sendable {
    var isSubscriber: Bool
    var unlimitedSends: Bool
    var mailboxLimit: Int
    var ownedMailboxes: Int
    var stampPricing: StampPricing
    var maxTextBytes: Int
    var maxDrawingBytes: Int
    /// Plus ceilings for Free-plan upsell; nil when already subscribed.
    var subscriberTextMaxBytes: Int?
    var subscriberDrawingMaxBytes: Int?
    var scheduling: SchedulingEntitlements

    init(
        isSubscriber: Bool,
        unlimitedSends: Bool = false,
        mailboxLimit: Int = 1,
        ownedMailboxes: Int = 0,
        stampPricing: StampPricing = .default,
        maxTextBytes: Int,
        maxDrawingBytes: Int,
        subscriberTextMaxBytes: Int? = nil,
        subscriberDrawingMaxBytes: Int? = nil,
        scheduling: SchedulingEntitlements? = nil
    ) {
        self.isSubscriber = isSubscriber
        self.unlimitedSends = unlimitedSends
        self.mailboxLimit = mailboxLimit
        self.ownedMailboxes = ownedMailboxes
        self.stampPricing = stampPricing
        self.maxTextBytes = maxTextBytes
        self.maxDrawingBytes = maxDrawingBytes
        self.subscriberTextMaxBytes = subscriberTextMaxBytes
        self.subscriberDrawingMaxBytes = subscriberDrawingMaxBytes
        self.scheduling = scheduling
            ?? (isSubscriber ? .plusDefaults : .freeDefaults)
    }

    var planLabel: String {
        isSubscriber ? PromoText.planPlus : PromoText.planFree
    }

    func maxBytes(for kind: LetterComposeKind) -> Int {
        switch kind {
        case .text: maxTextBytes
        case .drawing: maxDrawingBytes
        }
    }

    func exceedsLimit(_ byteCount: Int, for kind: LetterComposeKind) -> Bool {
        byteCount > maxBytes(for: kind)
    }

    /// Stamp cost for the current letter size. Pro pays `0`.
    func stampCost(byteSize: Int, kind: LetterComposeKind) -> Int {
        stampPricing.cost(byteSize: byteSize, kind: kind, unlimitedSends: unlimitedSends)
    }

    /// Free / metered plans use the stamp fill meter; Plus keeps the size ceiling meter.
    var usesStampMeter: Bool { !unlimitedSends }

    /// 0…∞ relative to the size ceiling; UI clamps display to 0…1.
    func usageFraction(_ byteCount: Int, for kind: LetterComposeKind) -> Double {
        let ceiling = maxBytes(for: kind)
        guard ceiling > 0 else { return 0 }
        return Double(byteCount) / Double(ceiling)
    }

    /// Progress shown in the composer meter.
    ///
    /// Free (under the hard cap): stamp-bucket fill so each stamp allotment reads as 0…100%.
    /// Free (over the hard cap) and Plus: share of the plan size ceiling.
    func meterFraction(byteCount: Int, for kind: LetterComposeKind) -> Double {
        if usesStampMeter, !exceedsLimit(byteCount, for: kind) {
            return stampPricing.fillFraction(byteSize: byteCount, kind: kind)
        }
        return usageFraction(byteCount, for: kind)
    }

    /// Percent of the plan ceiling used (can exceed 100 when over).
    func usagePercent(byteCount: Int, for kind: LetterComposeKind) -> Int {
        Int((usageFraction(byteCount, for: kind) * 100).rounded())
    }

    /// Under-limit size usage, e.g. "84% of Plus limit".
    func formattedUsage(byteCount: Int, for kind: LetterComposeKind) -> String {
        let percent = min(usagePercent(byteCount: byteCount, for: kind), 100)
        return "\(percent)% of \(planLabel) limit"
    }

    /// Caption under the Free stamp meter while filling the current stamp.
    func formattedStampFill(byteCount: Int, for kind: LetterComposeKind) -> String {
        let percent = Int((stampPricing.fillFraction(byteSize: byteCount, kind: kind) * 100).rounded())
        let cost = stampCost(byteSize: byteCount, kind: kind)
        if cost <= 1 {
            return "\(min(percent, 100))% of this stamp"
        }
        return "\(min(percent, 100))% of stamp \(cost)"
    }

    func overLimitMessage(byteCount: Int, for kind: LetterComposeKind) -> String {
        let relative = overAmountDescription(byteCount: byteCount, for: kind)
        switch kind {
        case .text:
            return "This letter is \(relative). Shorten it to continue."
        case .drawing:
            return "This drawing is \(relative). Erase some strokes to continue."
        }
    }

    /// How far over the ceiling, without byte units — e.g. "12% over the Free limit", "2.4× the Plus limit".
    func overAmountDescription(byteCount: Int, for kind: LetterComposeKind) -> String {
        let plan = planLabel
        let ratio = usageFraction(byteCount, for: kind)
        guard maxBytes(for: kind) > 0, ratio > 1 else {
            return "over the \(plan) limit"
        }

        if ratio < 2 {
            let percentOver = max(Int(((ratio - 1) * 100).rounded()), 1)
            return "\(percentOver)% over the \(plan) limit"
        }

        return "\(Self.formatMultiplier(ratio)) the \(plan) limit"
    }

    private static func formatMultiplier(_ ratio: Double) -> String {
        let roundedToTenth = (ratio * 10).rounded() / 10
        if abs(roundedToTenth - roundedToTenth.rounded()) < 0.05 {
            return "\(Int(roundedToTenth.rounded()))×"
        }
        return String(format: "%.1f×", roundedToTenth)
    }
}

extension LetterLimits: Decodable {
    private enum RootKeys: String, CodingKey {
        case isSubscriber = "is_subscriber"
        case unlimitedSends = "unlimited_sends"
        case mailboxLimit = "mailbox_limit"
        case ownedMailboxes = "owned_mailboxes"
        case stampPricing = "stamp_pricing"
        case letter
        case scheduling
    }

    init(from decoder: Decoder) throws {
        let root = try decoder.container(keyedBy: RootKeys.self)
        let isSubscriber = try root.decode(Bool.self, forKey: .isSubscriber)
        let letter = try root.decode(LetterLimitBlock.self, forKey: .letter)
        self.init(
            isSubscriber: isSubscriber,
            unlimitedSends: try root.decodeIfPresent(Bool.self, forKey: .unlimitedSends) ?? isSubscriber,
            mailboxLimit: try root.decodeIfPresent(Int.self, forKey: .mailboxLimit) ?? 1,
            ownedMailboxes: try root.decodeIfPresent(Int.self, forKey: .ownedMailboxes) ?? 0,
            stampPricing: try root.decodeIfPresent(StampPricing.self, forKey: .stampPricing) ?? .default,
            maxTextBytes: letter.textMaxBytes,
            maxDrawingBytes: letter.drawingMaxBytes,
            subscriberTextMaxBytes: letter.subscriber?.textMaxBytes,
            subscriberDrawingMaxBytes: letter.subscriber?.drawingMaxBytes,
            scheduling: try root.decodeIfPresent(SchedulingEntitlements.self, forKey: .scheduling)
        )
    }
}

extension LetterLimits {
    /// Preview-only limits for SwiftUI previews (Free-tier sample tariff).
    static let preview = LetterLimits(
        isSubscriber: false,
        unlimitedSends: false,
        mailboxLimit: 1,
        ownedMailboxes: 0,
        stampPricing: .default,
        maxTextBytes: 4_096,
        maxDrawingBytes: 20_480,
        subscriberTextMaxBytes: 12_288,
        subscriberDrawingMaxBytes: 61_440
    )

    /// Free plan that can span multiple stamps before the hard size cap.
    static let previewMultiStamp = LetterLimits(
        isSubscriber: false,
        unlimitedSends: false,
        mailboxLimit: 1,
        ownedMailboxes: 0,
        stampPricing: .default,
        maxTextBytes: 12_288,
        maxDrawingBytes: 61_440,
        subscriberTextMaxBytes: 12_288,
        subscriberDrawingMaxBytes: 61_440
    )

    /// Plus / unlimited-sends preview (size ceiling meter).
    static let previewPlus = LetterLimits(
        isSubscriber: true,
        unlimitedSends: true,
        mailboxLimit: 5,
        ownedMailboxes: 1,
        stampPricing: .default,
        maxTextBytes: 12_288,
        maxDrawingBytes: 61_440
    )
}
