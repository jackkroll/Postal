import Foundation

/// Size ceilings for letter content, keyed by compose kind.
///
/// Decodes `GET /api/me/limits` (`is_subscriber`, `letter.text_max_bytes`, `letter.drawing_max_bytes`).
struct LetterLimits: Equatable, Sendable {
    var maxTextBytes: Int
    var maxDrawingBytes: Int
    /// Whether the active ceilings are Plus (subscriber) vs Free.
    var isSubscriber: Bool

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

    /// 0…∞ relative to the ceiling; UI clamps display to 0…1.
    func usageFraction(_ byteCount: Int, for kind: LetterComposeKind) -> Double {
        let ceiling = maxBytes(for: kind)
        guard ceiling > 0 else { return 0 }
        return Double(byteCount) / Double(ceiling)
    }

    /// Percent of the plan ceiling used (can exceed 100 when over).
    func usagePercent(byteCount: Int, for kind: LetterComposeKind) -> Int {
        Int((usageFraction(byteCount, for: kind) * 100).rounded())
    }

    /// Under-limit usage, e.g. "84% of Free limit".
    func formattedUsage(byteCount: Int, for kind: LetterComposeKind) -> String {
        let percent = min(usagePercent(byteCount: byteCount, for: kind), 100)
        return "\(percent)% of \(planLabel) limit"
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
        case letter
    }

    private enum LetterKeys: String, CodingKey {
        case textMaxBytes = "text_max_bytes"
        case drawingMaxBytes = "drawing_max_bytes"
    }

    init(from decoder: Decoder) throws {
        let root = try decoder.container(keyedBy: RootKeys.self)
        isSubscriber = try root.decode(Bool.self, forKey: .isSubscriber)
        let letter = try root.nestedContainer(keyedBy: LetterKeys.self, forKey: .letter)
        maxTextBytes = try letter.decode(Int.self, forKey: .textMaxBytes)
        maxDrawingBytes = try letter.decode(Int.self, forKey: .drawingMaxBytes)
    }
}
