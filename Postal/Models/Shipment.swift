import Foundation

enum ShipmentStatus: String, Codable, Hashable {
    case awaitingPickup = "awaiting_pickup"
    case inTransit = "in_transit"
    case atFacility = "at_facility"
    case outForDelivery = "out_for_delivery"
    case delivered = "delivered"
    case failed = "failed"
}

struct Shipment: Codable, Identifiable, Hashable {
    let id: String
    let trackingNumber: String
    let userID: String?
    let originPostOffice: PostOffice
    let destinationPostOffice: PostOffice
    let status: ShipmentStatus
    let currentFacility: PostOffice?
    let expectedDeliveryTime: Date?
    let routeFound: Bool
    let letter: LetterMetadata?
    let requestedAt: Date?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case trackingNumber = "tracking_number"
        case userID = "user_id"
        case originPostOffice = "origin_post_office"
        case destinationPostOffice = "destination_post_office"
        case status
        case currentFacility = "current_facility"
        case expectedDeliveryTime = "expected_delivery_time"
        case routeFound = "route_found"
        case letter
        case requestedAt = "requested_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ShipmentListResponse: Codable {
    let shipments: [Shipment]
}
