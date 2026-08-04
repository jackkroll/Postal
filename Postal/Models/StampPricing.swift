import Foundation

/// Server stamp tariff from `stamp_pricing` on `/api/me/limits` and `/api/me/entitlements`.
///
/// Free users: `cost = max(min_stamps, ceil(byte_size / bytes_per_stamp))`.
/// Pro (`unlimited_sends`): cost is always `0`.
struct StampPricing: Codable, Hashable, Sendable {
    var textBytesPerStamp: Int
    var drawingBytesPerStamp: Int
    var minStamps: Int

    enum CodingKeys: String, CodingKey {
        case textBytesPerStamp = "text_bytes_per_stamp"
        case drawingBytesPerStamp = "drawing_bytes_per_stamp"
        case minStamps = "min_stamps"
    }

    /// Spec defaults for Free tier when the field is absent.
    static let `default` = StampPricing(
        textBytesPerStamp: 4_096,
        drawingBytesPerStamp: 20_480,
        minStamps: 1
    )

    func bytesPerStamp(for kind: LetterComposeKind) -> Int {
        switch kind {
        case .text: textBytesPerStamp
        case .drawing: drawingBytesPerStamp
        }
    }

    /// Stamp cost for a letter payload.
    /// Empty / missing content (`byteSize == 0`) still costs `minStamps` when not unlimited.
    func cost(byteSize: Int, kind: LetterComposeKind, unlimitedSends: Bool) -> Int {
        guard !unlimitedSends else { return 0 }
        let perStamp = max(bytesPerStamp(for: kind), 1)
        let sizeBased = Int((Double(max(byteSize, 0)) / Double(perStamp)).rounded(.up))
        return max(minStamps, sizeBased)
    }

    /// How full the *current* stamp bucket is (0…1).
    ///
    /// Resets toward 0 when `byteSize` crosses into the next stamp’s allotment.
    func fillFraction(byteSize: Int, kind: LetterComposeKind) -> Double {
        let perStamp = max(bytesPerStamp(for: kind), 1)
        guard byteSize > 0 else { return 0 }
        let remainder = byteSize % perStamp
        if remainder == 0 { return 1 }
        return Double(remainder) / Double(perStamp)
    }
}

/// Active letter size ceilings (`letter.text_max_bytes` / `drawing_max_bytes`).
struct LetterSizeCaps: Codable, Hashable, Sendable {
    var textMaxBytes: Int
    var drawingMaxBytes: Int

    enum CodingKeys: String, CodingKey {
        case textMaxBytes = "text_max_bytes"
        case drawingMaxBytes = "drawing_max_bytes"
    }

    func maxBytes(for kind: LetterComposeKind) -> Int {
        switch kind {
        case .text: textMaxBytes
        case .drawing: drawingMaxBytes
        }
    }
}

/// `letter` object on limits / entitlements, including optional Plus upsell ceilings.
struct LetterLimitBlock: Codable, Hashable, Sendable {
    var textMaxBytes: Int
    var drawingMaxBytes: Int
    var subscriber: LetterSizeCaps?

    enum CodingKeys: String, CodingKey {
        case textMaxBytes = "text_max_bytes"
        case drawingMaxBytes = "drawing_max_bytes"
        case subscriber
    }

    init(textMaxBytes: Int, drawingMaxBytes: Int, subscriber: LetterSizeCaps? = nil) {
        self.textMaxBytes = textMaxBytes
        self.drawingMaxBytes = drawingMaxBytes
        self.subscriber = subscriber
    }

    var active: LetterSizeCaps {
        LetterSizeCaps(textMaxBytes: textMaxBytes, drawingMaxBytes: drawingMaxBytes)
    }
}

/// Sync metadata from `POST /api/me/entitlements/refresh`.
struct EntitlementsSyncResult: Codable, Hashable, Sendable {
    var synced: Bool
    var reason: String
    var stampsCredited: Int
    var error: String?
    var statusCode: Int?

    enum CodingKeys: String, CodingKey {
        case synced
        case reason
        case stampsCredited = "stamps_credited"
        case error
        case statusCode = "status_code"
    }
}

/// Full body of `POST /api/me/entitlements/refresh` (entitlements + sync).
struct EntitlementsRefreshResponse: Decodable, Sendable {
    var entitlements: UserEntitlements
    var sync: EntitlementsSyncResult

    private enum CodingKeys: String, CodingKey {
        case sync
    }

    init(from decoder: Decoder) throws {
        entitlements = try UserEntitlements(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sync = try container.decode(EntitlementsSyncResult.self, forKey: .sync)
    }
}
