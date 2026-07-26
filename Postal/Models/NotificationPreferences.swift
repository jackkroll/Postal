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

    /// Free tier default / only free option on the server.
    var requiresSubscription: Bool {
        self == .shipmentDetails
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

    /// Free tier default / only free option on the server.
    var requiresSubscription: Bool {
        self == .shipmentDetails
    }
}

/// Response from `GET/PUT /api/me/notification-preferences`.
struct NotificationPreferencesSummary: Codable, Hashable {
    var sent: SentNotificationMode
    var inbound: InboundNotificationMode
    var effectiveSent: SentNotificationMode?
    var effectiveInbound: InboundNotificationMode?
    var allowedSent: [String]
    var allowedInbound: [String]
    /// Server timestamp string; format is not strictly specified by the OpenAPI schema.
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case sent
        case inbound
        case effectiveSent = "effective_sent"
        case effectiveInbound = "effective_inbound"
        case allowedSent = "allowed_sent"
        case allowedInbound = "allowed_inbound"
        case updatedAt = "updated_at"
    }

    init(
        sent: SentNotificationMode = .destinationOnly,
        inbound: InboundNotificationMode = .arrivalOnly,
        effectiveSent: SentNotificationMode? = nil,
        effectiveInbound: InboundNotificationMode? = nil,
        allowedSent: [String] = [SentNotificationMode.destinationOnly.rawValue],
        allowedInbound: [String] = [InboundNotificationMode.arrivalOnly.rawValue],
        updatedAt: String? = nil
    ) {
        self.sent = sent
        self.inbound = inbound
        self.effectiveSent = effectiveSent
        self.effectiveInbound = effectiveInbound
        self.allowedSent = allowedSent
        self.allowedInbound = allowedInbound
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sent = try container.decodeIfPresent(SentNotificationMode.self, forKey: .sent)
            ?? .destinationOnly
        inbound = try container.decodeIfPresent(InboundNotificationMode.self, forKey: .inbound)
            ?? .arrivalOnly
        effectiveSent = try container.decodeIfPresent(SentNotificationMode.self, forKey: .effectiveSent)
        effectiveInbound = try container.decodeIfPresent(
            InboundNotificationMode.self,
            forKey: .effectiveInbound
        )
        allowedSent = try container.decodeIfPresent([String].self, forKey: .allowedSent)
            ?? [SentNotificationMode.destinationOnly.rawValue]
        allowedInbound = try container.decodeIfPresent([String].self, forKey: .allowedInbound)
            ?? [InboundNotificationMode.arrivalOnly.rawValue]
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
    }

    var allowedSentModes: [SentNotificationMode] {
        let modes = allowedSent.compactMap(SentNotificationMode.init(rawValue:))
        return modes.isEmpty ? [.destinationOnly] : modes
    }

    var allowedInboundModes: [InboundNotificationMode] {
        let modes = allowedInbound.compactMap(InboundNotificationMode.init(rawValue:))
        return modes.isEmpty ? [.arrivalOnly] : modes
    }
}

/// Body for `PUT /api/me/notification-preferences`.
struct UpdateNotificationPreferencesRequest: Codable, Hashable {
    let sent: SentNotificationMode
    let inbound: InboundNotificationMode
}
