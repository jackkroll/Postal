import Foundation

/// Response from `GET /api/me/inbound-letters`.
/// Letter IDs are shipment IDs; fetch details via `GET /api/shipments/{id}`.
struct InboundLettersResponse: Codable, Hashable {
    let letterIDs: [String]

    enum CodingKeys: String, CodingKey {
        case letterIDs = "letter_ids"
    }
}

/// Display model for an inbound letter row on the letters page.
struct InboundLetterItem: Identifiable, Hashable {
    let id: String
    let trackingNumber: String
    let status: ShipmentStatus
    let originName: String
    let destinationName: String
    let hasLetter: Bool
    let letterFormat: LetterFormat?
    let letterMimeType: String?
    let letterEncoding: String?
    let letterByteSize: Int?
    let canReadLetter: Bool
    let createdAt: Date?
    let updatedAt: Date?

    var sortDate: Date {
        updatedAt ?? createdAt ?? .distantPast
    }

    /// Summary used to open tracking / letter reading from the inbound list.
    var letterSummary: LetterSummary {
        LetterSummary(
            trackingNumber: trackingNumber,
            shipmentID: id,
            origin: LetterEndpoint(rawValue: originName),
            destination: LetterEndpoint(rawValue: destinationName),
            status: status,
            hasLetter: hasLetter,
            letterFormat: letterFormat,
            letterMimeType: letterMimeType,
            letterEncoding: letterEncoding,
            letterByteSize: letterByteSize,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    init(shipment: Shipment) {
        id = shipment.id
        trackingNumber = shipment.trackingNumber
        status = shipment.status
        originName = shipment.originDisplayName
        destinationName = shipment.destinationDisplayName
        hasLetter = shipment.letter != nil
        letterFormat = shipment.letter?.format
        letterMimeType = shipment.letter?.mimeType
        letterEncoding = shipment.letter?.encoding
        letterByteSize = shipment.letter?.byteSize
        canReadLetter = shipment.canReadLetter
        createdAt = shipment.createdAt ?? shipment.requestedAt
        updatedAt = shipment.updatedAt ?? shipment.requestedAt
    }

    init(
        id: String,
        trackingNumber: String,
        status: ShipmentStatus,
        originName: String,
        destinationName: String,
        hasLetter: Bool = false,
        letterFormat: LetterFormat? = nil,
        letterMimeType: String? = nil,
        letterEncoding: String? = nil,
        letterByteSize: Int? = nil,
        canReadLetter: Bool = false,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.trackingNumber = trackingNumber
        self.status = status
        self.originName = originName
        self.destinationName = destinationName
        self.hasLetter = hasLetter
        self.letterFormat = letterFormat
        self.letterMimeType = letterMimeType
        self.letterEncoding = letterEncoding
        self.letterByteSize = letterByteSize
        self.canReadLetter = canReadLetter
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum AppStorageKeys {
    /// When false, the Inbound tab is hidden on the letters page.
    static let showInboundLetters = "showInboundLetters"
}
