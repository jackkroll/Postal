import Foundation

/// Size ceilings for letter content, keyed by compose kind.
///
/// Matches `GET /api/me/limits` (`max_text_bytes`, `max_drawing_bytes`).
struct LetterLimits: Codable, Equatable, Sendable {
    var maxTextBytes: Int
    var maxDrawingBytes: Int

    enum CodingKeys: String, CodingKey {
        case maxTextBytes = "max_text_bytes"
        case maxDrawingBytes = "max_drawing_bytes"
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

    func formattedCeiling(for kind: LetterComposeKind) -> String {
        Self.formatByteCount(maxBytes(for: kind))
    }

    func formattedUsage(byteCount: Int, for kind: LetterComposeKind) -> String {
        "\(Self.formatByteCount(byteCount)) / \(formattedCeiling(for: kind))"
    }

    func overLimitMessage(for kind: LetterComposeKind) -> String {
        let ceiling = formattedCeiling(for: kind)
        switch kind {
        case .text:
            return "This letter is over the \(ceiling) limit. Shorten it to continue."
        case .drawing:
            return "This drawing is over the \(ceiling) limit. Erase some strokes to continue."
        }
    }

    static func formatByteCount(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: Int64(max(bytes, 0)))
    }
}
