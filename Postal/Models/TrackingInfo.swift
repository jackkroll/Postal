import Foundation

struct TrackingInfo: Codable, Hashable {
    let status: ShipmentStatus
    let toBox: String
    let fromBox: String
    let trackingNumber: String
}
