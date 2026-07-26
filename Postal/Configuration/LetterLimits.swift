import Foundation

/// Size ceilings for letter content, keyed by compose kind.
///
/// Shaped like the payload the backend is expected to serve so `LetterLimitsService`
/// can switch from the bundled defaults to a remote fetch without touching call sites.
struct LetterLimits: Codable, Equatable, Sendable {
    var maxTextBytes: Int
    var maxDrawingBytes: Int

    func maxBytes(for kind: LetterComposeKind) -> Int {
        switch kind {
        case .text: maxTextBytes
        case .drawing: maxDrawingBytes
        }
    }

    func exceedsLimit(_ byteCount: Int, for kind: LetterComposeKind) -> Bool {
        byteCount > maxBytes(for: kind)
    }

    /// "12 KB / 64 KB"
    func usageLabel(_ byteCount: Int, for kind: LetterComposeKind) -> String {
        let current = Self.formatted(byteCount)
        let limit = Self.formatted(maxBytes(for: kind))
        return "\(current) / \(limit)"
    }

    func overLimitMessage(for kind: LetterComposeKind) -> String {
        switch kind {
        case .text:
            return "This letter is over the \(Self.formatted(maxTextBytes)) limit. Shorten it to continue."
        case .drawing:
            return "This drawing is over the \(Self.formatted(maxDrawingBytes)) limit. Erase some strokes to continue."
        }
    }

    static func formatted(_ byteCount: Int) -> String {
        byteCountFormatter.string(fromByteCount: Int64(byteCount))
    }

    private static let byteCountFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()
}
