import Foundation

/// Public tracking summary from `GET /track/{trackingNumber}` (no auth).
/// Field names are camelCase — unlike auth shipment endpoints.
struct TrackingInfo: Codable, Hashable {
    let trackingNumber: String
    let status: ShipmentStatus
    let fromPostOffice: PostOffice
    let toPostOffice: PostOffice
    let expectedDeliveryTime: Date?
    let updatedAt: Date

    init(
        trackingNumber: String,
        status: ShipmentStatus,
        fromPostOffice: PostOffice,
        toPostOffice: PostOffice,
        expectedDeliveryTime: Date?,
        updatedAt: Date
    ) {
        self.trackingNumber = trackingNumber
        self.status = status
        self.fromPostOffice = fromPostOffice
        self.toPostOffice = toPostOffice
        self.expectedDeliveryTime = expectedDeliveryTime
        self.updatedAt = updatedAt
    }
}
