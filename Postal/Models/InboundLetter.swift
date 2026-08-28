import Foundation

/// Response from `GET /api/me/inbound-letters`.
/// Letter IDs are shipment IDs; fetch details via `GET /api/shipments/{id}`.
struct InboundLettersResponse: Codable, Hashable {
    let letterIDs: [String]

    enum CodingKeys: String, CodingKey {
        case letterIDs = "letter_ids"
    }
}

enum AppStorageKeys {
    /// When false, the Inbound tab is hidden on the letters page.
    static let showInboundLetters = "showInboundLetters"
    /// Shipment IDs for inbound letters the user has opened as recipient.
    static let openedInboundShipmentIDs = "openedInboundShipmentIDs"
}
