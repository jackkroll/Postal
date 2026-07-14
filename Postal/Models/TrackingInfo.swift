import Foundation

struct TrackingInfo: Codable, Hashable {
    let status: ShipmentStatus
    let destination: LetterEndpoint
    let origin: LetterEndpoint
    let trackingNumber: String

    enum CodingKeys: String, CodingKey {
        case status
        case destination = "to_box"
        case origin = "from_box"
        case trackingNumber = "tracking_number"
    }

    init(status: ShipmentStatus, destination: LetterEndpoint, origin: LetterEndpoint, trackingNumber: String) {
        self.status = status
        self.destination = destination
        self.origin = origin
        self.trackingNumber = trackingNumber
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(ShipmentStatus.self, forKey: .status)
        destination = LetterEndpoint(rawValue: try container.decode(String.self, forKey: .destination))
        origin = LetterEndpoint(rawValue: try container.decode(String.self, forKey: .origin))
        trackingNumber = try container.decode(String.self, forKey: .trackingNumber)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(status, forKey: .status)
        try container.encode(destination.rawValue, forKey: .destination)
        try container.encode(origin.rawValue, forKey: .origin)
        try container.encode(trackingNumber, forKey: .trackingNumber)
    }
}
