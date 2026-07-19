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
    let createdAt: Date?
    let updatedAt: Date?

    var sortDate: Date {
        updatedAt ?? createdAt ?? .distantPast
    }

    init(shipment: Shipment) {
        id = shipment.id
        trackingNumber = shipment.trackingNumber
        status = shipment.status
        originName = shipment.originDisplayName
        destinationName = shipment.destinationDisplayName
        hasLetter = shipment.letter != nil
        letterFormat = shipment.letter?.format
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
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum AppStorageKeys {
    /// When false, the Inbound tab is hidden on the letters page.
    static let showInboundLetters = "showInboundLetters"
}
