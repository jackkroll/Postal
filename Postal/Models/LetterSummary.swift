import Foundation

/// Firestore mirror at `users/{uid}/letters/{trackingNumber}`.
struct LetterSummary: Identifiable, Hashable {
    let trackingNumber: String
    let origin: LetterEndpoint
    let destination: LetterEndpoint
    let status: ShipmentStatus
    let hasLetter: Bool
    let letterFormat: LetterFormat?
    let letterMimeType: String?
    let letterEncoding: String?
    let letterByteSize: Int?
    let createdAt: Date?
    let updatedAt: Date?

    var id: String { trackingNumber }

    var letterMetadata: LetterMetadata? {
        guard hasLetter, let letterFormat, let letterMimeType else { return nil }
        return LetterMetadata(
            format: letterFormat,
            mimeType: letterMimeType,
            encoding: letterEncoding,
            filename: nil,
            byteSize: letterByteSize
        )
    }

    var sortDate: Date {
        updatedAt ?? createdAt ?? .distantPast
    }
}
