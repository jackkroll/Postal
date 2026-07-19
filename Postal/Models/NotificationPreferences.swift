import Foundation

/// Push mode for letters you send.
enum SentNotificationMode: String, Codable, CaseIterable, Hashable, Sendable {
    case shipmentDetails = "shipment_details"
    case destinationOnly = "destination_only"

    var title: String {
        switch self {
        case .shipmentDetails: "Shipment details"
        case .destinationOnly: "Destination only"
        }
    }

    var footer: String {
        switch self {
        case .shipmentDetails:
            return "Get tracking updates while a letter you sent is in transit."
        case .destinationOnly:
            return "Only get notified when a letter you sent arrives."
        }
    }
}

/// Push mode for letters shipping to a mailbox you own.
enum InboundNotificationMode: String, Codable, CaseIterable, Hashable, Sendable {
    case shipmentDetails = "shipment_details"
    case arrivalOnly = "arrival_only"

    var title: String {
        switch self {
        case .shipmentDetails: "Shipment details"
        case .arrivalOnly: "Arrival only"
        }
    }

    var footer: String {
        switch self {
        case .shipmentDetails:
            return "Get tracking updates while an inbound letter is in transit."
        case .arrivalOnly:
            return "Only get notified when an inbound letter arrives at your mailbox."
        }
    }
}

/// Response from `GET/PUT /api/me/notification-preferences`.
struct NotificationPreferencesSummary: Codable, Hashable {
    var sent: SentNotificationMode
    var inbound: InboundNotificationMode
    /// Server timestamp string; format is not strictly specified by the OpenAPI schema.
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case sent
        case inbound
        case updatedAt = "updated_at"
    }

    init(
        sent: SentNotificationMode = .shipmentDetails,
        inbound: InboundNotificationMode = .shipmentDetails,
        updatedAt: String? = nil
    ) {
        self.sent = sent
        self.inbound = inbound
        self.updatedAt = updatedAt
    }
}

/// Body for `PUT /api/me/notification-preferences`.
struct UpdateNotificationPreferencesRequest: Codable, Hashable {
    let sent: SentNotificationMode
    let inbound: InboundNotificationMode
}
