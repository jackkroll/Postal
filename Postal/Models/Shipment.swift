import Foundation

enum ShipmentStatus: String, Codable, Hashable {
    case awaitingPickup = "awaiting_pickup"
    case inTransit = "in_transit"
    case atFacility = "at_facility"
    case outForDelivery = "out_for_delivery"
    case delivered = "delivered"
    case failed = "failed"
}

struct Shipment: Decodable, Identifiable, Hashable {
    let id: String
    let trackingNumber: String
    let userID: String?
    let originBoxID: MailboxID?
    let destinationBoxID: MailboxID?
    let originPostOffice: PostOffice?
    let destinationPostOffice: PostOffice?
    let status: ShipmentStatus
    let currentFacility: PostOffice?
    let expectedDeliveryTime: Date?
    let routeFound: Bool
    let letter: LetterMetadata?
    let canReadLetter: Bool
    let requestedAt: Date?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case trackingNumber = "tracking_number"
        case userID = "user_id"
        case originBoxID = "origin_box_id"
        case destinationBoxID = "destination_box_id"
        case originPostOffice = "origin_post_office"
        case destinationPostOffice = "destination_post_office"
        case status
        case currentFacility = "current_facility"
        case expectedDeliveryTime = "expected_delivery_time"
        case routeFound = "route_found"
        case letter
        case canReadLetter = "can_read_letter"
        case requestedAt = "requested_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        trackingNumber = try container.decodeIfPresent(String.self, forKey: .trackingNumber) ?? id
        userID = try container.decodeIfPresent(String.self, forKey: .userID)
        originBoxID = try container.decodeIfPresent(MailboxID.self, forKey: .originBoxID)
        destinationBoxID = try container.decodeIfPresent(MailboxID.self, forKey: .destinationBoxID)
        originPostOffice = try container.decodeIfPresent(PostOffice.self, forKey: .originPostOffice)
        destinationPostOffice = try container.decodeIfPresent(PostOffice.self, forKey: .destinationPostOffice)
        status = try container.decode(ShipmentStatus.self, forKey: .status)
        currentFacility = try container.decodeIfPresent(PostOffice.self, forKey: .currentFacility)
        expectedDeliveryTime = try container.decodeIfPresent(Date.self, forKey: .expectedDeliveryTime)
        routeFound = try container.decodeIfPresent(Bool.self, forKey: .routeFound) ?? false
        letter = try container.decodeIfPresent(LetterMetadata.self, forKey: .letter)
        canReadLetter = try container.decodeIfPresent(Bool.self, forKey: .canReadLetter) ?? false
        requestedAt = try container.decodeIfPresent(Date.self, forKey: .requestedAt)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    var originEndpoint: LetterEndpoint {
        if let originBoxID {
            return LetterEndpoint(mailboxID: originBoxID)
        }
        if let name = originPostOffice?.name {
            return LetterEndpoint(rawValue: name)
        }
        return LetterEndpoint(rawValue: "Unknown")
    }

    var destinationEndpoint: LetterEndpoint {
        if let destinationBoxID {
            return LetterEndpoint(mailboxID: destinationBoxID)
        }
        if let name = destinationPostOffice?.name {
            return LetterEndpoint(rawValue: name)
        }
        return LetterEndpoint(rawValue: "Unknown")
    }
}
